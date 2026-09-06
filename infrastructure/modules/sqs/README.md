# SQS Job Queue Module

This module creates one Standard SQS job queue and its dedicated dead-letter queue.

## Owned Resources

- Main Standard SQS queue.
- Dedicated DLQ.
- Main queue redrive policy.
- DLQ redrive allow policy restricted to the main queue.
- TLS-only queue resource policies.

## Delivery Semantics

SQS Standard provides at-least-once delivery. Messages can be duplicated or delivered out of order. Worker code must be idempotent and use durable job state to avoid duplicate side effects.

## Failure Flow

The worker receives a message and the message becomes invisible for the visibility timeout. If durable processing succeeds, the worker deletes the message. If processing fails, the worker does not delete it. After visibility expires, the message can be retried. After `max_receive_count` failed receives, SQS moves the message to the DLQ.

Long-running work must either complete within the visibility timeout or call `ChangeMessageVisibility`.

## Security

Both queues use SQS-managed server-side encryption. The module does not create customer-managed KMS keys.

Queue resource policies deny requests when `aws:SecureTransport = false`. They do not grant public access or cross-account access.

Future API and worker IAM permissions should be identity-based and least-privilege.
