from uuid import uuid4

from application.worker.main import process_job


class FakeRepository:
    def __init__(self):
        self.completed = False
        self.processing_attempts = 0
        self.result = None
        self.object_key = None

    def mark_job_processing(self, job_id):
        self.processing_attempts += 1
        if self.completed:
            return None
        return {
            "id": job_id,
            "job_type": "csv_report",
            "status": "processing",
            "payload": {},
            "attempts": self.processing_attempts,
        }

    def get_job(self, job_id):
        return {"id": job_id, "status": "completed" if self.completed else "pending"}

    def complete_job_with_report(self, job_id, result, object_key, object_type):
        self.completed = True
        self.result = result
        self.object_key = object_key
        self.object_type = object_type


class FakeArtifactStore:
    def put_csv_report(self, job_id, rows):
        return f"reports/{job_id}/{uuid4()}.csv", "text/csv"


def test_process_job_generates_report_metadata():
    repository = FakeRepository()
    job_id = uuid4()

    process_job(repository, FakeArtifactStore(), job_id)

    assert repository.completed is True
    assert repository.object_key.startswith(f"reports/{job_id}/")
    assert repository.object_key.endswith(".csv")
    assert repository.result["rows"] == 3

