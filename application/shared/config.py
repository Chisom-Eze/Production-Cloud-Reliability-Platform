from functools import lru_cache
from typing import Literal

from psycopg.conninfo import make_conninfo
from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "production-cloud-reliability-platform"
    environment: str = "local"
    service_name: str = "api"
    log_level: str = "INFO"
    runtime_mode: Literal["local", "cloud"] = "local"
    database_url: str | None = "postgresql://platform:platform@postgres:5432/platform"
    db_host: str | None = None
    db_port: int = 5432
    db_name: str | None = None
    db_username: str | None = None
    db_password: SecretStr | None = None
    aws_region: str = "us-east-1"
    sqs_queue_url: str | None = None
    artifact_backend: Literal["local", "s3"] = "local"
    artifact_bucket_name: str | None = None
    artifact_prefix: str = "reports"
    local_artifact_root: str = "/app/platform-artifacts"
    job_processing_lease_seconds: int = Field(default=120, gt=0)
    outbox_claim_lease_seconds: int = Field(default=120, gt=0)
    sqs_visibility_timeout_seconds: int = Field(default=60, gt=0)
    sqs_visibility_heartbeat_seconds: int = Field(default=30, gt=0)
    metrics_enabled: bool = True
    worker_metrics_host: str = "127.0.0.1"
    worker_metrics_port: int = Field(default=9464, gt=0, le=65535)
    otel_enabled: bool = False
    otel_service_name: str | None = None
    otel_exporter_otlp_endpoint: str = "http://127.0.0.1:4317"
    otel_traces_sampler: str = "parentbased_traceidratio"
    otel_traces_sampler_arg: float = Field(default=0.1, ge=0, le=1)

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @model_validator(mode="after")
    def validate_runtime_intervals(self) -> "Settings":
        if self.sqs_visibility_heartbeat_seconds >= self.sqs_visibility_timeout_seconds:
            raise ValueError("SQS_VISIBILITY_HEARTBEAT_SECONDS must be less than SQS_VISIBILITY_TIMEOUT_SECONDS")
        if self.job_processing_lease_seconds <= self.sqs_visibility_heartbeat_seconds:
            raise ValueError("JOB_PROCESSING_LEASE_SECONDS must be greater than SQS_VISIBILITY_HEARTBEAT_SECONDS")
        return self

    @property
    def is_cloud(self) -> bool:
        return self.runtime_mode == "cloud"

    def database_conninfo(self) -> str:
        if self.database_url and (not self.is_cloud or "database_url" in self.model_fields_set):
            return self.database_url
        missing = [
            name
            for name, value in {
                "DB_HOST": self.db_host,
                "DB_NAME": self.db_name,
                "DB_USERNAME": self.db_username,
                "DB_PASSWORD": self.db_password,
            }.items()
            if value is None
        ]
        if missing:
            raise ValueError(f"missing required database configuration: {', '.join(missing)}")
        return make_conninfo(
            "",
            host=self.db_host,
            port=self.db_port,
            dbname=self.db_name,
            user=self.db_username,
            password=self.db_password.get_secret_value() if self.db_password else None,
        )

    def validate_database(self) -> None:
        self.database_conninfo()

    def validate_queue(self) -> None:
        missing = []
        if not self.aws_region:
            missing.append("AWS_REGION")
        if not self.sqs_queue_url:
            missing.append("SQS_QUEUE_URL")
        if missing:
            raise ValueError(f"missing required queue configuration: {', '.join(missing)}")

    def validate_artifact_store(self) -> None:
        missing = []
        if not self.aws_region:
            missing.append("AWS_REGION")
        if self.artifact_backend != "s3":
            missing.append("ARTIFACT_BACKEND=s3")
        if not self.artifact_bucket_name:
            missing.append("ARTIFACT_BUCKET_NAME")
        if missing:
            raise ValueError(f"missing required artifact configuration: {', '.join(missing)}")

    def validate_api_runtime(self) -> None:
        if self.is_cloud:
            self.validate_database()

    def validate_worker_runtime(self) -> None:
        if self.is_cloud:
            self.validate_database()
            self.validate_queue()
            self.validate_artifact_store()


@lru_cache
def get_settings() -> Settings:
    return Settings()
