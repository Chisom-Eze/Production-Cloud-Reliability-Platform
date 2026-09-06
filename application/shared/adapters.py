import csv
import io
import json
from pathlib import Path
from typing import Protocol
from uuid import UUID, uuid4

import boto3

from application.shared.config import Settings


class JobPublisher(Protocol):
    def publish(self, job_id: UUID, correlation_id: str | None) -> None:
        ...


class ArtifactStore(Protocol):
    def put_csv_report(self, job_id: UUID, rows: list[dict[str, str]]) -> tuple[str, str]:
        ...


class JobConsumer(Protocol):
    def receive_job(self) -> tuple[UUID, str] | None:
        ...

    def change_visibility(self, receipt_handle: str, timeout_seconds: int) -> None:
        ...

    def delete(self, receipt_handle: str) -> None:
        ...


class LocalJobPublisher:
    """Stage 1 adapter: records the async boundary without requiring AWS SQS locally."""

    def __init__(self) -> None:
        self.published: list[tuple[UUID, str | None]] = []

    def publish(self, job_id: UUID, correlation_id: str | None) -> None:
        self.published.append((job_id, correlation_id))


class NoopJobPublisher:
    """Used by cloud API tasks when durable outbox dispatch is owned by workers."""

    def publish(self, job_id: UUID, correlation_id: str | None) -> None:
        return None


class SqsJobPublisher:
    def __init__(self, queue_url: str, region_name: str) -> None:
        self.queue_url = queue_url
        self.client = boto3.client("sqs", region_name=region_name)

    def publish(self, job_id: UUID, correlation_id: str | None) -> None:
        message = {
            "version": 1,
            "event_type": "job.created",
            "job_id": str(job_id),
        }
        if correlation_id:
            message["correlation_id"] = correlation_id
        self.client.send_message(
            QueueUrl=self.queue_url,
            MessageBody=json.dumps(message, separators=(",", ":")),
        )


class SqsJobConsumer:
    def __init__(self, queue_url: str, region_name: str, wait_time_seconds: int = 20) -> None:
        self.queue_url = queue_url
        self.wait_time_seconds = wait_time_seconds
        self.client = boto3.client("sqs", region_name=region_name)

    def receive_job(self) -> tuple[UUID, str] | None:
        response = self.client.receive_message(
            QueueUrl=self.queue_url,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=self.wait_time_seconds,
        )
        messages = response.get("Messages", [])
        if not messages:
            return None
        message = messages[0]
        payload = json.loads(message["Body"])
        if payload.get("version") != 1 or payload.get("event_type") != "job.created":
            raise ValueError("unsupported SQS job message schema")
        return UUID(str(payload["job_id"])), message["ReceiptHandle"]

    def delete(self, receipt_handle: str) -> None:
        self.client.delete_message(QueueUrl=self.queue_url, ReceiptHandle=receipt_handle)

    def change_visibility(self, receipt_handle: str, timeout_seconds: int) -> None:
        self.client.change_message_visibility(
            QueueUrl=self.queue_url,
            ReceiptHandle=receipt_handle,
            VisibilityTimeout=timeout_seconds,
        )


class LocalArtifactStore:
    """Stage 1 adapter: writes reports locally using the future S3 key pattern."""

    def __init__(self, root: str, prefix: str = "reports") -> None:
        self.root = Path(root)
        self.prefix = prefix.strip("/")

    def put_csv_report(self, job_id: UUID, rows: list[dict[str, str]]) -> tuple[str, str]:
        report_id = uuid4()
        object_key = f"{self.prefix}/{job_id}/{report_id}.csv"
        destination = self.root / object_key
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=["field", "value"])
            writer.writeheader()
            writer.writerows(rows)
        return object_key, "text/csv"


class S3ArtifactStore:
    def __init__(self, bucket_name: str, region_name: str, prefix: str = "reports") -> None:
        self.bucket_name = bucket_name
        self.prefix = prefix.strip("/")
        self.client = boto3.client("s3", region_name=region_name)

    def put_csv_report(self, job_id: UUID, rows: list[dict[str, str]]) -> tuple[str, str]:
        report_id = uuid4()
        object_key = f"{self.prefix}/{job_id}/{report_id}.csv"
        output = io.StringIO()
        fieldnames = ["field", "value"]
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
        self.client.put_object(
            Bucket=self.bucket_name,
            Key=object_key,
            Body=output.getvalue().encode("utf-8"),
            ContentType="text/csv",
        )
        return object_key, "text/csv"


def create_job_publisher(settings: Settings, *, direct_cloud_publish: bool = False) -> JobPublisher:
    if settings.is_cloud:
        if direct_cloud_publish:
            settings.validate_queue()
            return SqsJobPublisher(settings.sqs_queue_url or "", settings.aws_region)
        return NoopJobPublisher()
    return LocalJobPublisher()


def create_job_consumer(settings: Settings) -> JobConsumer:
    settings.validate_queue()
    return SqsJobConsumer(settings.sqs_queue_url or "", settings.aws_region)


def create_artifact_store(settings: Settings) -> ArtifactStore:
    if settings.artifact_backend == "s3":
        settings.validate_artifact_store()
        return S3ArtifactStore(settings.artifact_bucket_name or "", settings.aws_region, settings.artifact_prefix)
    return LocalArtifactStore(settings.local_artifact_root, settings.artifact_prefix)
