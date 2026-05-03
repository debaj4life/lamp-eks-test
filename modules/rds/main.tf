resource "aws_db_subnet_group" "this" {
  name       = "mysql-subnet-group"
  subnet_ids = var.db_subnet_ids
}

resource "aws_db_instance" "mysql" {
  allocated_storage    = var.allocated_storage
  engine               = "mysql"
  instance_class       = var.instance_class
  db_name              = var.name
  username             = var.username
  manage_master_user_password = true
  skip_final_snapshot  = var.skip_final_snapshot

  vpc_security_group_ids = [var.security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.this.name

  publicly_accessible = false
}


output "master_user_secret_arn" {
  value = try(aws_db_instance.mysql.master_user_secret[0].secret_arn, null)
}