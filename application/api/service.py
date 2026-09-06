from uuid import UUID

from application.shared.adapters import JobPublisher
from application.shared.logging import correlation_id_var
from application.shared.repository import Repository


class ApplicationService:
    def __init__(self, repository: Repository, publisher: JobPublisher) -> None:
        self.repository = repository
        self.publisher = publisher

    def create_job(self, job_type: str, payload: dict):
        correlation_id = correlation_id_var.get()
        try:
            job = self.repository.create_job(job_type, payload, correlation_id)
        except TypeError:
            job = self.repository.create_job(job_type, payload)
        self.publisher.publish(job["id"], correlation_id)
        return job

    def get_job(self, job_id: UUID):
        return self.repository.get_job(job_id)
