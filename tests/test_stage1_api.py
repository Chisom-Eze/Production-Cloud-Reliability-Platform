from datetime import UTC, datetime
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

from application.api.main import create_app
from application.api.service import ApplicationService
from application.shared.repository import DuplicateCustomerError, NotFoundError


class FakeRepository:
    def __init__(self, ready: bool = True) -> None:
        self.ready = ready
        self.customers = []
        self.jobs = []

    def check(self) -> bool:
        return self.ready

    def list_customers(self):
        return self.customers

    def create_customer(self, name: str, email: str):
        if any(customer["email"] == email for customer in self.customers):
            raise DuplicateCustomerError("customer email already exists")
        customer = {
            "id": uuid4(),
            "name": name,
            "email": email,
            "created_at": datetime.now(UTC),
        }
        self.customers.append(customer)
        return customer

    def create_job(self, job_type: str, payload: dict):
        job = {
            "id": uuid4(),
            "job_type": job_type,
            "status": "pending",
            "payload": payload,
            "attempts": 0,
            "last_error": None,
            "created_at": datetime.now(UTC),
            "updated_at": datetime.now(UTC),
            "result": None,
            "object_key": None,
            "object_type": None,
        }
        self.jobs.append(job)
        return job

    def get_job(self, job_id: UUID):
        for job in self.jobs:
            if job["id"] == job_id:
                return job
        raise NotFoundError("job not found")


class FakePublisher:
    def __init__(self) -> None:
        self.messages = []

    def publish(self, job_id: UUID, correlation_id: str | None) -> None:
        self.messages.append((job_id, correlation_id))


@pytest.fixture
def client_and_fakes():
    repository = FakeRepository()
    publisher = FakePublisher()
    service = ApplicationService(repository, publisher)
    app = create_app(repository=repository, service=service)
    return TestClient(app), repository, publisher


def test_health_endpoint_does_not_depend_on_readiness():
    repository = FakeRepository(ready=False)
    publisher = FakePublisher()
    service = ApplicationService(repository, publisher)
    client = TestClient(create_app(repository=repository, service=service))

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_readiness_reports_database_connectivity(client_and_fakes):
    client, _, _ = client_and_fakes

    response = client.get("/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready", "checks": {"database": True}}


def test_readiness_fails_when_database_unavailable():
    repository = FakeRepository(ready=False)
    publisher = FakePublisher()
    service = ApplicationService(repository, publisher)
    client = TestClient(create_app(repository=repository, service=service))

    response = client.get("/ready")

    assert response.status_code == 503
    assert response.json() == {"status": "not_ready", "checks": {"database": False}}


def test_customer_creation_and_retrieval(client_and_fakes):
    client, _, _ = client_and_fakes

    created = client.post("/customers", json={"name": "Ada Lovelace", "email": "ada@example.com"})
    listed = client.get("/customers")

    assert created.status_code == 201
    assert created.json()["email"] == "ada@example.com"
    assert listed.status_code == 200
    assert len(listed.json()) == 1


def test_job_creation_and_retrieval_publishes_async_boundary(client_and_fakes):
    client, _, publisher = client_and_fakes

    created = client.post(
        "/jobs",
        headers={"x-correlation-id": "incident-123"},
        json={"job_type": "csv_report", "payload": {"customer": "all"}},
    )
    fetched = client.get(f"/jobs/{created.json()['id']}")

    assert created.status_code == 202
    assert fetched.status_code == 200
    assert fetched.json()["status"] == "pending"
    assert publisher.messages[0][1] == "incident-123"


def test_metrics_endpoint_exposes_prometheus_text(client_and_fakes):
    client, _, _ = client_and_fakes

    response = client.get("/metrics")

    assert response.status_code == 200
    assert "app_http_requests_total" in response.text

