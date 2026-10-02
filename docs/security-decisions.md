# Infrastructure security decisions

BoundaryPass is a short lived learning environment. The application release job
runs separately from the infrastructure Checkov scan. The original scan had 120 passed checks and 11 failed checks. Controls
marked Resolved below have since been implemented. The remaining lab
decisions use resource-specific Checkov exceptions and appear as skipped.

| Check | Resource | Decision |
| --- | --- | --- |
| CKV_AWS_58 | EKS | EKS 1.35 encrypts Kubernetes API data by default. No customer-managed KMS key is configured; review key control and cost before production use. |
| CKV_AWS_39 | EKS | The public API endpoint is needed for administration from the laptop and is restricted by `api_access_cidr`. Use private access only when an administrative network path is available. |
| CKV_AWS_353 | RDS | Resolved: Database Insights Standard collects detailed metrics with 7-day retention. |
| CKV_AWS_354 | RDS | Database Insights uses an AWS-managed KMS key. A customer-managed key adds key management and cost; review before production use. |
| CKV_AWS_161 | RDS | Resolved: the application uses the dedicated boundarypass_app PostgreSQL IAM user through EKS Pod Identity. The live Deployment has no database password Secret reference; an IAM connection to RDS was verified. |
| CKV_AWS_293 | RDS | Resolved: deletion protection is enabled. For a planned teardown, verify that a manual snapshot is available before deliberately disabling protection and destroying the instance. |
| CKV_AWS_118 | RDS | Resolved: RDS Enhanced Monitoring runs at a 60-second interval using the dedicated monitoring IAM role. CloudWatch Logs usage adds cost. |
| CKV_AWS_158 | VPC flow logs | Resolved: a customer-managed KMS key encrypts new VPC flow log events, with key use restricted to this log group. Retain the key while encrypted logs need to remain readable. |
| CKV_AWS_338 | VPC flow logs | Resolved: rejected VPC traffic logs are retained for 365 days. |
| CKV2_AWS_62 | Terraform state S3 bucket | Resolved: S3 sends object creation and deletion events through EventBridge to a KMS-encrypted CloudWatch log group with 365-day retention. Delivery was verified with a temporary object. |
| CKV2_AWS_30 | RDS | Resolved: the PostgreSQL parameter group logs DDL and queries taking at least one second. Restrict access to PostgreSQL logs because queries may contain sensitive data. |
| CKV_AWS_18 | Terraform state S3 bucket | Bucket access logging is not configured. Review a separate logging destination and retention policy. |
| CKV_AWS_144 | Terraform state S3 bucket | Cross region replication is not configured for this short lived lab. Review disaster recovery requirements and cost. |
| CKV_AWS_145 | Terraform state S3 bucket | Resolved: the bucket defaults to SSE-KMS with a customer managed key and S3 Bucket Keys. The Terraform backend uses that key for state and lock writes; a lock version was verified as SSE-KMS. Retain the key while any encrypted state version may be needed. |

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
