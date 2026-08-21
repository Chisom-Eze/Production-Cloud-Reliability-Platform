from contextlib import asynccontextmanager
from logging import getLogger
from uuid import UUID

from fastapi import FastAPI, HTTPException, Response, status

from application.api.schemas import Customer, CustomerCreate, HealthResponse, Job, JobCreate, ReadyResponse
from application.api.service import ApplicationService
from application.shared.adapters import LocalJobPublisher
from application.shared.config import Settings, get_settings
from application.shared.database import Database
from application.shared.logging import RequestContextMiddleware, configure_logging
from application.shared.metrics import PrometheusMiddleware, metrics_response
from application.shared.repository import DuplicateCustomerError, NotFoundError, Repository

logger = getLogger("application.api")


def _database_unavailable(exc: Exception) -> HTTPException:
    logger.warning("database operation failed", extra={"service": "api", "error": str(exc)})
    return HTTPException(status_code=503, detail="database unavailable")


def create_app(
    settings: Settings | None = None,
    repository: Repository | None = None,
    service: ApplicationService | None = None,
) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.log_level, "api")

    database: Database | None = None
    owns_database = repository is None
    if repository is None:
        database = Database(settings.database_url)
        repository = Repository(database)
    if service is None:
        service = ApplicationService(repository, LocalJobPublisher())

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        if owns_database and database is not None:
            database.open()
        yield
        if owns_database and database is not None:
            database.close()

    app = FastAPI(title=settings.app_name, lifespan=lifespan)
    app.add_middleware(RequestContextMiddleware, service_name="api")
    app.add_middleware(PrometheusMiddleware)

    @app.get("/health", response_model=HealthResponse)
    def health() -> HealthResponse:
        return HealthResponse(
            status="ok",
            service=settings.app_name,
            environment=settings.environment,
        )

    @app.get("/ready", response_model=ReadyResponse)
    def ready(response: Response) -> ReadyResponse:
        checks = {"database": repository.check()}
        if not all(checks.values()):
            response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
            return ReadyResponse(status="not_ready", checks=checks)
        return ReadyResponse(status="ready", checks=checks)

    @app.get("/metrics", include_in_schema=False)
    def metrics():
        return metrics_response()

    @app.get("/customers", response_model=list[Customer])
    def list_customers():
        return repository.list_customers()

    @app.post("/customers", response_model=Customer, status_code=status.HTTP_201_CREATED)
    def create_customer(payload: CustomerCreate):
        try:
            return repository.create_customer(payload.name, str(payload.email))
        except DuplicateCustomerError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from exc
        except Exception as exc:
            raise _database_unavailable(exc) from exc

    @app.post("/jobs", response_model=Job, status_code=status.HTTP_202_ACCEPTED)
    def create_job(payload: JobCreate):
        try:
            return service.create_job(payload.job_type, payload.payload)
        except Exception as exc:
            raise _database_unavailable(exc) from exc

    @app.get("/jobs/{job_id}", response_model=Job)
    def get_job(job_id: UUID):
        try:
            return service.get_job(job_id)
        except NotFoundError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    return app


app = create_app()
