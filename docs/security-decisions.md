# Infrastructure security decisions

BoundaryPass is a short lived learning environment. The application release job
runs separately from the infrastructure Checkov scan. The latest scan has
100 passed checks and 13 failed checks. These findings remain visible in CI.

| Check | Resource | Decision |
| --- | --- | --- |
| CKV_AWS_58 | EKS | Explicit customer managed KMS encryption for Kubernetes secrets is not configured. Review before production use. |
| CKV_AWS_39 | EKS | The public API endpoint is needed for administration from the laptop and is restricted by `api_access_cidr`. Use private access only when an administrative network path is available. |
| CKV_AWS_353 | RDS | Performance Insights is not enabled in this short lived lab. Review cost and retention before enabling. |
| CKV_AWS_161 | RDS | The app uses a Secrets Manager managed database password. IAM database authentication requires an application and database user migration. |
| CKV_AWS_293 | RDS | Deletion protection is disabled for the planned snapshot and destroy workflow. Take a manual snapshot before destroying the database if booking data must be kept. |
| CKV_AWS_118 | RDS | Enhanced Monitoring is not enabled. Review its operational need and cost. |
| CKV_AWS_158 | VPC flow logs | The CloudWatch log group has no customer managed KMS key. Review key management before production use. |
| CKV_AWS_338 | VPC flow logs | Rejected traffic logs are retained for 7 days to limit storage in this short lived lab. |
| CKV2_AWS_62 | Terraform state S3 bucket | Event notifications have no consumer in this project. Add them only with a defined monitoring workflow. |
| CKV2_AWS_30 | RDS | Statement query logging is not enabled. Review log volume and sensitive data exposure before attaching a custom parameter group. |
| CKV_AWS_18 | Terraform state S3 bucket | Bucket access logging is not configured. Review a separate logging destination and retention policy. |
| CKV_AWS_144 | Terraform state S3 bucket | Cross region replication is not configured for this short lived lab. Review disaster recovery requirements and cost. |
| CKV_AWS_145 | Terraform state S3 bucket | State uses SSE-S3 (`AES256`) rather than a customer managed KMS key. Review KMS access and recovery requirements before changing encryption. |

These are recorded decisions, not Checkov suppressions. Keep the `infra-scan`
job reporting failures until each finding is fixed or a scoped exception is
approved and documented.