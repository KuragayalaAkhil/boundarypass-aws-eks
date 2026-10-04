# Give the EBS CSI controller its own IAM role.
# Reuse the existing EKS Pod Identity trust policy.
resource "aws_iam_role" "ebs_csi" {
  name               = "boundarypass-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.app_pod_assume_role.json

  tags = {
    Project = "boundarypass"
  }
}

# Allow the driver to create and manage Kubernetes EBS volumes.
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role = aws_iam_role.ebs_csi.name
  # Allow the EBS CSI driver to manage tagged volumes and snapshots.
  policy_arn = "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2"
}

# Install the AWS-managed EBS CSI driver.
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  # Assign the IAM role to the driver's controller service account.
  # EKS manages this association as part of the add-on.
  pod_identity_association {
    role_arn        = aws_iam_role.ebs_csi.arn
    service_account = "ebs-csi-controller-sa"
  }

  # Wait for the worker nodes, Pod Identity agent and IAM policy.
  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.ebs_csi
  ]

  tags = {
    Project = "boundarypass"
  }
}