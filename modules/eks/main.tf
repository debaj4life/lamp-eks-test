# ──────────────────────────────────────────────
# IAM Role – EKS Control Plane
# ──────────────────────────────────────────────
resource "aws_iam_role" "techrite_eks_role" {
  name = "techrite-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "techrite_eks_policy" {
  role       = aws_iam_role.techrite_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ──────────────────────────────────────────────
# IAM Role – EKS Node Group
# ──────────────────────────────────────────────
resource "aws_iam_role" "major_node_instance_role" {
  name = "techrite-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  role       = aws_iam_role.major_node_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  role       = aws_iam_role.major_node_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  role       = aws_iam_role.major_node_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ──────────────────────────────────────────────
# EKS Cluster
# ──────────────────────────────────────────────
resource "aws_eks_cluster" "eks" {
  name     = "techrite-eks-cluster-nonprod"
  role_arn = aws_iam_role.techrite_eks_role.arn

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  depends_on = [aws_iam_role_policy_attachment.techrite_eks_policy]
}

# ──────────────────────────────────────────────
# EKS Node Group
# ──────────────────────────────────────────────
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "techrite-worker-node-nonprod"
  node_role_arn   = aws_iam_role.major_node_instance_role.arn
  subnet_ids      = var.node_subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy,
  ]
}