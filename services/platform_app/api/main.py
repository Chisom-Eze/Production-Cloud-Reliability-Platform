from contextlib import asynccontextmanager
from logging import getLogger
from uuid import UUID

from fastapi import FastAPI, HTTPException, Response, status

from platform_app.api.schemas import (
    Customer,
    CustomerCreate,
    HealthResponse,
    Job,
    JobCreate,
    ReadinessResponse,
)
from platform_app.config import Settings, get_settings
from platform_app.db.database import Database
from platform_app.db.repository import DuplicateCustomerError, NotFoundError, Repository
from platform_app.logging import RequestContextMiddleware, configure_logging, correlation_id_var
from platform_app.queue import QueueClient

logger = getLogger("platform.api")


def create_app(
    settings: Settings | None = None,
    repository: Repository | None = None,
    queue_client: QueueClient | None = None,
) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.log_level)

    database: Database | None = None
    owns_database = repository is None
    if repository is None:
        database = Database(settings.database_url)
        repository = Repository(database)
    if queue_client is None:
        queue_client = QueueClient(settings)

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        if owns_database and database is not None:
            database.open()
        yield
        if owns_database and database is not None:
            database.close()

    app = FastAPI(title=settings.app_name, lifespan=lifespan)
    app.add_middleware(RequestContextMiddleware)

    @app.get("/health", response_model=HealthResponse)
    def health() -> HealthResponse:
        return HealthResponse(
            status="ok",
            service=settings.app_name,
            environment=settings.app_env,
        )

    @app.get("/ready", response_model=ReadinessResponse)
    def ready(response: Response) -> ReadinessResponse:
        checks = {"database": False, "queue": False}
        try:
            checks["database"] = repository.check()
            checks["queue"] = queue_client.check()
        except Exception as exc:
            logger.warning("readiness check failed", extra={"error": str(exc)})

        if not all(checks.values()):
            response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
            return ReadinessResponse(status="not_ready", checks=checks)

        return ReadinessResponse(status="ready", checks=checks)

    @app.get("/customers", response_model=list[Customer])
    def list_customers() -> list[dict]:
        return repository.list_customers()

    @app.post("/customers", response_model=Customer, status_code=status.HTTP_201_CREATED)
    def create_customer(payload: CustomerCreate) -> dict:
        try:
            return repository.create_customer(payload.name, str(payload.email))
        except DuplicateCustomerError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from exc

    @app.get("/jobs", response_model=list[Job])
    def list_jobs() -> list[dict]:
        return repository.list_jobs()

    @app.post("/jobs", response_model=Job, status_code=status.HTTP_202_ACCEPTED)
    def create_job(payload: JobCreate) -> dict:
        job = repository.create_job(payload.job_type, payload.payload)
        queue_client.send_job(str(job["id"]), correlation_id_var.get())
        return job

    @app.get("/jobs/{job_id}", response_model=Job)
    def get_job(job_id: UUID) -> dict:
        try:
            return repository.get_job(job_id)
        except NotFoundError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    return app


app = create_app()

