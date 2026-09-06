# S3 Artifacts Module

This module creates one private S3 bucket for application-generated artifacts.

## Owned Resources

- Private S3 bucket.
- Complete S3 Public Access Block.
- Bucket owner enforced object ownership.
- SSE-S3 server-side encryption.
- Bucket versioning.
- Lifecycle cleanup for incomplete multipart uploads and noncurrent versions.
- TLS-only bucket policy.

## Artifact Contract

The initial application artifact is a CSV report stored under:

```text
reports/{job_id}/{report_id}.csv
```

PostgreSQL stores durable object references. S3 stores the artifact data. ECS container filesystems are not durable artifact storage.

## Security

The bucket is not public and is not configured for static website hosting. Public ACLs and public bucket policies are blocked. Object ownership is `BucketOwnerEnforced`, so ACLs are disabled.

Encryption uses SSE-S3 with `AES256`. This module does not create customer-managed KMS keys or aliases.

The bucket policy denies requests made without TLS by checking `aws:SecureTransport = false`. It does not grant public access.

## Lifecycle

Current artifacts are not automatically expired by this module. Current-object retention is a business and data-retention decision.

The lifecycle rule aborts incomplete multipart uploads and expires old noncurrent versions to limit operational waste from failed uploads, overwrites, and delete markers.

## Future IAM

Future worker access should be scoped to object actions under `reports/*`. Delete permissions should be added only if the application implements a real artifact-delete workflow.
