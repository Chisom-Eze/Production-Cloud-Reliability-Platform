import csv
from pathlib import Path
from typing import Protocol
from uuid import UUID, uuid4


class JobPublisher(Protocol):
    def publish(self, job_id: UUID, correlation_id: str | None) -> None:
        ...


class ArtifactStore(Protocol):
    def put_csv_report(self, job_id: UUID, rows: list[dict[str, str]]) -> tuple[str, str]:
        ...


class LocalJobPublisher:
    """Stage 1 adapter: records the async boundary without requiring AWS SQS locally."""

    def __init__(self) -> None:
        self.published: list[tuple[UUID, str | None]] = []

    def publish(self, job_id: UUID, correlation_id: str | None) -> None:
        self.published.append((job_id, correlation_id))


class LocalArtifactStore:
    """Stage 1 adapter: writes reports locally using the future S3 key pattern."""

    def __init__(self, root: str) -> None:
        self.root = Path(root)

    def put_csv_report(self, job_id: UUID, rows: list[dict[str, str]]) -> tuple[str, str]:
        report_id = uuid4()
        object_key = f"reports/{job_id}/{report_id}.csv"
        destination = self.root / object_key
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=["field", "value"])
            writer.writeheader()
            writer.writerows(rows)
        return object_key, "text/csv"

