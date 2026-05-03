variable "subnet_ids" {
  description = "Subnet IDs for the EKS control plane (public or mixed)"
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnet IDs for the EKS worker node group (private recommended)"
  type        = list(string)
}

variable "node_instance_type" {
  description = "EC2 instance type for the EKS worker nodes"
  type        = string
  default     = "t3.micro"
}


variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}
