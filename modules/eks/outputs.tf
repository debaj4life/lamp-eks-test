output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = aws_eks_cluster.eks.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded certificate authority data"
  value       = aws_eks_cluster.eks.certificate_authority[0].data
}

output "node_group_name" {
  description = "Name of the EKS node group"
  value       = aws_eks_node_group.node_group.node_group_name
}
