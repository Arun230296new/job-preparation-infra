pipeline {
  agent any
  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }
  environment {
    AWS_REGION = 'ap-southeast-2'
    TF_IN_AUTOMATION = 'true'
    TF_INPUT = 'false'
    EKS_CLUSTER_NAME = 'job-preparation-eks'
  }
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    stage('Prepare remote Terraform state') {
      steps {
        script {
          env.AWS_ACCOUNT_ID = sh(
            script: 'aws sts get-caller-identity --query Account --output text',
            returnStdout: true
          ).trim()
          env.TF_STATE_BUCKET = "job-preparation-tfstate-${env.AWS_ACCOUNT_ID}-${env.AWS_REGION}"
        }
        sh '''
          set -eu
          if ! aws s3api head-bucket --bucket "$TF_STATE_BUCKET" 2>/dev/null; then
            aws s3api create-bucket \
              --bucket "$TF_STATE_BUCKET" \
              --region "$AWS_REGION" \
              --create-bucket-configuration LocationConstraint="$AWS_REGION"
          fi
          aws s3api put-public-access-block --bucket "$TF_STATE_BUCKET" --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
          aws s3api put-bucket-versioning --bucket "$TF_STATE_BUCKET" --versioning-configuration Status=Enabled
          aws s3api put-bucket-encryption --bucket "$TF_STATE_BUCKET" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
        '''
      }
    }
    stage('Terraform format, validate and plan') {
      steps {
        sh '''
          set -eu
          curl -fsSL https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json -o terraform/iam/aws-load-balancer-controller-policy.json
          terraform -chdir=terraform fmt -recursive
          terraform -chdir=terraform init -input=false -reconfigure \
            -backend-config="bucket=$TF_STATE_BUCKET" \
            -backend-config="key=job-preparation/terraform.tfstate" \
            -backend-config="region=$AWS_REGION" \
            -backend-config="encrypt=true" \
            -backend-config="use_lockfile=true"
          terraform -chdir=terraform validate
          terraform -chdir=terraform plan -input=false -out=tfplan
        '''
      }
    }
    stage('Provision AWS infrastructure') {
      steps {
        sh '''
          set -eu
          terraform -chdir=terraform apply -input=false -auto-approve tfplan
        '''
      }
    }
    stage('Install platform services and configure Argo CD') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'github-repo-token', usernameVariable: 'GITHUB_USERNAME', passwordVariable: 'GITHUB_TOKEN')]) {
          sh '''
            set -eu
            set +x
            aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"
            kubectl wait --for=condition=Ready nodes --all --timeout=20m

            helm repo add argo https://argoproj.github.io/argo-helm
            helm repo add eks https://aws.github.io/eks-charts
            helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
            helm repo update

            helm upgrade --install argocd argo/argo-cd \
              --namespace argocd --create-namespace --wait --timeout 20m

            ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
            VPC_ID=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text)

            helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
              --version 1.14.1 \
              --namespace kube-system \
              --set clusterName="$EKS_CLUSTER_NAME" \
              --set region="$AWS_REGION" \
              --set vpcId="$VPC_ID" \
              --set serviceAccount.create=true \
              --set serviceAccount.name=aws-load-balancer-controller \
              --set-string "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/job-preparation-aws-load-balancer-controller" \
              --wait --timeout 15m

            helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
              --namespace monitoring --create-namespace \
              --set grafana.service.type=ClusterIP \
              --set prometheus.prometheusSpec.retention=7d \
              --wait --timeout 20m

            kubectl create secret generic job-preparation-app-repo \
              --namespace argocd \
              --from-literal=type=git \
              --from-literal=url=https://github.com/Arun230296new/job-preparation-app.git \
              --from-literal=username="$GITHUB_USERNAME" \
              --from-literal=password="$GITHUB_TOKEN" \
              --dry-run=client -o yaml | kubectl apply -f -
            kubectl label secret job-preparation-app-repo --namespace argocd \
              argocd.argoproj.io/secret-type=repository --overwrite

            ECR_URL=$(terraform -chdir=terraform output -raw ecr_repository_url)
            sed "s|REPLACE_WITH_ECR_REPOSITORY_URL|${ECR_URL}|g" argocd/application.yaml | kubectl apply -f -

            kubectl get nodes
            kubectl get pods -n argocd
            kubectl get pods -n monitoring
            kubectl get deployment aws-load-balancer-controller -n kube-system
            echo "ECR repository: ${ECR_URL}"
            echo "EKS cluster: ${EKS_CLUSTER_NAME}"
          '''
        }
      }
    }
  }
  post {
    success { echo 'Infrastructure pipeline completed successfully.' }
    failure { echo 'Infrastructure pipeline failed. Review the stage logs before retrying.' }
  }
}
