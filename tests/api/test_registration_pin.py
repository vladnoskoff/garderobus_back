import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="module")
def test_client(tmp_path_factory):
    db_dir = tmp_path_factory.mktemp("db")
    db_path = db_dir / "test_pin.db"

    os.environ["DATABASE_URL"] = f"sqlite:///{db_path}"
    os.environ["DATABASE_USE_REPLICAS"] = "false"
    os.environ["CACHE_ENABLED"] = "false"
    os.environ["TRACING_ENABLED"] = "false"
    os.environ["OPENAI_API_KEY"] = "sk-test-key"
    os.environ.setdefault("OPENWEATHER_API_KEY", "test-weather-key")

    api_path = Path(__file__).resolve().parents[2] / "api"
    if str(api_path) not in sys.path:
        sys.path.append(str(api_path))

    import main  # pylint: disable=import-error

    client = TestClient(main.app)
    yield client
    client.close()
    main.shutdown_event()


def test_register_accepts_camel_case_pin(test_client):
    response = test_client.post(
        "/users/register",
        json={
            "name": "Alias User",
            "email": "alias@example.com",
            "password": "password",
            "gender": "male",
            "pinCode": "9876",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["has_pin"] is True

    verify = test_client.post(
        f"/users/{data['id']}/verify_pin",
        json={"pin_code": "9876"},
    )
    assert verify.status_code == 200
    assert verify.json() == {"valid": True}
