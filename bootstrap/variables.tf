variable "region" {
  description = "AWS region for bootstrap resources"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project prefix used for bootstrap resource names"
  type        = string
  default     = "lamp-eks-test"
}

variable "github_repository" {
  description = "GitHub repository in owner/repo format"
  type        = string
}

variable "github_branches" {
  description = "Git branches allowed to assume GitHub Actions roles"
  type        = list(string)
  default     = ["main", "master"]
}

variable "tf_state_bucket_name" {
  description = "Optional explicit name for the Terraform state bucket"
  type        = string
  default     = ""
}

variable "tf_lock_table_name" {
  description = "Optional explicit name for the Terraform lock table"
  type        = string
  default     = ""
}

variable "eks_cluster_name" {
  description = "Existing EKS cluster name — used in the app deploy IAM policy and in the aws-auth instructions for kubectl access"
  type        = string
  default     = "techrite-eks-cluster-nonprod"
}