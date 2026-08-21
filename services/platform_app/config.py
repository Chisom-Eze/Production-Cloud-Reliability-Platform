from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "cloud-reliability-platform"
    app_env: str = "local"
    log_level: str = "INFO"
    database_url: str = "postgresql://platform:platform@localhost:5432/platform"
    aws_region: str = "us-east-1"
    aws_endpoint_url: str | None = "http://localhost:4566"
    sqs_queue_name: str = "platform-jobs-local"
    sqs_queue_url: str | None = None

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
