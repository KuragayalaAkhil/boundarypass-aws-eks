# Keep the database in private subnets across two Availability Zones.
resource "aws_db_subnet_group" "this" {
  name       = "boundarypass-db-subnets"
  subnet_ids = var.private_subnet_ids

  tags = {
    Project = "boundarypass"
  }
}

# Permit PostgreSQL connections from the EKS managed nodes.
resource "aws_security_group" "this" {
  name        = "boundarypass-db"
  description = "Database access from BoundaryPass EKS nodes"
  vpc_id      = var.vpc_id

  tags = {
    Project = "boundarypass"
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_eks" {
  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.eks_cluster_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL from EKS nodes"
}

data "aws_iam_policy_document" "monitoring_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "boundarypass-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume_role.json

  tags = {
    Project = "boundarypass"
  }
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Log schema changes and queries taking at least one second.
resource "aws_db_parameter_group" "logging" {
  name   = "boundarypass-postgres18-logging"
  family = "postgres18"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = {
    Project = "boundarypass"
  }
}

# RDS manages the master password in Secrets Manager.
# Multi-AZ maintains a standby database in another Availability Zone.
resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_354:Lab uses AWS-managed encryption for seven-day Database Insights
  identifier                          = "boundarypass-db"
  snapshot_identifier                 = var.snapshot_identifier
  engine                              = "postgres"
  instance_class                      = "db.t4g.small"
  allocated_storage                   = 20
  storage_type                        = "gp3"
  storage_encrypted                   = true
  db_name                             = "boundarypass"
  username                            = "boundarypassadmin"
  manage_master_user_password         = true
  iam_database_authentication_enabled = true

  multi_az                        = true
  publicly_accessible             = false
  db_subnet_group_name            = aws_db_subnet_group.this.name
  parameter_group_name            = aws_db_parameter_group.logging.name
  vpc_security_group_ids          = [aws_security_group.this.id]
  auto_minor_version_upgrade      = true
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.monitoring.arn

  depends_on = [aws_iam_role_policy_attachment.monitoring]

  database_insights_mode                = "standard"
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # This lab is destroyed between sessions to stop database charges.
  # Take a manual RDS snapshot first if you need to keep booking data.
  deletion_protection = true
  skip_final_snapshot = true

  tags = {
    Project = "boundarypass"
  }
}