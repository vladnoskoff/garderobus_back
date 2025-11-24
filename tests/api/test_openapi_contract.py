import json
from pathlib import Path


SNAPSHOT_PATH = Path(__file__).parent / "snapshots" / "openapi.json"


def test_openapi_matches_snapshot(api_client):
    response = api_client.get("/openapi.json")
    assert response.status_code == 200

    current = response.json()
    expected = json.loads(SNAPSHOT_PATH.read_text())
    assert current == expected


def test_legacy_routes_marked_deprecated(api_client):
    schema = api_client.get("/openapi.json").json()
    legacy_register = schema["paths"].get("/users/register")
    v1_register = schema["paths"].get("/v1/users/register")

    assert legacy_register is not None
    assert legacy_register["post"].get("deprecated") is True
    assert v1_register is not None
    assert bool(v1_register["post"].get("deprecated")) is False
