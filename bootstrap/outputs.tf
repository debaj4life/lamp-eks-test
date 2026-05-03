output "tf_state_bucket_name" {
  description = "Terraform state bucket name"
  value       = aws_s3_bucket.tf_state.bucket
}

output "tf_lock_table_name" {
  description = "Terraform lock table name"
  value       = aws_dynamodb_table.tf_locks.name
}

output "terraform_role_arn" {
  description = "GitHub Actions IAM role ARN for Terraform"
  value       = aws_iam_role.terraform.arn
}

output "app_deploy_role_arn" {
  description = "GitHub Actions IAM role ARN for application deployment"
  value       = aws_iam_role.app_deploy.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}