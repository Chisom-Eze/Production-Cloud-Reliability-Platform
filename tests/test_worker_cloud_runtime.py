import threading
import time
from uuid import uuid4

import pytest

from application.shared.repository import LostJobClaimError
from application.worker.main import JobProcessStatus, consume_one_message, dispatch_outbox, process_job


class FakeRepository:
    def __init__(self):
        self.jobs = {}
        self.completed = []
        self.failed = []
        self.renewals = []
        self.outbox = []
        self.published = []
        self.outbox_failures = []
        self.now = 1000
        self._lock = threading.Lock()
        self.force_publish_mark_failure = False

    def add_job(self, job_id, status="pending", *, started_at=None, token=None):
        self.jobs[job_id] = {
            "id": job_id,
            "job_type": "csv_report",
            "status": status,
            "payload": {},
            "attempts": 0,
            "processing_token": token,
            "processing_started_at": started_at,
        }

    def mark_job_processing(self, job_id, lease_seconds=120):
        with self._lock:
            job = self.jobs[job_id]
            stale = (
                job["status"] == "processing"
                and job["processing_started_at"] is not None
                and job["processing_started_at"] < self.now - lease_seconds
            )
            if job["status"] not in {"pending", "failed"} and not stale:
                return None
            token = uuid4()
            job.update(
                {
                    "status": "processing",
                    "attempts": job["attempts"] + 1,
                    "processing_token": token,
                    "processing_started_at": self.now,
                }
            )
            return dict(job)

    def renew_job_processing_lease(self, job_id, processing_token):
        job = self.jobs[job_id]
        if job["status"] == "processing" and job["processing_token"] == processing_token:
            job["processing_started_at"] = self.now
            self.renewals.append((job_id, processing_token))
            return True
        return False

    def get_job(self, job_id):
        return dict(self.jobs[job_id])

    def complete_job_with_report(self, job_id, processing_token, result, object_key, object_type):
        job = self.jobs[job_id]
        if job["status"] != "processing" or job["processing_token"] != processing_token:
            raise LostJobClaimError("lost claim")
        job.update({"status": "completed", "processing_token": None, "processing_started_at": None})
        self.completed.append((job_id, result, object_key, object_type))

    def fail_job(self, job_id, processing_token, error):
        job = self.jobs[job_id]
        if job["status"] != "processing" or job["processing_token"] != processing_token:
            return False
        job.update({"status": "failed", "processing_token": None, "processing_started_at": None, "last_error": error})
        self.failed.append((job_id, error))
        return True

    def claim_outbox_events(self, limit=10, lease_seconds=120):
        claimed = []
        batch_token = uuid4()
        for event in self.outbox:
            stale = (
                event["status"] == "publishing"
                and event.get("locked_at") is not None
                and event["locked_at"] < self.now - lease_seconds
            )
            if event["status"] in {"pending", "failed"} or stale:
                event.update(
                    {
                        "status": "publishing",
                        "attempts": event.get("attempts", 0) + 1,
                        "locked_at": self.now,
                        "claim_token": batch_token,
                    }
                )
                claimed.append(dict(event))
            if len(claimed) >= limit:
                break
        return claimed

    def mark_outbox_published(self, event_id, claim_token):
        if self.force_publish_mark_failure:
            return False
        for event in self.outbox:
            if event["id"] == event_id and event["status"] == "publishing" and event["claim_token"] == claim_token:
                event.update({"status": "published", "claim_token": None, "locked_at": None, "last_error": None})
                self.published.append(event_id)
                return True
        return False

    def mark_outbox_failed(self, event_id, claim_token, error):
        for event in self.outbox:
            if event["id"] == event_id and event["status"] == "publishing" and event["claim_token"] == claim_token:
                event.update({"status": "failed", "claim_token": None, "locked_at": None, "last_error": error})
                self.outbox_failures.append((event_id, error))
                return True
        return False


class FakeArtifactStore:
    def __init__(self, *, fail=False, delay_seconds=0):
        self.fail = fail
        self.delay_seconds = delay_seconds
        self.puts = 0

    def put_csv_report(self, job_id, rows):
        self.puts += 1
        if self.delay_seconds:
            time.sleep(self.delay_seconds)
        if self.fail:
            raise RuntimeError("artifact failed")
        return f"reports/{job_id}/{uuid4()}.csv", "text/csv"


class FakePublisher:
    def __init__(self):
        self.published = []

    def publish(self, job_id, correlation_id):
        self.published.append((job_id, correlation_id))


class FakeConsumer:
    def __init__(self, message):
        self.message = message
        self.deleted = []
        self.visibility_changes = []

    def receive_job(self):
        return self.message

    def change_visibility(self, receipt_handle, timeout_seconds):
        self.visibility_changes.append((receipt_handle, timeout_seconds))

    def delete(self, receipt_handle):
        self.deleted.append(receipt_handle)


def make_outbox_event(job_id, *, status="pending", locked_at=None, claim_token=None):
    return {
        "id": uuid4(),
        "event_type": "job.created",
        "version": 1,
        "payload": {"job_id": str(job_id), "correlation_id": "corr"},
        "status": status,
        "attempts": 0,
        "locked_at": locked_at,
        "claim_token": claim_token,
    }


def test_only_one_concurrent_worker_can_claim_pending_job():
    repository = FakeRepository()
    job_id = uuid4()
    repository.add_job(job_id)
    barrier = threading.Barrier(2)
    results = []

    def claim():
        barrier.wait()
        results.append(repository.mark_job_processing(job_id, 120))

    threads = [threading.Thread(target=claim), threading.Thread(target=claim)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    assert sum(result is not None for result in results) == 1


def test_fresh_processing_job_cannot_be_claimed_by_second_worker():
    repository = FakeRepository()
    job_id = uuid4()
    repository.add_job(job_id, status="processing", started_at=990, token=uuid4())

    assert repository.mark_job_processing(job_id, 120) is None


def test_stale_processing_job_can_be_reclaimed_with_new_token():
    repository = FakeRepository()
    job_id = uuid4()
    old_token = uuid4()
    repository.add_job(job_id, status="processing", started_at=800, token=old_token)

    claimed = repository.mark_job_processing(job_id, 120)

    assert claimed is not None
    assert claimed["processing_token"] != old_token


def test_stale_worker_cannot_complete_after_newer_reclaim():
    repository = FakeRepository()
    job_id = uuid4()
    old_token = uuid4()
    repository.add_job(job_id, status="processing", started_at=800, token=old_token)
    newer_claim = repository.mark_job_processing(job_id, 120)

    with pytest.raises(LostJobClaimError):
        repository.complete_job_with_report(job_id, old_token, {"ok": True}, "old.csv", "text/csv")

    assert newer_claim["processing_token"] != old_token
    assert repository.completed == []


def test_stale_worker_cannot_mark_failed_after_ownership_is_lost():
    repository = FakeRepository()
    job_id = uuid4()
    old_token = uuid4()
    repository.add_job(job_id, status="processing", started_at=800, token=old_token)
    repository.mark_job_processing(job_id, 120)

    assert repository.fail_job(job_id, old_token, "RuntimeError") is False
    assert repository.failed == []


def test_duplicate_completed_job_does_not_create_another_artifact():
    repository = FakeRepository()
    artifact_store = FakeArtifactStore()
    job_id = uuid4()
    repository.add_job(job_id)

    assert process_job(repository, artifact_store, job_id) == JobProcessStatus.COMPLETED
    assert process_job(repository, artifact_store, job_id) == JobProcessStatus.DUPLICATE_COMPLETED

    assert artifact_store.puts == 1


def test_duplicate_fresh_processing_does_not_call_fail_job():
    repository = FakeRepository()
    job_id = uuid4()
    repository.add_job(job_id, status="processing", started_at=999, token=uuid4())
    consumer = FakeConsumer((job_id, "receipt-1"))

    assert consume_one_message(repository, FakeArtifactStore(), consumer) is False

    assert repository.failed == []
    assert consumer.deleted == []


def test_outbox_pending_event_can_be_claimed():
    repository = FakeRepository()
    event = make_outbox_event(uuid4())
    repository.outbox = [event]

    claimed = repository.claim_outbox_events(10, 120)

    assert len(claimed) == 1
    assert claimed[0]["claim_token"] is not None


def test_fresh_publishing_outbox_event_cannot_be_reclaimed():
    repository = FakeRepository()
    repository.outbox = [make_outbox_event(uuid4(), status="publishing", locked_at=990, claim_token=uuid4())]

    assert repository.claim_outbox_events(10, 120) == []


def test_stale_publishing_outbox_event_can_be_reclaimed():
    repository = FakeRepository()
    repository.outbox = [make_outbox_event(uuid4(), status="publishing", locked_at=800, claim_token=uuid4())]

    assert len(repository.claim_outbox_events(10, 120)) == 1


def test_reclaimed_outbox_event_receives_new_claim_token():
    repository = FakeRepository()
    old_token = uuid4()
    repository.outbox = [make_outbox_event(uuid4(), status="publishing", locked_at=800, claim_token=old_token)]

    claimed = repository.claim_outbox_events(10, 120)

    assert claimed[0]["claim_token"] != old_token


def test_stale_outbox_claimant_cannot_mark_newer_claim_published():
    repository = FakeRepository()
    old_token = uuid4()
    event = make_outbox_event(uuid4(), status="publishing", locked_at=800, claim_token=old_token)
    repository.outbox = [event]
    repository.claim_outbox_events(10, 120)

    assert repository.mark_outbox_published(event["id"], old_token) is False
    assert event["status"] == "publishing"


def test_stale_outbox_claimant_cannot_mark_newer_claim_failed():
    repository = FakeRepository()
    old_token = uuid4()
    event = make_outbox_event(uuid4(), status="publishing", locked_at=800, claim_token=old_token)
    repository.outbox = [event]
    repository.claim_outbox_events(10, 120)

    assert repository.mark_outbox_failed(event["id"], old_token, "RuntimeError") is False
    assert event["status"] == "publishing"


def test_send_success_then_publish_mark_failure_can_safely_redispatch():
    repository = FakeRepository()
    job_id = uuid4()
    repository.outbox = [make_outbox_event(job_id)]
    repository.force_publish_mark_failure = True
    publisher = FakePublisher()

    assert dispatch_outbox(repository, publisher, lease_seconds=120) == 0

    repository.force_publish_mark_failure = False
    repository.outbox[0]["locked_at"] = 800

    assert dispatch_outbox(repository, publisher, lease_seconds=120) == 1
    assert publisher.published == [(job_id, "corr"), (job_id, "corr")]


def test_worker_deletes_message_only_after_durable_completion():
    repository = FakeRepository()
    job_id = uuid4()
    repository.add_job(job_id)
    consumer = FakeConsumer((job_id, "receipt-1"))

    assert consume_one_message(repository, FakeArtifactStore(), consumer) is True

    assert consumer.deleted == ["receipt-1"]
    assert repository.completed


def test_processing_failure_does_not_delete_sqs_message():
    repository = FakeRepository()
    job_id = uuid4()
    repository.add_job(job_id)
    consumer = FakeConsumer((job_id, "receipt-1"))

    assert consume_one_message(repository, FakeArtifactStore(fail=True), consumer) is False

    assert consumer.deleted == []
    assert repository.failed[0][0] == job_id


def test_visibility_heartbeat_renews_db_lease_and_sqs_visibility():
    repository = FakeRepository()
    job_id = uuid4()
    repository.add_job(job_id)
    consumer = FakeConsumer((job_id, "receipt-1"))

    assert consume_one_message(
        repository,
        FakeArtifactStore(delay_seconds=0.05),
        consumer,
        visibility_timeout_seconds=60,
        visibility_heartbeat_seconds=0.01,
    )

    assert repository.renewals
    assert consumer.visibility_changes
