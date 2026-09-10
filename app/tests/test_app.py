import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

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

