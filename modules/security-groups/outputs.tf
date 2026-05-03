output "security_group_id" {
  value = aws_security_group.web_sg.id
}

output "db_security_group_id" {
  value = aws_security_group.db_sg.id
}

output "eks_security_group_id" {
  value = aws_security_group.eks_sg.id
}
