from uuid import uuid4

import pytest

from application.shared.adapters import S3ArtifactStore, SqsJobConsumer, SqsJobPublisher


class FakeSqsClient:
    def __init__(self, messages=None):
        self.messages = messages or []
        self.sent = []
        self.deleted = []

    def send_message(self, **kwargs):
        self.sent.append(kwargs)

    def receive_message(self, **kwargs):
        return {"Messages": self.messages}

    def delete_message(self, **kwargs):
        self.deleted.append(kwargs)


class FakeS3Client:
    def __init__(self):
        self.objects = []

    def put_object(self, **kwargs):
        self.objects.append(kwargs)


def test_sqs_publisher_sends_stable_json_schema(monkeypatch):
    fake_client = FakeSqsClient()
    monkeypatch.setattr("application.shared.adapters.boto3.client", lambda *_, **__: fake_client)
    job_id = uuid4()

    SqsJobPublisher("https://sqs.example/queue", "us-east-1").publish(job_id, "correlation-1")

    assert fake_client.sent[0]["QueueUrl"] == "https://sqs.example/queue"
    assert f'"job_id":"{job_id}"' in fake_client.sent[0]["MessageBody"]
    assert '"version":1' in fake_client.sent[0]["MessageBody"]


def test_sqs_consumer_rejects_unexpected_schema(monkeypatch):
    fake_client = FakeSqsClient(messages=[{"Body": '{"version":2}', "ReceiptHandle": "receipt"}])
    monkeypatch.setattr("application.shared.adapters.boto3.client", lambda *_, **__: fake_client)

    with pytest.raises(ValueError, match="unsupported SQS job message schema"):
        SqsJobConsumer("https://sqs.example/queue", "us-east-1").receive_job()


def test_s3_artifact_store_puts_csv_without_acl_or_kms(monkeypatch):
    fake_client = FakeS3Client()
    monkeypatch.setattr("application.shared.adapters.boto3.client", lambda *_, **__: fake_client)
    job_id = uuid4()

    object_key, object_type = S3ArtifactStore("artifact-bucket", "us-east-1").put_csv_report(
        job_id,
        [{"field": "job_id", "value": str(job_id)}],
    )

    request = fake_client.objects[0]
    assert object_key.startswith(f"reports/{job_id}/")
    assert object_type == "text/csv"
    assert request["Bucket"] == "artifact-bucket"
    assert request["ContentType"] == "text/csv"
    assert "ACL" not in request
    assert "ServerSideEncryption" not in request

