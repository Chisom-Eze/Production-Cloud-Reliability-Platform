from pathlib import Path

from application.shared.config import get_settings
from application.shared.database import Database
from application.shared.logging import configure_logging

MIGRATION_LOCK_ID = 20260820
MIGRATION_DIR = Path(__file__).parent / "shared" / "migrations"


def run_migrations() -> None:
    settings = get_settings()
    configure_logging(settings.log_level, "migration")
    settings.validate_database()
    database = Database(settings.database_conninfo())
    database.open()
    try:
        with database.transaction() as connection:
            connection.execute("SELECT pg_advisory_xact_lock(%s)", (MIGRATION_LOCK_ID,))
            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS schema_migrations (
                    version TEXT PRIMARY KEY,
                    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
            applied = {
                row["version"]
                for row in connection.execute(
                    "SELECT version FROM schema_migrations"
                ).fetchall()
            }
            for migration_path in sorted(MIGRATION_DIR.glob("*.sql")):
                if migration_path.name in applied:
                    continue
                connection.execute(migration_path.read_text(encoding="utf-8"))
                connection.execute(
                    "INSERT INTO schema_migrations (version) VALUES (%s)",
                    (migration_path.name,),
                )
    finally:
        database.close()


if __name__ == "__main__":
    run_migrations()
