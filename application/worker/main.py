import logging
import signal
import time
from uuid import UUID

from application.shared.adapters import LocalArtifactStore
from application.shared.config import get_settings
from application.shared.database import Database
from application.shared.logging import configure_logging
from application.shared.repository import Repository

logger = logging.getLogger("application.worker")
shutdown_requested = False


def _request_shutdown(signum, _frame) -> None:
    global shutdown_requested
    shutdown_requested = True
    logger.info("shutdown requested", extra={"service": "worker"})


def process_job(repository: Repository, artifact_store: LocalArtifactStore, job_id: UUID) -> None:
    job = repository.mark_job_processing(job_id)
    if job is None:
        existing = repository.get_job(job_id)
        if existing["status"] == "completed":
            logger.info("duplicate completed job ignored", extra={"service": "worker", "job_id": str(job_id)})
            return
        raise RuntimeError(f"job {job_id} is not processable")

    rows = [
        {"field": "job_id", "value": str(job_id)},
        {"field": "job_type", "value": job["job_type"]},
        {"field": "attempt", "value": str(job["attempts"])},
    ]
    object_key, object_type = artifact_store.put_csv_report(job_id, rows)
    result = {"report_key": object_key, "rows": len(rows)}
    repository.complete_job_with_report(job_id, result, object_key, object_type)
    logger.info("job completed", extra={"service": "worker", "job_id": str(job_id)})


def run_idle_worker() -> None:
    settings = get_settings()
    configure_logging(settings.log_level, "worker")
    signal.signal(signal.SIGINT, _request_shutdown)
    signal.signal(signal.SIGTERM, _request_shutdown)
    database = Database(settings.database_url)
    database.open()
    try:
        logger.info("worker foundation started; AWS SQS adapter arrives in later stage", extra={"service": "worker"})
        while not shutdown_requested:
            time.sleep(2)
    finally:
        database.close()
        logger.info("worker stopped", extra={"service": "worker"})


if __name__ == "__main__":
    run_idle_worker()

