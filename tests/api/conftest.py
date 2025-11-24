import os
import sys
from pathlib import Path

import asyncio
import pytest
import httpx


@pytest.fixture(scope="module")
def api_client(tmp_path_factory):
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

    transport = httpx.ASGITransport(app=main.app)
    async_client = httpx.AsyncClient(
        transport=transport, base_url="http://testserver", follow_redirects=True
    )

    class SyncASGIClient:
        def request(self, method: str, url: str, **kwargs):
            return asyncio.run(async_client.request(method, url, **kwargs))

        def get(self, url: str, **kwargs):
            return self.request("GET", url, **kwargs)

        def post(self, url: str, **kwargs):
            return self.request("POST", url, **kwargs)

    client = SyncASGIClient()
    yield client

    asyncio.run(async_client.aclose())
    main.shutdown_event()
