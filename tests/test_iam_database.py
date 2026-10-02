"""Check IAM token refresh and startup without contacting AWS or PostgreSQL."""

import importlib.util
import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

import app.database as database


def test_iam_connection_and_existing_schema(monkeypatch):
    # Supply only non-secret connection details. The fake SDK returns tokens.
    monkeypatch.setenv("DATABASE_AUTH_MODE", "iam")
    monkeypatch.setenv("DATABASE_HOST", "example.ap-south-1.rds.amazonaws.com")
    monkeypatch.setenv("DATABASE_PORT", "5432")
    monkeypatch.setenv("DATABASE_USER", "boundarypass_app")
    monkeypatch.setenv("DATABASE_NAME", "boundarypass")
    monkeypatch.setenv("AWS_REGION", "ap-south-1")

    rds = Mock()
    rds.generate_db_auth_token.side_effect = ["first-token", "second-token"]
    client = Mock(return_value=rds)
    monkeypatch.setitem(sys.modules, "boto3", SimpleNamespace(client=client))

    # Load an isolated copy so the other tests keep their SQLite module.
    spec = importlib.util.spec_from_file_location(
        "iam_database_under_test", Path(database.__file__)
    )
    iam_database = importlib.util.module_from_spec(spec)
    monkeypatch.setitem(sys.modules, spec.name, iam_database)
    spec.loader.exec_module(iam_database)

    assert iam_database.engine.url.host == "example.ap-south-1.rds.amazonaws.com"
    assert iam_database.engine.url.username == "boundarypass_app"
    client.assert_called_once_with("rds", region_name="ap-south-1")

    # Each physical connection gets a fresh login token.
    first = {}
    second = {}
    iam_database.add_iam_token(None, None, [], first)
    iam_database.add_iam_token(None, None, [], second)
    assert first["password"] == "first-token"
    assert second["password"] == "second-token"
    assert rds.generate_db_auth_token.call_count == 2

    # IAM startup reads an existing table and never creates schema objects.
    session = Mock()
    session.__enter__ = Mock(return_value=session)
    session.__exit__ = Mock(return_value=False)
    monkeypatch.setattr(iam_database, "SessionLocal", lambda: session)
    create_all = Mock(side_effect=AssertionError("IAM user must not create tables"))
    monkeypatch.setattr(iam_database.Base.metadata, "create_all", create_all)

    iam_database.initialize_database()
    session.scalar.assert_called_once()
    create_all.assert_not_called()
