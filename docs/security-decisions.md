# Infrastructure security decisions

BoundaryPass is a short lived learning environment. The application release job
runs separately from the infrastructure Checkov scan. The prior scan had 120 passed checks and 11 failed checks. The 11 lab
decisions below now use resource-specific Checkov exceptions with reasons;
the scan reports them as skipped, not as implemented controls.

| Check | Resource | Decision |
| --- | --- | --- |
| CKV_AWS_58 | EKS | EKS 1.35 encrypts Kubernetes API data by default. No customer-managed KMS key is configured; review key control and cost before production use. |
| CKV_AWS_39 | EKS | The public API endpoint is needed for administration from the laptop and is restricted by `api_access_cidr`. Use private access only when an administrative network path is available. |
| CKV_AWS_353 | RDS | Resolved: Database Insights Standard collects detailed metrics with 7-day retention. |
| CKV_AWS_354 | RDS | Database Insights uses an AWS-managed KMS key. A customer-managed key adds key management and cost; review before production use. |
| CKV_AWS_161 | RDS | The app uses a Secrets Manager managed database password. IAM database authentication requires an application and database user migration. |
| CKV_AWS_293 | RDS | Deletion protection is disabled for the planned snapshot and destroy workflow. Take a manual snapshot before destroying the database if booking data must be kept. |
| CKV_AWS_118 | RDS | Resolved: RDS Enhanced Monitoring runs at a 60-second interval using the dedicated monitoring IAM role. CloudWatch Logs usage adds cost. |
| CKV_AWS_158 | VPC flow logs | The CloudWatch log group has no customer managed KMS key. Review key management before production use. |
| CKV_AWS_338 | VPC flow logs | Resolved: rejected VPC traffic logs are retained for 365 days. |
| CKV2_AWS_62 | Terraform state S3 bucket | Event notifications have no consumer in this project. Add them only with a defined monitoring workflow. |
| CKV2_AWS_30 | RDS | Statement query logging is not enabled. Review log volume and sensitive data exposure before attaching a custom parameter group. |
| CKV_AWS_18 | Terraform state S3 bucket | Bucket access logging is not configured. Review a separate logging destination and retention policy. |
| CKV_AWS_144 | Terraform state S3 bucket | Cross region replication is not configured for this short lived lab. Review disaster recovery requirements and cost. |
| CKV_AWS_145 | Terraform state S3 bucket | State uses SSE-S3 (`AES256`) rather than a customer managed KMS key. Review KMS access and recovery requirements before changing encryption. |

These scoped exceptions apply only to the listed resources in this learning
environment. Reassess every skipped control before production use. Keep
the remaining Checkov checks enforced in the `infra-scan` job.

## Kubernetes manifest exceptions

The application remains in the default namespace while its database Secret,
Service, and ALB Ingress are live. Moving them requires a coordinated migration.
CI uses a commit-specific Docker Hub tag; digest pinning is deferred. The
application currently reads its Secrets Manager managed database password from
a Kubernetes Secret environment variable; file-based delivery needs an app
change. EKS network policy enforcement is not configured, so adding a
NetworkPolicy manifest alone would not enforce traffic restrictions.

Checkov exceptions for CKV_K8S_21, CKV_K8S_43, CKV_K8S_35, and CKV2_K8S_6
are scoped to the BoundaryPass manifests. Reassess them before production use.
