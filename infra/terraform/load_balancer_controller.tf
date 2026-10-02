# Allow EKS Pod Identity to assume a dedicated role for the ALB controller.
data "aws_iam_policy_document" "load_balancer_controller_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "load_balancer_controller" {
  name               = "boundarypass-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.load_balancer_controller_assume.json

  tags = {
    Project = "boundarypass"
  }
}

# AWS publishes the API permissions needed to create and manage ALBs.
resource "aws_iam_policy" "load_balancer_controller" {
  name   = "boundarypass-load-balancer-controller"
  policy = file("${path.module}/load_balancer_controller_iam_policy.json")

  tags = {
    Project = "boundarypass"
  }
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

# The Helm chart will create this ServiceAccount in kube-system.
resource "aws_eks_pod_identity_association" "load_balancer_controller" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.load_balancer_controller.arn

  depends_on = [aws_iam_role_policy_attachment.load_balancer_controller]

  tags = {
    Project = "boundarypass"
  }
}
