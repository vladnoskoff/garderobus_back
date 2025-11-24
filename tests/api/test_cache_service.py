from pathlib import Path
import sys
from time import sleep

api_path = Path(__file__).resolve().parents[2] / "api"
if str(api_path) not in sys.path:
    sys.path.append(str(api_path))

from cache import CacheService


def test_local_cache_roundtrip_and_invalidation():
    service = CacheService(force_local_only=True)
    key = service.make_key("unit", "123")

    assert service.get_json(key, resource="unit") is None

    payload = {"value": 42}
    service.set_json(key, payload, ttl=1, resource="unit")

    assert service.get_json(key, resource="unit") == payload

    sleep(1.2)
    assert service.get_json(key, resource="unit") is None

    service.set_json(key, payload, ttl=5, resource="unit")
    assert service.get_json(key, resource="unit") == payload

    service.delete_prefix(service.make_key("unit"))
    assert service.get_json(key, resource="unit") is None
