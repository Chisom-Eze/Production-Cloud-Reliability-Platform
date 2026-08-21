from typing import Any
from uuid import UUID, uuid4

from psycopg.errors import UniqueViolation
from psycopg.types.json import Jsonb

from platform_app.db.database import Database


class DuplicateCustomerError(Exception):
    pass


class NotFoundError(Exception):
    pass


class InvalidJobTransitionError(Exception):
    pass


class Repository:
    def __init__(self, database: Database) -> None:
        self.database = database

    def check(self) -> bool:
        return self.database.check()

    def list_customers(self) -> list[dict[str, Any]]:
        with self.database.transaction() as connection:
            rows = connection.execute(
                """
                SELECT id, name, email, created_at
                FROM customers
                ORDER BY created_at DESC
                LIMIT 100
                """
            ).fetchall()
            return [dict(row) for row in rows]

    def create_customer(self, name: str, email: str) -> dict[str, Any]:
        customer_id = uuid4()
        audit_id = uuid4()
        try:
            with self.database.transaction() as connection:
                row = connection.execute(
                    """
                    INSERT INTO customers (id, name, email)
                    VALUES (%s, %s, %s)
                    RETURNING id, name, email, created_at
                    """,
                    (customer_id, name, email),
                ).fetchone()
                connection.execute(
                    """
                    INSERT INTO audit_events (id, entity_type, entity_id, action, details)
                    VALUES (%s, 'customer', %s, 'created', %s)
                    """,
                    (audit_id, customer_id, Jsonb({"email": email})),
                )
                return dict(row)
        except UniqueViolation as exc:
            raise DuplicateCustomerError("customer email already exists") from exc

    def list_jobs(self) -> list[dict[str, Any]]:
        with self.database.transaction() as connection:
            rows = connection.execute(
                """
                SELECT id, job_type, status, payload, attempts, last_error, created_at, updated_at
                FROM jobs
                ORDER BY created_at DESC
                LIMIT 100
                """
            ).fetchall()
            return [dict(row) for row in rows]

    def create_job(self, job_type: str, payload: dict[str, Any]) -> dict[str, Any]:
        job_id = uuid4()
        audit_id = uuid4()
        with self.database.transaction() as connection:
            row = connection.execute(
                """
                INSERT INTO jobs (id, job_type, status, payload)
                VALUES (%s, %s, 'pending', %s)
                RETURNING id, job_type, status, payload, attempts, last_error, created_at, updated_at
                """,
                (job_id, job_type, Jsonb(payload)),
            ).fetchone()
            connection.execute(
                """
                INSERT INTO audit_events (id, entity_type, entity_id, action, details)
                VALUES (%s, 'job', %s, 'created', %s)
                """,
                (audit_id, job_id, Jsonb({"job_type": job_type})),
            )
            return dict(row)

    def get_job(self, job_id: UUID) -> dict[str, Any]:
        with self.database.transaction() as connection:
            row = connection.execute(
                """
                SELECT j.id, j.job_type, j.status, j.payload, j.attempts, j.last_error,
                       j.created_at, j.updated_at, r.result
                FROM jobs j
                LEFT JOIN job_results r ON r.job_id = j.id
                WHERE j.id = %s
                """,
                (job_id,),
            ).fetchone()
            if not row:
                raise NotFoundError("job not found")
            return dict(row)

    def mark_job_processing(self, job_id: UUID) -> dict[str, Any] | None:
        with self.database.transaction() as connection:
            row = connection.execute(
                """
                UPDATE jobs
                SET status = 'processing',
                    attempts = attempts + 1,
                    updated_at = NOW()
                WHERE id = %s AND status IN ('pending', 'failed')
                RETURNING id, job_type, status, payload, attempts
                """,
                (job_id,),
            ).fetchone()
            return dict(row) if row else None

    def complete_job(self, job_id: UUID, result: dict[str, Any]) -> None:
        result_id = uuid4()
        audit_id = uuid4()
        with self.database.transaction() as connection:
            connection.execute(
                """
                INSERT INTO job_results (id, job_id, result)
                VALUES (%s, %s, %s)
                ON CONFLICT (job_id) DO NOTHING
                """,
                (result_id, job_id, Jsonb(result)),
            )
            updated = connection.execute(
                """
                UPDATE jobs
                SET status = 'completed',
                    last_error = NULL,
                    updated_at = NOW()
                WHERE id = %s
                """,
                (job_id,),
            ).rowcount
            if updated != 1:
                raise InvalidJobTransitionError("job could not be completed")
            connection.execute(
                """
                INSERT INTO audit_events (id, entity_type, entity_id, action, details)
                VALUES (%s, 'job', %s, 'completed', %s)
                """,
                (audit_id, job_id, Jsonb(result)),
            )

    def fail_job(self, job_id: UUID, error: str) -> None:
        with self.database.transaction() as connection:
            connection.execute(
                """
                UPDATE jobs
                SET status = 'failed',
                    last_error = %s,
                    updated_at = NOW()
                WHERE id = %s
                """,
                (error[:1000], job_id),
            )
