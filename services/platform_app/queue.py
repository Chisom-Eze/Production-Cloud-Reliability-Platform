from typing import Any

import boto3

from platform_app.config import Settings


class QueueClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._client = boto3.client(
            "sqs",
            region_name=settings.aws_region,
            endpoint_url=settings.aws_endpoint_url,
        )
        self._queue_url = settings.sqs_queue_url

    @property
    def queue_url(self) -> str:
        if not self._queue_url:
            response = self._client.create_queue(QueueName=self.settings.sqs_queue_name)
            self._queue_url = response["QueueUrl"]
        return self._queue_url

    def check(self) -> bool:
        self._client.get_queue_attributes(
            QueueUrl=self.queue_url,
            AttributeNames=["QueueArn"],
        )
        return True

    def send_job(self, job_id: str, correlation_id: str | None) -> None:
        attributes: dict[str, Any] = {}
        if correlation_id:
            attributes["correlation_id"] = {
                "DataType": "String",
                "StringValue": correlation_id,
            }
        self._client.send_message(
            QueueUrl=self.queue_url,
            MessageBody=job_id,
            MessageAttributes=attributes,
        )

    def receive_messages(self, max_messages: int = 5, wait_seconds: int = 10) -> list[dict[str, Any]]:
        response = self._client.receive_message(
            QueueUrl=self.queue_url,
            MaxNumberOfMessages=max_messages,
            WaitTimeSeconds=wait_seconds,
            MessageAttributeNames=["All"],
        )
        return response.get("Messages", [])

    def delete_message(self, receipt_handle: str) -> None:
        self._client.delete_message(
            QueueUrl=self.queue_url,
            ReceiptHandle=receipt_handle,
        )

