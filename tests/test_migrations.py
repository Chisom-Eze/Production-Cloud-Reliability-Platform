from application import migrations


class FakeResult:
    def __init__(self, rows=None):
        self.rows = rows or []

    def fetchall(self):
        return self.rows


class FakeConnection:
    def __init__(self):
        self.executed = []

    def execute(self, sql, params=None):
        self.executed.append((str(sql), params))
        if "SELECT version FROM schema_migrations" in str(sql):
            return FakeResult([])
        return FakeResult([])


class FakeTransaction:
    def __init__(self, connection):
        self.connection = connection

    def __enter__(self):
        return self.connection

    def __exit__(self, *_):
        return False


class FakeDatabase:
    connection = FakeConnection()

    def __init__(self, conninfo):
        self.conninfo = conninfo

    def open(self):
        return None

    def close(self):
        return None

    def transaction(self):
        return FakeTransaction(self.connection)


def test_migration_runner_uses_advisory_lock(monkeypatch, tmp_path):
    migration_dir = tmp_path / "migrations"
    migration_dir.mkdir()
    (migration_dir / "001_test.sql").write_text(
        "CREATE TABLE example(id int);", encoding="utf-8"
    )
    monkeypatch.setattr(migrations, "MIGRATION_DIR", migration_dir)
    monkeypatch.setattr(migrations, "Database", FakeDatabase)

    migrations.run_migrations()

    executed_sql = "\n".join(sql for sql, _ in FakeDatabase.connection.executed)
    assert "pg_advisory_xact_lock" in executed_sql
    assert "schema_migrations" in executed_sql
