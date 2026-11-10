# Job preparation infrastructure

Terraform and platform automation for the **Job preparation** DevOps project.

## Resources created
- VPC with public/private subnets across two Availability Zones and one NAT Gateway
- Amazon ECR repository `job-preparation-app`
- Amazon EKS cluster `job-preparation-eks` with two `t3.medium` managed worker nodes
- EKS add-ons and IAM Roles for Service Accounts (IRSA)
- AWS Load Balancer Controller IAM role and policy
- Argo CD, AWS Load Balancer Controller, Prometheus and Grafana
- Argo CD Application for the private app repository

## Jenkins pipeline
This repository has the infrastructure Jenkins pipeline (`Jenkinsfile`). Configure a Jenkins Pipeline job with:
- Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository: `https://github.com/Arun230296new/job-preparation-infra.git`
- Credentials: `github-repo-token` (Username with password; GitHub username + fine-grained PAT)
- Branch: `*/main`
- Script path: `Jenkinsfile`

The pipeline uses the EC2 instance profile `JenkinsEC2Role` directly. It creates an encrypted, versioned S3 bucket for remote Terraform state, runs Terraform format/validate/plan/apply, then installs the platform services and registers the private app repository with Argo CD. The Argo CD Application tracks the app repository `gitops` branch; the first successful app pipeline creates that branch and keeps its Helm image tag current.

## Jenkins prerequisites
- AWS CLI v2, Terraform 1.10+, kubectl, Helm 3, Docker and curl installed on the Jenkins EC2.
- EC2 instance profile `JenkinsEC2Role` with the permissions required to create VPC, EKS, ECR, IAM, S3 and related resources. The current lab role uses AdministratorAccess; reduce permissions for production.
- Jenkins credential `github-repo-token`: **Username with password**, username `Arun230296new`, password is a fine-grained GitHub PAT with Contents read/write access to both private repositories.

## Run order
1. Run this infrastructure pipeline first.
2. Run the app pipeline after the infrastructure pipeline succeeds.

## Cost warning
EKS control plane, two EC2 worker nodes, NAT Gateway, EBS storage, load balancers and data transfer incur AWS charges. Destroy the Terraform infrastructure when the lab is finished. The remote Terraform state bucket is intentionally retained so state is not lost; delete it only after infrastructure destruction and after confirming you no longer need the state.
