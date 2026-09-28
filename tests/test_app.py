import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, update
from sqlalchemy.orm import sessionmaker

import app.database as database
import app.main as main


@pytest.fixture
def client(tmp_path, monkeypatch):
    test_db = tmp_path / "boundarypass-test.db"
    test_engine = create_engine(
        f"sqlite:///{test_db.as_posix()}",
        connect_args={"check_same_thread": False},
    )
    test_sessions = sessionmaker(bind=test_engine, expire_on_commit=False)

    monkeypatch.setattr(database, "engine", test_engine)
    monkeypatch.setattr(database, "SessionLocal", test_sessions)
    monkeypatch.setattr(main, "SessionLocal", test_sessions)

    # Starting TestClient runs the app's database setup against the test DB.
    with TestClient(main.app) as test_client:
        yield test_client, test_sessions

    test_engine.dispose()


def test_homepage_health_and_seeded_matches(client):
    test_client, _ = client

    assert test_client.get("/health").json() == {"status": "ok"}

    homepage = test_client.get("/")
    assert homepage.status_code == 200
    assert "BoundaryPass" in homepage.text

    matches = test_client.get("/api/matches")
    assert matches.status_code == 200
    assert len(matches.json()) == 3
    assert matches.json()[0]["available_tickets"] == 100


def test_booking_calculates_total_and_reduces_stock(client):
    test_client, _ = client

    response = test_client.post(
        "/api/bookings",
        json={
            "match_id": 1,
            "customer_name": "Akhil Test",
            "customer_email": "akhil@example.com",
            "quantity": 2,
        },
    )

    assert response.status_code == 201
    assert response.json()["total_price"] == 2998
    assert response.json()["quantity"] == 2

    matches = test_client.get("/api/matches").json()
    assert matches[0]["available_tickets"] == 98
    assert matches[1]["available_tickets"] == 100


def test_cannot_book_more_tickets_than_available(client):
    test_client, test_sessions = client

    with test_sessions.begin() as session:
        session.execute(
            update(database.Match)
            .where(database.Match.id == 1)
            .values(available_tickets=1)
        )

    response = test_client.post(
        "/api/bookings",
        json={
            "match_id": 1,
            "customer_name": "Akhil Test",
            "customer_email": "akhil@example.com",
            "quantity": 2,
        },
    )

    assert response.status_code == 409
    assert test_client.get("/api/matches").json()[0]["available_tickets"] == 1