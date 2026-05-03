variable "username" {
  description = "RDS database username"
  type        = string
}

variable "name" {
  type    = string
  default = "mydb"
}

variable "db_subnet_ids" {
  description = "Subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID to attach to the RDS instance"
  type        = string
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
  description = "RDS MySQL instance class; must be a supported combination for the engine version. t3.micro is compatible with MySQL 8.0."
}

variable "allocated_storage" {
  description = "MySQL allocated storage in GB"
  type        = number
  default     = 20

}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot on deletion"
  type        = bool
  default     = true
}