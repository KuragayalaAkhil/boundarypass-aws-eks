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

# RDS manages the master password in Secrets Manager.
# Multi-AZ maintains a standby database in another Availability Zone.
resource "aws_db_instance" "this" {
  identifier                  = "boundarypass-db"
  engine                      = "postgres"
  instance_class              = "db.t4g.small"
  allocated_storage           = 20
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = "boundarypass"
  username                    = "boundarypassadmin"
  manage_master_user_password = true

  multi_az               = true
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  # This lab is destroyed between sessions to stop database charges.
  # Take a manual RDS snapshot first if you need to keep booking data.
  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Project = "boundarypass"
  }
}