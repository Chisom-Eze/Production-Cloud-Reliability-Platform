import logging
import signal
import time
from uuid import UUID

from platform_app.config import get_settings
from platform_app.db.database import Database
from platform_app.db.repository import Repository
from platform_app.logging import configure_logging, correlation_id_var
from platform_app.queue import QueueClient

logger = logging.getLogger("platform.worker")
shutdown_requested = False


def _request_shutdown(signum, _frame) -> None:
    global shutdown_requested
    shutdown_requested = True
    logger.info("shutdown requested", extra={"signal": signum})


def process_job(repository: Repository, job_id: UUID) -> None:
    job = repository.mark_job_processing(job_id)
    if job is None:
        existing = repository.get_job(job_id)
        if existing["status"] == "completed":
            logger.info("duplicate completed job ignored", extra={"job_id": str(job_id)})
            return
        raise RuntimeError(f"job {job_id} is not processable")

    result = {
        "processed": True,
        "job_type": job["job_type"],
        "attempt": job["attempts"],
    }
    repository.complete_job(job_id, result)
    logger.info("job completed", extra={"job_id": str(job_id)})


def run() -> None:
    settings = get_settings()
    configure_logging(settings.log_level)
    signal.signal(signal.SIGINT, _request_shutdown)
    signal.signal(signal.SIGTERM, _request_shutdown)

    database = Database(settings.database_url)
    database.open()
    repository = Repository(database)
    queue_client = QueueClient(settings)

    logger.info("worker started")
    try:
        while not shutdown_requested:
            messages = queue_client.receive_messages()
            if not messages:
                continue

            for message in messages:
                receipt_handle = message["ReceiptHandle"]
                attributes = message.get("MessageAttributes", {})
                correlation_id = attributes.get("correlation_id", {}).get("StringValue")
                token = correlation_id_var.set(correlation_id)
                try:
                    job_id = UUID(message["Body"])
                    process_job(repository, job_id)
                    queue_client.delete_message(receipt_handle)
                except Exception as exc:
                    if "job_id" in locals():
                        repository.fail_job(job_id, str(exc))
                        logger.exception("job failed", extra={"job_id": str(job_id)})
                    else:
                        logger.exception("invalid job message", extra={"error": str(exc)})
                finally:
                    if "job_id" in locals():
                        del job_id
                    correlation_id_var.reset(token)
            time.sleep(0.1)
    finally:
        database.close()
        logger.info("worker stopped")


if __name__ == "__main__":
    run()
