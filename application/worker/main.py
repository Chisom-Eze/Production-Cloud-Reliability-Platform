import logging
import signal
import threading
import time
from enum import Enum
from typing import Any, Self
from uuid import UUID

from application.shared.adapters import (
    ArtifactStore,
    JobConsumer,
    JobPublisher,
    create_artifact_store,
    create_job_consumer,
    create_job_publisher,
)
from application.shared.config import get_settings
from application.shared.database import Database
from application.shared.logging import configure_logging
from application.shared.metrics import (
    WORKER_DUPLICATE_JOBS,
    WORKER_JOB_CLAIMS,
    WORKER_JOB_DURATION,
    WORKER_JOBS_PROCESSED,
    WORKER_OUTBOX_DISPATCH,
    WORKER_OUTBOX_RECLAIMS,
    WORKER_VISIBILITY_HEARTBEAT_FAILURES,
    start_worker_metrics_server,
)
from application.shared.repository import LostJobClaimError, Repository
from application.shared.telemetry import configure_tracing, tracer

logger = logging.getLogger("application.worker")
shutdown_requested = False
worker_tracer = tracer("application.worker")


class JobProcessStatus(str, Enum):
    COMPLETED = "completed"
    DUPLICATE_COMPLETED = "duplicate_completed"
    IN_PROGRESS_NOT_OWNED = "in_progress_not_owned"


class VisibilityHeartbeat:
    def __init__(
        self,
        repository: Repository,
        consumer: JobConsumer,
        job_id: UUID,
        processing_token: UUID,
        receipt_handle: str,
        visibility_timeout_seconds: int,
        heartbeat_seconds: int,
    ) -> None:
        self.repository = repository
        self.consumer = consumer
        self.job_id = job_id
        self.processing_token = processing_token
        self.receipt_handle = receipt_handle
        self.visibility_timeout_seconds = visibility_timeout_seconds
        self.heartbeat_seconds = heartbeat_seconds
        self._stop = threading.Event()
        self._thread = threading.Thread(
            target=self._run, name="sqs-visibility-heartbeat", daemon=True
        )

    def __enter__(self) -> Self:
        self._thread.start()
        return self

    def __exit__(self, _exc_type, _exc, _traceback) -> None:
        self._stop.set()
        self._thread.join(timeout=self.heartbeat_seconds + 1)

    def _run(self) -> None:
        while not self._stop.wait(self.heartbeat_seconds):
            lease_renewed = self.repository.renew_job_processing_lease(
                self.job_id, self.processing_token
            )
            if not lease_renewed:
                WORKER_VISIBILITY_HEARTBEAT_FAILURES.labels(
                    operation="db_lease_renewal"
                ).inc()
                logger.warning(
                    "job processing lease renewal skipped because ownership was lost",
                    extra={"service": "worker", "job_id": str(self.job_id)},
                )
                return
            try:
                self.consumer.change_visibility(
                    self.receipt_handle, self.visibility_timeout_seconds
                )
            except Exception as exc:  # noqa: BLE001 - record heartbeat retry evidence.
                WORKER_VISIBILITY_HEARTBEAT_FAILURES.labels(
                    operation="sqs_change_visibility"
                ).inc()
                logger.warning(
                    "SQS visibility heartbeat failed",
                    extra={
                        "service": "worker",
                        "job_id": str(self.job_id),
                        "error_type": type(exc).__name__,
                    },
                )


def _request_shutdown(signum, _frame) -> None:
    global shutdown_requested
    shutdown_requested = True
    logger.info("shutdown requested", extra={"service": "worker"})


def claim_job(
    repository: Repository, job_id: UUID, lease_seconds: int
) -> dict[str, Any] | JobProcessStatus:
    job = repository.mark_job_processing(job_id, lease_seconds)
    if job is None:
        existing = repository.get_job(job_id)
        if existing["status"] == "completed":
            WORKER_DUPLICATE_JOBS.labels(result="completed").inc()
            WORKER_JOB_CLAIMS.labels(result="duplicate_completed").inc()
            logger.info(
                "duplicate completed job ignored",
                extra={"service": "worker", "job_id": str(job_id)},
            )
            return JobProcessStatus.DUPLICATE_COMPLETED
        WORKER_JOB_CLAIMS.labels(result="in_progress_not_owned").inc()
        logger.info(
            "job is currently processing under another valid claim",
            extra={
                "service": "worker",
                "job_id": str(job_id),
                "status": existing["status"],
            },
        )
        return JobProcessStatus.IN_PROGRESS_NOT_OWNED
    WORKER_JOB_CLAIMS.labels(result="acquired").inc()
    return job


def complete_claimed_job(
    repository: Repository, artifact_store: ArtifactStore, job: dict[str, Any]
) -> JobProcessStatus:
    job_id = job["id"]
    job_type = job["job_type"]
    started = time.perf_counter()
    with worker_tracer.start_as_current_span("job.process") as span:
        span.set_attribute("job.type", job_type)
        try:
            rows = [
                {"field": "job_id", "value": str(job_id)},
                {"field": "job_type", "value": job_type},
                {"field": "attempt", "value": str(job["attempts"])},
            ]
            with worker_tracer.start_as_current_span("artifact.write"):
                object_key, object_type = artifact_store.put_csv_report(job_id, rows)
            result = {"report_key": object_key, "rows": len(rows)}
            repository.complete_job_with_report(
                job_id, job["processing_token"], result, object_key, object_type
            )
            WORKER_JOBS_PROCESSED.labels(job_type=job_type, result="success").inc()
            WORKER_JOB_DURATION.labels(job_type=job_type, result="success").observe(
                time.perf_counter() - started
            )
            logger.info(
                "job completed", extra={"service": "worker", "job_id": str(job_id)}
            )
            return JobProcessStatus.COMPLETED
        except Exception:
            WORKER_JOBS_PROCESSED.labels(job_type=job_type, result="failure").inc()
            WORKER_JOB_DURATION.labels(job_type=job_type, result="failure").observe(
                time.perf_counter() - started
            )
            raise


def process_job(
    repository: Repository,
    artifact_store: ArtifactStore,
    job_id: UUID,
    lease_seconds: int = 120,
) -> JobProcessStatus:
    job = claim_job(repository, job_id, lease_seconds)
    if isinstance(job, JobProcessStatus):
        return job
    try:
        return complete_claimed_job(repository, artifact_store, job)
    except LostJobClaimError:
        raise
    except Exception:
        repository.fail_job(job_id, job["processing_token"], "JobProcessingError")
        raise


def dispatch_outbox(
    repository: Repository,
    publisher: JobPublisher,
    limit: int = 10,
    lease_seconds: int = 120,
) -> int:
    dispatched = 0
    with worker_tracer.start_as_current_span("outbox.dispatch"):
        for event in repository.claim_outbox_events(limit, lease_seconds):
            event_id = event["id"]
            claim_token = event["claim_token"]
            payload: dict[str, Any] = event["payload"]
            if event["attempts"] > 1:
                WORKER_OUTBOX_RECLAIMS.labels(result="reclaimed").inc()
            try:
                WORKER_OUTBOX_DISPATCH.labels(result="attempt").inc()
                if event["event_type"] != "job.created" or event["version"] != 1:
                    raise ValueError("unsupported outbox event schema")
                publisher.publish(
                    UUID(str(payload["job_id"])), payload.get("correlation_id")
                )
                if repository.mark_outbox_published(event_id, claim_token):
                    WORKER_OUTBOX_DISPATCH.labels(result="success").inc()
                    dispatched += 1
            except Exception as exc:  # noqa: BLE001 - outbox retry needs failure capture.
                WORKER_OUTBOX_DISPATCH.labels(result="failure").inc()
                repository.mark_outbox_failed(event_id, claim_token, type(exc).__name__)
                logger.warning(
                    "outbox dispatch failed",
                    extra={
                        "service": "worker",
                        "event_id": str(event_id),
                        "error_type": type(exc).__name__,
                    },
                )
    return dispatched


def consume_one_message(
    repository: Repository,
    artifact_store: ArtifactStore,
    consumer: JobConsumer,
    *,
    processing_lease_seconds: int = 120,
    visibility_timeout_seconds: int = 60,
    visibility_heartbeat_seconds: int = 30,
) -> bool:
    with worker_tracer.start_as_current_span("sqs.consume"):
        try:
            message = consumer.receive_job()
        except Exception as exc:  # noqa: BLE001 - keep worker alive on receive failure.
            logger.warning(
                "invalid or unavailable SQS message",
                extra={"service": "worker", "error_type": type(exc).__name__},
            )
            return False
    if message is None:
        return False

    job_id, receipt_handle = message
    job = claim_job(repository, job_id, processing_lease_seconds)
    if job == JobProcessStatus.DUPLICATE_COMPLETED:
        consumer.delete(receipt_handle)
        return True
    if job == JobProcessStatus.IN_PROGRESS_NOT_OWNED:
        return False

    try:
        with VisibilityHeartbeat(
            repository,
            consumer,
            job_id,
            job["processing_token"],
            receipt_handle,
            visibility_timeout_seconds,
            visibility_heartbeat_seconds,
        ):
            complete_claimed_job(repository, artifact_store, job)
        consumer.delete(receipt_handle)
        return True
    except LostJobClaimError:
        logger.warning(
            "job claim was lost before completion",
            extra={"service": "worker", "job_id": str(job_id)},
        )
        return False
    except Exception as exc:
        repository.fail_job(job_id, job["processing_token"], type(exc).__name__)
        logger.exception(
            "job processing failed", extra={"service": "worker", "job_id": str(job_id)}
        )
        return False


def run_idle_worker() -> None:
    settings = get_settings()
    configure_logging(settings.log_level, "worker")
    configure_tracing(settings, "production-cloud-reliability-worker")
    if settings.metrics_enabled and not start_worker_metrics_server(
        settings.worker_metrics_host, settings.worker_metrics_port
    ):
        logger.warning(
            "worker metrics endpoint failed to start",
            extra={
                "service": "worker",
                "host": settings.worker_metrics_host,
                "port": settings.worker_metrics_port,
            },
        )
    signal.signal(signal.SIGINT, _request_shutdown)
    signal.signal(signal.SIGTERM, _request_shutdown)
    settings.validate_worker_runtime()
    database = Database(settings.database_conninfo())
    database.open()
    try:
        repository = Repository(database)
        artifact_store = create_artifact_store(settings)
        outbox_publisher = create_job_publisher(
            settings, direct_cloud_publish=settings.is_cloud
        )
        consumer = create_job_consumer(settings) if settings.is_cloud else None
        logger.info(
            "worker started",
            extra={"service": "worker", "runtime_mode": settings.runtime_mode},
        )
        while not shutdown_requested:
            dispatch_outbox(
                repository,
                outbox_publisher,
                lease_seconds=settings.outbox_claim_lease_seconds,
            )
            if consumer is not None:
                consume_one_message(
                    repository,
                    artifact_store,
                    consumer,
                    processing_lease_seconds=settings.job_processing_lease_seconds,
                    visibility_timeout_seconds=settings.sqs_visibility_timeout_seconds,
                    visibility_heartbeat_seconds=settings.sqs_visibility_heartbeat_seconds,
                )
            else:
                time.sleep(2)
    finally:
        database.close()
        logger.info("worker stopped", extra={"service": "worker"})


if __name__ == "__main__":
    run_idle_worker()
