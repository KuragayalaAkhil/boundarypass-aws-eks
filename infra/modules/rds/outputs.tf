# Share connection details without exposing the database password.
output "endpoint" {
  description = "PostgreSQL hostname and port"
  value       = aws_db_instance.this.endpoint
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed master credential secret"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}