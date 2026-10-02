# Create the managed Kubernetes control plane in the supplied private subnets.
resource "aws_eks_cluster" "this" {
  #checkov:skip=CKV_AWS_58:EKS 1.35 encrypts Kubernetes API data by default
  #checkov:skip=CKV_AWS_39:Laptop administration uses a restricted public CIDR; private endpoint is also enabled
  name                      = var.cluster_name
  role_arn                  = aws_iam_role.cluster.arn
  version                   = "1.35"
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    # Use the EKS API for authentication and grant the creator initial admin access.
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    # Enable both endpoints so the API can be reached privately or over the internet.
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.api_access_cidr]
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]

  tags = {
    Project                                = "boundarypass"
    "alpha.eksctl.io/cluster-oidc-enabled" = "true"
  }
}

# Creates EC2 worker nodes in private subnets to run the application and Argo CD.
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids

  # Start with two nodes so workloads can run across both availability zones.
  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 2
  }

  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"
  disk_size      = 30

  # Ensure IAM permissions are attached before AWS launches the nodes.
  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_registry,
    aws_iam_role_policy_attachment.nodes_cni
  ]

  tags = {
    Project = "boundarypass"
  }
}

# Runs on each EKS worker node to provide temporary AWS credentials
# to pods through EKS Pod Identity.
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"

  # The agent runs as a DaemonSet, so worker nodes must exist first.
  depends_on = [aws_eks_node_group.this]

  tags = {
    Project = "boundarypass"
  }
}