import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import app as app_module

from app import app


def test_root():
    client = app.test_client()
    response = client.get("/")
    assert response.status_code == 200
    assert response.get_json()["status"] == "ok"


def test_liveness():
    client = app.test_client()
    response = client.get("/health/live")
    assert response.status_code == 200
    assert response.get_json()["status"] == "alive"

def test_version():
    client = app.test_client()
    response = client.get("/version")
    assert response.status_code == 200
    assert response.get_json()["version"] == "v1"



def test_readiness_success(monkeypatch):
    class Cursor:
        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

        def execute(self, query):
            assert query == "SELECT 1"

        def fetchone(self):
            return (1,)

    class Connection:
        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

        def cursor(self):
            return Cursor()

    monkeypatch.setattr(
        app_module,
        "database_connection",
        lambda: Connection(),
    )

    client = app.test_client()
    response = client.get("/health/ready")

    assert response.status_code == 200
    assert response.get_json()["status"] == "ready"


def test_readiness_failure(monkeypatch):
    def failed_connection():
        raise RuntimeError("database unavailable")

    monkeypatch.setattr(
        app_module,
        "database_connection",
        failed_connection,
    )

    client = app.test_client()
    response = client.get("/health/ready")

    assert response.status_code == 503
    assert response.get_json()["status"] == "not ready"
