import os
from pathlib import Path
from dotenv import load_dotenv

# Загрузка переменных окружения из .env файла
load_dotenv()

# Базовые пути
BASE_DIR = Path(__file__).resolve().parent
CLOTHES_IMAGE_DIR = BASE_DIR / os.getenv("CLOTHES_IMAGE_DIR", "clothes_images")
MANNEQUIN_IMAGE_DIR = BASE_DIR / os.getenv("MANNEQUIN_IMAGE_DIR", "mannequins")
DEFAULT_API_DOMAIN = "http://aapanel-api.noksovsteam.ru"
CLOTHES_IMAGE_URL_PREFIX = os.getenv(
    "CLOTHES_IMAGE_URL_PREFIX", f"{DEFAULT_API_DOMAIN}/clothes_images"
)
MANNEQUIN_IMAGE_URL_PREFIX = os.getenv(
    "MANNEQUIN_IMAGE_URL_PREFIX", f"{DEFAULT_API_DOMAIN}/mannequins"
)
TEST_PERSON_IMAGE_URL = os.getenv(
    "TEST_PERSON_IMAGE_URL",
    "http://aapanel-api.noksovsteam.ru/chkaf/clothes_images/static/test_mannequin.png",
)

# Создание директорий, если они отсутствуют
for directory in (CLOTHES_IMAGE_DIR, MANNEQUIN_IMAGE_DIR):
    directory.mkdir(parents=True, exist_ok=True)

# Настройки базы данных
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:Inoskoff11@192.168.1.148:5432/smart-closet",
)

DATABASE_READ_REPLICAS = [
    replica.strip()
    for replica in os.getenv("DATABASE_READ_REPLICAS", "").split(",")
    if replica.strip()
]

DATABASE_USE_REPLICAS = (
    os.getenv("DATABASE_USE_REPLICAS", "true").lower() == "true"
    and bool(DATABASE_READ_REPLICAS)
)

DATABASE_POOL_SIZE = int(os.getenv("DATABASE_POOL_SIZE", "10"))
DATABASE_MAX_OVERFLOW = int(os.getenv("DATABASE_MAX_OVERFLOW", "20"))
DATABASE_POOL_TIMEOUT = int(os.getenv("DATABASE_POOL_TIMEOUT", "30"))
DATABASE_POOL_RECYCLE = int(os.getenv("DATABASE_POOL_RECYCLE", "1800"))
DATABASE_POOL_PRE_PING = os.getenv("DATABASE_POOL_PRE_PING", "true").lower() == "true"

# API-ключи
OPENAI_API_KEY = os.getenv(
    "OPENAI_API_KEY",
    "sk-proj-meOKTsNkP_Gp17p9tWbHCNBT8Y2qidUHCQFkrZ6bRB_R0yUB3qi0OIvILCAs-"
    "SobJ5yqq8nr2lT3BlbkFJ4j5ALz62zsZLzf0m2q97QoMbSt_RZWUpBtCG7jh7f4yFfQSpxWgsuX42dizTtDpiiymu0ID0kA",
)
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY", "b12505dfa3865989452161d336d8ee5c")
HUGGINGFACE_API_KEY = os.getenv("HUGGINGFACE_API_KEY", "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")
SEGMIND_API_KEY = os.getenv("SEGMIND_API_KEY", "SG_37d704a36997b82a")
UPLOADCARE_PUBLIC_KEY = os.getenv("UPLOADCARE_PUBLIC_KEY", "9bbcfab1a72a8d1311ba")
UPLOADCARE_SECRET_KEY = os.getenv("UPLOADCARE_SECRET_KEY", "0ac770a85532060f0ed9")

# Прокси-настройки
SOCKS_PROXY_URL = os.getenv(
    "SOCKS_PROXY",
    os.getenv("SOCKS_PROXY_URL", "socks5://127.0.0.1:10808"),
)
ENABLE_SOCKS_PROXY = os.getenv("ENABLE_SOCKS_PROXY", "true").lower() == "true"

# Другие настройки
APP_NAME = os.getenv("APP_NAME", "Smart Closet")
ESP_DISPLAY_IP = os.getenv("ESP_DISPLAY_IP", "http://192.168.1.100")
DEBUG = os.getenv("DEBUG", "false").lower() == "true"

# Cache configuration
CACHE_URL = os.getenv("CACHE_URL", "redis://localhost:6379/0")
CACHE_BACKEND = os.getenv("CACHE_BACKEND", "redis")
CACHE_ENABLED = os.getenv("CACHE_ENABLED", "true").lower() == "true"
CACHE_DEFAULT_TTL = int(os.getenv("CACHE_DEFAULT_TTL", "300"))
CACHE_TTL_CLOTHES = int(
    os.getenv("CACHE_TTL_CLOTHES", str(CACHE_DEFAULT_TTL))
)
CACHE_TTL_LOCATIONS = int(
    os.getenv("CACHE_TTL_LOCATIONS", str(CACHE_DEFAULT_TTL))
)
CACHE_TTL_OUTFITS = int(
    os.getenv("CACHE_TTL_OUTFITS", str(CACHE_DEFAULT_TTL))
)
CACHE_TTL_WEATHER = int(os.getenv("CACHE_TTL_WEATHER", "900"))
CACHE_SOCKET_TIMEOUT = float(os.getenv("CACHE_SOCKET_TIMEOUT", "1.5"))
CACHE_KEY_PREFIX = os.getenv("CACHE_KEY_PREFIX", "garderobus")
CACHE_INVALIDATION_BATCH_SIZE = int(
    os.getenv("CACHE_INVALIDATION_BATCH_SIZE", "50")
)

# Static content caching / CDN hints
STATIC_CACHE_CONTROL = os.getenv(
    "STATIC_CACHE_CONTROL", "public, max-age=604800, immutable"
)
CDN_CACHE_CONTROL = os.getenv("CDN_CACHE_CONTROL", STATIC_CACHE_CONTROL)
STATIC_ENABLE_ETAG = os.getenv("STATIC_ENABLE_ETAG", "true").lower() == "true"
