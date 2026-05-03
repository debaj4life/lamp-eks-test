variable "instance_type" {
  default = "t3.micro"
  type    = string
}

variable "ami" {
  default = "ami-0685f8dd865c8e389"
  type    = string
}

variable "service" {
  description = "Service name"
  type        = string
  default     = "nginx"
}

variable "db_username" {
  description = "RDS database username"
  type        = string
}

variable "region" {
  type        = string
  description = "aws region"
  default     = "eu-west-2"
}

variable "allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 10
}

variable "db_name" {
  type    = string
  default = "mydb"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot on RDS deletion"
  type        = bool
  default     = true
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access"
  type        = string
  default     = "web-key"
  nullable    = true
}