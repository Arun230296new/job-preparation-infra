# Job preparation infrastructure

Terraform repository for the **Job preparation** DevOps project.

Creates a VPC with public/private subnets and one NAT Gateway, ECR repository, EKS cluster and managed nodes, EKS add-ons, IAM role for AWS Load Balancer Controller, Argo CD, AWS Load Balancer Controller, and Prometheus/Grafana.

## Jenkins requirements
- Jenkins AWS credential ID: `aws-credentials`
- Terraform 1.6+, AWS CLI and kubectl on the Jenkins agent
- Jenkins plugins: Pipeline, Git, Pipeline: AWS Steps
- AWS permissions for VPC, EC2, IAM, EKS, ECR and related resources

## Before running
- Push both repositories to their `main` branches.
- For a private app repository, configure GitHub repository credentials in Argo CD before the Application is synced.
- Review the Terraform plan and AWS charges. EKS, EC2 worker nodes, NAT Gateway, EBS and ALB resources are billable.
- Terraform state is local to the Jenkins workspace. Preserve it between builds or configure remote state before running.

The infrastructure contract matches the application repository: ECR `job-preparation-app`, EKS `job-preparation-eks`, Kubernetes namespace `job-preparation`, Argo CD Application `job-preparation-app`.


Additional Jenkins credential required:
- Secret text ID `github-repo-token`: GitHub personal access token with read access to the private application repository. It is used to register the app repo with Argo CD.
- Jenkins agent must also have Helm 3 installed.

Terraform provisions AWS resources first; the same Jenkins build then installs Argo CD, AWS Load Balancer Controller, Prometheus/Grafana, registers the private GitHub app repository, and applies the Argo CD Application.
