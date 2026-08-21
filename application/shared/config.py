from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "production-cloud-reliability-platform"
    environment: str = "local"
    service_name: str = "api"
    log_level: str = "INFO"
    database_url: str = "postgresql://platform:platform@postgres:5432/platform"
    local_artifact_root: str = "/tmp/platform-artifacts"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()

