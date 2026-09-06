from typing import Any
from uuid import UUID, uuid4

from psycopg.errors import UniqueViolation
from psycopg.types.json import Jsonb

from application.shared.database import Database


class DuplicateCustomerError(Exception):
    pass


class NotFoundError(Exception):
    pass


class LostJobClaimError(Exception):
    pass


class Repository:
    def __init__(self, database: Database) -> None:
        self.database = database

    def check(self) -> bool:
        return self.database.check()

    def list_customers(self) -> list[dict[str, Any]]:
        with self.database.transaction() as connection:
            return [
                dict(row)
                for row in connection.execute(
                    """
                    SELECT id, name, email, created_at
                    FROM customers
                    ORDER BY created_at DESC
                    LIMIT 100
                    """
                ).fetchall()
            ]

    def create_customer(self, name: str, email: str) -> dict[str, Any]:
        customer_id = uuid4()
        try:
            with self.database.transaction() as connection:
                customer = connection.execute(
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
                    (uuid4(), customer_id, Jsonb({"email": email})),
                )
                return dict(customer)
        except UniqueViolation as exc:
            raise DuplicateCustomerError("customer email already exists") from exc

    def create_job(self, job_type: str, payload: dict[str, Any], correlation_id: str | None = None) -> dict[str, Any]:
        job_id = uuid4()
        outbox_payload = {
            "version": 1,
            "event_type": "job.created",
            "job_id": str(job_id),
        }
        if correlation_id:
            outbox_payload["correlation_id"] = correlation_id
        with self.database.transaction() as connection:
            job = connection.execute(
                """
                INSERT INTO jobs (id, job_type, status, payload)
                VALUES (%s, %s, 'pending', %s)
                RETURNING id, job_type, status, payload, attempts, last_error, created_at, updated_at
                """,
                (job_id, job_type, Jsonb(payload)),
            ).fetchone()
            connection.execute(
                """
                INSERT INTO job_outbox (id, event_type, version, payload)
                VALUES (%s, 'job.created', 1, %s)
                """,
                (
                    uuid4(),
                    Jsonb(outbox_payload),
                ),
            )
            connection.execute(
                """
                INSERT INTO audit_events (id, entity_type, entity_id, action, details)
                VALUES (%s, 'job', %s, 'created', %s)
                """,
                (uuid4(), job_id, Jsonb({"job_type": job_type})),
            )
            return dict(job)

    def claim_outbox_events(self, limit: int = 10, lease_seconds: int = 120) -> list[dict[str, Any]]:
        claim_token = uuid4()
        with self.database.transaction() as connection:
            rows = connection.execute(
                """
                WITH claimed AS (
                    SELECT id
                    FROM job_outbox
                    WHERE status IN ('pending', 'failed')
                       OR (
                            status = 'publishing'
                            AND locked_at < NOW() - (%s * INTERVAL '1 second')
                       )
                    ORDER BY created_at
                    LIMIT %s
                    FOR UPDATE SKIP LOCKED
                )
                UPDATE job_outbox o
                SET status = 'publishing',
                    attempts = attempts + 1,
                    locked_at = NOW(),
                    claim_token = %s,
                    updated_at = NOW()
                FROM claimed
                WHERE o.id = claimed.id
                RETURNING o.id, o.event_type, o.version, o.payload, o.attempts, o.claim_token
                """,
                (lease_seconds, limit, claim_token),
            ).fetchall()
            return [dict(row) for row in rows]

    def mark_outbox_published(self, event_id: UUID, claim_token: UUID) -> bool:
        with self.database.transaction() as connection:
            result = connection.execute(
                """
                UPDATE job_outbox
                SET status = 'published',
                    published_at = NOW(),
                    updated_at = NOW(),
                    last_error = NULL,
                    locked_at = NULL,
                    claim_token = NULL
                WHERE id = %s
                  AND status = 'publishing'
                  AND claim_token = %s
                """,
                (event_id, claim_token),
            )
            return result.rowcount == 1

    def mark_outbox_failed(self, event_id: UUID, claim_token: UUID, error: str) -> bool:
        with self.database.transaction() as connection:
            result = connection.execute(
                """
                UPDATE job_outbox
                SET status = 'failed',
                    last_error = %s,
                    locked_at = NULL,
                    claim_token = NULL,
                    updated_at = NOW()
                WHERE id = %s
                  AND status = 'publishing'
                  AND claim_token = %s
                """,
                (error[:1000], event_id, claim_token),
            )
            return result.rowcount == 1

    def get_job(self, job_id: UUID) -> dict[str, Any]:
        with self.database.transaction() as connection:
            row = connection.execute(
                """
                SELECT j.id, j.job_type, j.status, j.payload, j.attempts, j.last_error,
                       j.created_at, j.updated_at, r.result, o.object_key, o.object_type
                FROM jobs j
                LEFT JOIN job_results r ON r.job_id = j.id
                LEFT JOIN object_metadata o ON o.job_id = j.id
                WHERE j.id = %s
                """,
                (job_id,),
            ).fetchone()
            if not row:
                raise NotFoundError("job not found")
            return dict(row)

    def mark_job_processing(self, job_id: UUID, lease_seconds: int = 120) -> dict[str, Any] | None:
        processing_token = uuid4()
        with self.database.transaction() as connection:
            row = connection.execute(
                """
                UPDATE jobs
                SET status = 'processing',
                    attempts = attempts + 1,
                    processing_token = %s,
                    processing_started_at = NOW(),
                    updated_at = NOW()
                WHERE id = %s
                  AND (
                    status IN ('pending', 'failed')
                    OR (
                        status = 'processing'
                        AND processing_started_at < NOW() - (%s * INTERVAL '1 second')
                    )
                  )
                RETURNING id, job_type, status, payload, attempts, processing_token, processing_started_at
                """,
                (processing_token, job_id, lease_seconds),
            ).fetchone()
            return dict(row) if row else None

    def renew_job_processing_lease(self, job_id: UUID, processing_token: UUID) -> bool:
        with self.database.transaction() as connection:
            result = connection.execute(
                """
                UPDATE jobs
                SET processing_started_at = NOW(),
                    updated_at = NOW()
                WHERE id = %s
                  AND status = 'processing'
                  AND processing_token = %s
                """,
                (job_id, processing_token),
            )
            return result.rowcount == 1

    def complete_job_with_report(
        self,
        job_id: UUID,
        processing_token: UUID,
        result: dict[str, Any],
        object_key: str,
        object_type: str,
    ) -> None:
        with self.database.transaction() as connection:
            fenced = connection.execute(
                """
                UPDATE jobs
                SET status = 'completed',
                    last_error = NULL,
                    processing_token = NULL,
                    processing_started_at = NULL,
                    updated_at = NOW()
                WHERE id = %s
                  AND status = 'processing'
                  AND processing_token = %s
                RETURNING id
                """,
                (job_id, processing_token),
            ).fetchone()
            if not fenced:
                raise LostJobClaimError("job processing claim was lost before completion")
            connection.execute(
                """
                INSERT INTO job_results (id, job_id, result)
                VALUES (%s, %s, %s)
                ON CONFLICT (job_id) DO UPDATE SET result = EXCLUDED.result
                """,
                (uuid4(), job_id, Jsonb(result)),
            )
            connection.execute(
                """
                INSERT INTO object_metadata (id, job_id, object_key, object_type, owner_ref)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (job_id, object_key) DO NOTHING
                """,
                (uuid4(), job_id, object_key, object_type, "job"),
            )
            connection.execute(
                """
                INSERT INTO audit_events (id, entity_type, entity_id, action, details)
                VALUES (%s, 'job', %s, 'completed', %s)
                """,
                (uuid4(), job_id, Jsonb(result)),
            )

    def fail_job(self, job_id: UUID, processing_token: UUID, error: str) -> bool:
        with self.database.transaction() as connection:
            result = connection.execute(
                """
                UPDATE jobs
                SET status = 'failed',
                    last_error = %s,
                    processing_token = NULL,
                    processing_started_at = NULL,
                    updated_at = NOW()
                WHERE id = %s
                  AND status = 'processing'
                  AND processing_token = %s
                """,
                (error[:1000], job_id, processing_token),
            )
            return result.rowcount == 1
