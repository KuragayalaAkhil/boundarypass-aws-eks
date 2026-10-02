# Share connection details without exposing the database password.
output "endpoint" {
  description = "PostgreSQL hostname and port"
  value       = aws_db_instance.this.endpoint
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed master credential secret"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

# The stable RDS resource ID is required in an IAM database connection ARN.
output "db_resource_id" {
  description = "RDS resource ID used to scope IAM database authentication"
  value       = aws_db_instance.this.resource_id
}