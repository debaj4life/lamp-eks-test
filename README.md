# LAMP EKS — WordPress on AWS EKS with RDS

Terraform project that provisions a containerised WordPress stack on AWS. The stack deploys a managed Kubernetes cluster (EKS), a MySQL RDS database, and all supporting networking and security-group infrastructure. A custom WordPress Docker image is built and pushed to Amazon ECR, then deployed via Kubernetes manifests.

---

## Architecture

```
VPC (10.0.0.0/16)  –  eu-west-2
├── Public Subnets   (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)  → EKS Control Plane / Load Balancer
└── Private Subnets  (10.0.4.0/24, 10.0.5.0/24, 10.0.6.0/24)  → EKS Node Group + RDS MySQL

EKS Cluster  (techrite-eks-cluster-nonprod)
└── Managed Node Group  (t3.micro × 2)

RDS MySQL  (db.t3.micro, 10 GB)

ECR Repository  (wordpress)
```

---

## Prerequisites

| Tool | Purpose |
|------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.0` | Infrastructure provisioning |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | ECR authentication & AWS access |
| [Docker](https://docs.docker.com/get-docker/) | Building and pushing the WordPress image |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Deploying Kubernetes manifests |

AWS credentials must be configured with sufficient permissions to manage VPC, EKS, RDS, IAM, and ECR resources.

---

## Module Structure

```
lamp-eks-test/
├── main.tf                   # Root module — wires all child modules together
├── variables.tf
├── outputs.tf
├── provider.tf
├── modules/
│   ├── network/              # VPC, subnets, internet gateway, route tables
│   ├── security-groups/      # Web (EKS) and DB security groups
│   ├── rds/                  # MySQL RDS instance
│   └── eks/                  # EKS cluster, node group, IAM roles
├── kubernetes/
│   ├── wordpress-deployment.yaml
│   ├── wordpress-service.yaml
│   └── secret.yaml           # DB password secret (do not commit plaintext values)
├── docker/
│   └── dockerfile            # Custom WordPress 6.5 / PHP 8.2 image
└── scripts/
    └── build-and-push.sh     # Build image and push to ECR
```

---

## Usage

### 1. Initialise Terraform

```bash
cd lamp-eks-test
terraform init
```

### 2. Build and push the Docker image

```bash
chmod +x scripts/build-and-push.sh
./scripts/build-and-push.sh
```

This will:
- Create the ECR repository if it does not exist
- Build the image from `docker/dockerfile`
- Tag and push as `wordpress:1.0` and `wordpress:latest`

### 3. Create the Kubernetes DB secret

For manual deployments, replace the placeholder value in `kubernetes/secret.yaml` and apply it after configuring `kubectl` (step 5). The GitHub Actions pipeline does not use this file for the password; it creates or updates the secret from the `WORDPRESS_DB_PASSWORD` repository secret.

```bash
kubectl apply -f kubernetes/secret.yaml
```

### 4. Deploy infrastructure

```bash
terraform apply -var="db_username=admin"
```

Key input variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `db_username` | *(required)* | RDS master username |
| `db_name` | `mydb` | RDS database name |
| `region` | `eu-west-2` | AWS region |
| `instance_class` | `db.t3.micro` | RDS instance class |
| `allocated_storage` | `10` | RDS storage in GB |
| `skip_final_snapshot` | `true` | Skip final RDS snapshot on destroy |

### 5. Configure kubectl

```bash
aws eks update-kubeconfig --region eu-west-2 --name techrite-eks-cluster-nonprod
```

### 6. Deploy WordPress to Kubernetes

```bash
kubectl apply -f kubernetes/secret.yaml
kubectl apply -f kubernetes/wordpress-deployment.yaml
kubectl apply -f kubernetes/wordpress-service.yaml
```

---

## Outputs

| Output | Description |
|--------|-------------|
| `eks_cluster_endpoint` | EKS API server endpoint |
| `eks_cluster_name` | EKS cluster name |

---

## CI/CD Pipeline

The repository now supports a GitHub Actions deployment workflow at `.github/workflows/deploy.yml`.

On every push to `main` or `master` that changes the Docker image, Kubernetes manifests, or the workflow itself, the pipeline will:
- Assume an AWS IAM role through GitHub OIDC
- Build the WordPress image from `docker/dockerfile`
- Push two tags to ECR: `latest` and the full Git commit SHA
- Update kubeconfig for the existing EKS cluster
- Create or update the Kubernetes secret `wp-db-secret` from a GitHub Actions secret
- Apply the WordPress deployment and service manifests
- Roll the `wordpress` deployment to the exact image built in that run

### Required GitHub repository secrets

| Secret | Description |
|--------|-------------|
| `AWS_DEPLOY_ROLE_ARN` | IAM role ARN that GitHub Actions can assume via OIDC |
| `WORDPRESS_DB_PASSWORD` | Database password written into the `wp-db-secret` Kubernetes secret |

### Required AWS IAM permissions

The IAM role used by GitHub Actions needs permission to:
- authenticate to ECR and push images
- describe or create the `wordpress` ECR repository
- describe the EKS cluster
- access the cluster through `aws eks update-kubeconfig`

In practice, attach the minimum policies needed for ECR push and EKS describe access, and map that IAM role into cluster RBAC if the role is not already authorised in the cluster.

### GitHub OIDC setup

Configure GitHub Actions to assume AWS credentials without storing long-lived AWS keys:

1. Create an IAM role trusted by GitHub's OIDC provider.
2. Allow the repository and branch you want to deploy from in the role trust policy.
3. Save that role ARN as the `AWS_DEPLOY_ROLE_ARN` repository secret.

If you prefer, I can also add the IAM trust-policy Terraform for that role.

---

## Infrastructure Pipeline

The repository also supports a Terraform infrastructure workflow at `.github/workflows/terraform.yml`.

This workflow:
- runs on pull requests and on pushes to `main` or `master` when Terraform files change
- checks Terraform formatting
- runs `terraform init`, `terraform validate`, and `terraform plan`
- only applies infrastructure on manual workflow dispatch when you choose the `apply` action
- uses an S3 backend with DynamoDB locking so CI does not rely on local state files

The repository also includes a dedicated destroy workflow at `.github/workflows/terraform-destroy.yml`. That workflow is manual-only, requires the input `DESTROY`, and should be protected with GitHub environment approvals.

### Required GitHub repository secrets

| Secret | Description |
|--------|-------------|
| `AWS_TERRAFORM_ROLE_ARN` | IAM role ARN assumed by GitHub Actions for Terraform |
| `TF_STATE_BUCKET` | S3 bucket name that stores Terraform remote state |
| `TF_STATE_LOCK_TABLE` | DynamoDB table used for Terraform state locking |
| `TF_VAR_db_username` | Value for Terraform variable `db_username` |

### Backend behavior

The S3 backend is declared in `provider.tf` and configured at runtime by the workflow with backend config arguments. The state key is fixed to `lamp-eks-test/terraform.tfstate`.

## Bootstrap Stack

A separate Terraform bootstrap stack now exists in `bootstrap/`. Use it to create the shared CI/CD prerequisites that the main stack should not create for itself:
- the S3 bucket used for Terraform remote state
- the DynamoDB table used for Terraform state locking
- the GitHub OIDC provider in AWS
- the GitHub Actions IAM role for Terraform
- the GitHub Actions IAM role for application deployment

### Bootstrap usage

Run the bootstrap stack from the `bootstrap/` directory:

```bash
cd bootstrap
terraform init
terraform apply -var="github_repository=<owner/repo>"
```

The bootstrap stack outputs values you should copy into GitHub repository secrets:
- `terraform_role_arn` -> `AWS_TERRAFORM_ROLE_ARN`
- `app_deploy_role_arn` -> `AWS_DEPLOY_ROLE_ARN`
- `tf_state_bucket_name` -> `TF_STATE_BUCKET`
- `tf_lock_table_name` -> `TF_STATE_LOCK_TABLE`

If the EKS cluster already exists and you want the app deployment pipeline to be able to run `kubectl`, add the app deploy role to the `aws-auth` ConfigMap after the bootstrap apply:

```bash
kubectl edit configmap aws-auth -n kube-system
```

Add the following entry under `mapRoles`, replacing the ARN with the value from the `app_deploy_role_arn` output:

```yaml
- rolearn: arn:aws:iam::<account-id>:role/lamp-eks-test-github-app-deploy-role
  username: github-app-deploy
  groups:
    - system:masters
```

### One-time state migration

This repository currently has local Terraform state. Before letting GitHub Actions apply infrastructure changes for the existing stack, migrate that state into the S3 backend once from a trusted machine:

```bash
terraform init \
    -migrate-state \
    -backend-config="bucket=<your-state-bucket>" \
    -backend-config="key=lamp-eks-test/terraform.tfstate" \
    -backend-config="region=eu-west-2" \
    -backend-config="dynamodb_table=<your-lock-table>"
```

Without this migration, CI would see an empty backend and attempt to create duplicate infrastructure instead of managing the resources you already provisioned.

Before using the workflow, create:

1. an S3 bucket for Terraform state
2. a DynamoDB table for Terraform locks with a string partition key named `LockID`
3. an IAM role trusted by GitHub OIDC with access to the S3 state bucket, DynamoDB lock table, and the AWS resources managed by this Terraform stack

### Important note

This workflow assumes GitHub Actions is the source of truth for Terraform state changes. Existing local state files should not be used for collaborative CI applies once the remote backend is active.

If you want, I can add the AWS resources and IAM policy documents for the Terraform backend as code next.

---

## Teardown

```bash
kubectl delete -f kubernetes/
terraform destroy -var="db_username=admin"
```

> **Note:** Set `skip_final_snapshot = false` before destroying if you need to retain a final RDS snapshot.
