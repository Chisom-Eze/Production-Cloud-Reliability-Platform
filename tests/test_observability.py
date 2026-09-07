import json
import logging
from uuid import uuid4

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider

from application.shared.logging import JsonFormatter
from application.shared.metrics import generate_latest, start_worker_metrics_server
from application.worker.main import JobProcessStatus, consume_one_message, process_job


class FakeRepository:
    def __init__(self, status="pending"):
        self.status = status
        self.failed = []
        self.completed = []
        self.token = uuid4()

    def mark_job_processing(self, job_id, lease_seconds=120):
        if self.status == "completed":
            return None
        if self.status == "processing":
            return None
        self.status = "processing"
        return {
            "id": job_id,
            "job_type": "csv_report",
            "status": "processing",
            "payload": {},
            "attempts": 1,
            "processing_token": self.token,
        }

    def get_job(self, job_id):
        return {"id": job_id, "status": self.status}

    def complete_job_with_report(
        self, job_id, processing_token, result, object_key, object_type
    ):
        self.status = "completed"
        self.completed.append((job_id, result, object_key, object_type))

    def fail_job(self, job_id, processing_token, error):
        self.status = "failed"
        self.failed.append((job_id, error))
        return True


class FakeArtifactStore:
    def __init__(self, fail=False):
        self.fail = fail

    def put_csv_report(self, job_id, rows):
        if self.fail:
            raise RuntimeError("artifact write failed")
        return f"reports/{job_id}/{uuid4()}.csv", "text/csv"


class FakeConsumer:
    def __init__(self, job_id):
        self.job_id = job_id
        self.deleted = []

    def receive_job(self):
        return self.job_id, "receipt-1"

    def change_visibility(self, receipt_handle, timeout_seconds):
        return None

    def delete(self, receipt_handle):
        self.deleted.append(receipt_handle)


def test_worker_metrics_endpoint_failure_does_not_raise(monkeypatch):
    def fail_start_http_server(*_args, **_kwargs):
        raise OSError("port unavailable")

    monkeypatch.setattr(
        "application.shared.metrics.start_http_server", fail_start_http_server
    )

    assert start_worker_metrics_server("127.0.0.1", 9464) is False


def test_successful_job_increments_success_metric():
    repository = FakeRepository()
    job_id = uuid4()

    assert (
        process_job(repository, FakeArtifactStore(), job_id)
        == JobProcessStatus.COMPLETED
    )

    metrics = generate_latest().decode("utf-8")
    assert (
        'worker_jobs_processed_total{job_type="csv_report",result="success"}' in metrics
    )
    assert str(job_id) not in metrics


def test_failed_job_increments_failure_metric_and_does_not_delete_message():
    repository = FakeRepository()
    job_id = uuid4()
    consumer = FakeConsumer(job_id)

    assert (
        consume_one_message(repository, FakeArtifactStore(fail=True), consumer) is False
    )

    metrics = generate_latest().decode("utf-8")
    assert (
        'worker_jobs_processed_total{job_type="csv_report",result="failure"}' in metrics
    )
    assert consumer.deleted == []


def test_duplicate_handling_increments_bounded_duplicate_metric():
    repository = FakeRepository(status="completed")
    job_id = uuid4()

    assert (
        process_job(repository, FakeArtifactStore(), job_id)
        == JobProcessStatus.DUPLICATE_COMPLETED
    )

    metrics = generate_latest().decode("utf-8")
    assert 'worker_duplicate_jobs_total{result="completed"}' in metrics
    assert str(job_id) not in metrics


def test_logging_emits_trace_context_when_span_exists():
    trace.set_tracer_provider(TracerProvider())
    tracer = trace.get_tracer("test")
    formatter = JsonFormatter()

    with tracer.start_as_current_span("test-span"):
        record = logging.LogRecord("test", logging.INFO, __file__, 1, "hello", (), None)
        payload = json.loads(formatter.format(record))

    assert payload["trace_id"] is not None
    assert payload["span_id"] is not None


def test_logging_is_valid_without_active_span():
    formatter = JsonFormatter()
    record = logging.LogRecord("test", logging.INFO, __file__, 1, "hello", (), None)

    payload = json.loads(formatter.format(record))

    assert payload["trace_id"] is None
    assert payload["span_id"] is None
