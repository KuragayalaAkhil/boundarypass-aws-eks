data "aws_caller_identity" "pod_identity" {}

data "aws_region" "pod_identity" {}

# EKS Pod Identity assumes this role for the application's service account.
data "aws_iam_policy_document" "app_pod_assume_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_pod" {
  name               = "boundarypass-app-pod"
  assume_role_policy = data.aws_iam_policy_document.app_pod_assume_role.json

  tags = {
    Project = "boundarypass"
  }
}

# Permit only the boundarypass_app PostgreSQL user on this RDS instance.
data "aws_iam_policy_document" "app_db_connect" {
  statement {
    actions = ["rds-db:connect"]
    resources = [
      "arn:aws:rds-db:${data.aws_region.pod_identity.region}:${data.aws_caller_identity.pod_identity.account_id}:dbuser:${module.rds.db_resource_id}/boundarypass_app"
    ]
  }
}

resource "aws_iam_role_policy" "app_db_connect" {
  name   = "boundarypass-app-db-connect"
  role   = aws_iam_role.app_pod.id
  policy = data.aws_iam_policy_document.app_db_connect.json
}

# Link the IAM role to the application service account in the default namespace.
resource "aws_eks_pod_identity_association" "app" {
  cluster_name    = module.eks.cluster_name
  namespace       = "default"
  service_account = "boundarypass-app"
  role_arn        = aws_iam_role.app_pod.arn

  depends_on = [aws_iam_role_policy.app_db_connect]

  tags = {
    Project = "boundarypass"
  }
}