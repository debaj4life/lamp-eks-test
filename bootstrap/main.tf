data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  state_bucket_name = var.tf_state_bucket_name != "" ? var.tf_state_bucket_name : "${var.project_name}-tf-state-${data.aws_caller_identity.current.account_id}"
  lock_table_name   = var.tf_lock_table_name != "" ? var.tf_lock_table_name : "${var.project_name}-tf-locks"
  branch_subjects   = [for branch in var.github_branches : "repo:${var.github_repository}:ref:refs/heads/${branch}"]
  environment_subjects = [
    for environment in var.github_environments :
    "repo:${var.github_repository}:environment:${environment}"
  ]
}

resource "aws_s3_bucket" "tf_state" {
  bucket = local.state_bucket_name
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "terraform_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = concat(
        local.branch_subjects,
        ["repo:${var.github_repository}:pull_request"],
        local.environment_subjects,
      )
    }
  }
}

data "aws_iam_policy_document" "app_deploy_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.branch_subjects
    }
  }
}

resource "aws_iam_role" "terraform" {
  name               = "${var.project_name}-github-terraform-role"
  assume_role_policy = data.aws_iam_policy_document.terraform_assume_role.json
}

data "aws_iam_policy_document" "terraform_permissions" {
  statement {
    sid = "TerraformStateBucket"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.tf_state.arn]
  }

  statement {
    sid = "TerraformStateObjects"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.tf_state.arn}/*"]
  }

  statement {
    sid = "TerraformLockTable"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem",
    ]
    resources = [aws_dynamodb_table.tf_locks.arn]
  }

  statement {
    sid = "TerraformManagedAwsResources"
    actions = [
      "autoscaling:*",
      "cloudwatch:*",
      "ec2:*",
      "eks:*",
      "elasticloadbalancing:*",
      "iam:*",
      "kms:DescribeKey",
      "kms:ListAliases",
      "logs:*",
      "rds:*",
      "secretsmanager:*",
      "tag:GetResources",
      "tag:TagResources",
      "tag:UntagResources",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "TerraformPassRole"
    actions = ["iam:PassRole"]
    resources = [
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/techrite-*",
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*",
    ]
  }
}

resource "aws_iam_role_policy" "terraform" {
  name   = "${var.project_name}-github-terraform-policy"
  role   = aws_iam_role.terraform.id
  policy = data.aws_iam_policy_document.terraform_permissions.json
}

resource "aws_iam_role" "app_deploy" {
  name               = "${var.project_name}-github-app-deploy-role"
  assume_role_policy = data.aws_iam_policy_document.app_deploy_assume_role.json
}

data "aws_iam_policy_document" "app_deploy_permissions" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid       = "RdsDescribe"
    actions   = ["rds:DescribeDBInstances"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:CreateRepository",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/wordpress",
    ]
  }

  statement {
    sid = "EksDescribeCluster"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}",
    ]
  }
}

resource "aws_iam_role_policy" "app_deploy" {
  name   = "${var.project_name}-github-app-deploy-policy"
  role   = aws_iam_role.app_deploy.id
  policy = data.aws_iam_policy_document.app_deploy_permissions.json
}

# aws_eks_access_entry requires AWS provider v5+.
# With provider ~> 4.0, add the deploy role to aws-auth manually after bootstrap:
#
#   kubectl edit configmap aws-auth -n kube-system
#
# Add the following under mapRoles:
#   - rolearn: <app_deploy_role_arn output>
#     username: github-app-deploy
#     groups:
#       - system:masters
#
# Alternatively, upgrade the provider version to ~> 5.0 and add:
#
#   resource "aws_eks_access_entry" "app_deploy" {
#     cluster_name  = var.eks_cluster_name
#     principal_arn = aws_iam_role.app_deploy.arn
#     type          = "STANDARD"
#   }
#
#   resource "aws_eks_access_policy_association" "app_deploy" {
#     cluster_name  = var.eks_cluster_name
#     principal_arn = aws_iam_role.app_deploy.arn
#     policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
#     access_scope { type = "cluster" }
#   }