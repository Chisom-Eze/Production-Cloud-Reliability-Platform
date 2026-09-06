import pytest

from application.shared.config import Settings


def test_cloud_database_conninfo_uses_separate_secret_values():
    settings = Settings(
        runtime_mode="cloud",
        database_url=None,
        db_host="db.example.internal",
        db_port=5432,
        db_name="platform",
        db_username="platformadmin",
        db_password="p@ss word/with:specials",
    )

    conninfo = settings.database_conninfo()

    assert "host=db.example.internal" in conninfo
    assert "dbname=platform" in conninfo
    assert "user=platformadmin" in conninfo
    assert "postgresql://" not in conninfo


def test_cloud_worker_validation_fails_fast_without_queue_or_bucket():
    settings = Settings(
        runtime_mode="cloud",
        database_url=None,
        db_host="db.example.internal",
        db_name="platform",
        db_username="platformadmin",
        db_password="secret",
    )

    with pytest.raises(ValueError, match="SQS_QUEUE_URL"):
        settings.validate_worker_runtime()
