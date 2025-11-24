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
DEFAULT_USER_LOCATION = os.getenv(
    "DEFAULT_USER_LOCATION",
    "55.755826, 37.617299",
)
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

# Authentication / JWT
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "supersecretkey")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))
AUTH_FAILED_ATTEMPT_LIMIT = int(os.getenv("AUTH_FAILED_ATTEMPT_LIMIT", "5"))
AUTH_FAILED_ATTEMPT_WINDOW_SECONDS = int(
    os.getenv("AUTH_FAILED_ATTEMPT_WINDOW_SECONDS", str(15 * 60))
)
AUTH_LOCKOUT_SECONDS = int(os.getenv("AUTH_LOCKOUT_SECONDS", str(15 * 60)))
AUTH_SUSPICIOUS_IP_LIMIT = int(os.getenv("AUTH_SUSPICIOUS_IP_LIMIT", "20"))
AUTH_SUSPICIOUS_IP_WINDOW_SECONDS = int(
    os.getenv("AUTH_SUSPICIOUS_IP_WINDOW_SECONDS", str(10 * 60))
)
USER_RATE_LIMIT_MAX_REQUESTS = int(os.getenv("USER_RATE_LIMIT_MAX_REQUESTS", "600"))
USER_RATE_LIMIT_WINDOW_SECONDS = int(
    os.getenv("USER_RATE_LIMIT_WINDOW_SECONDS", str(15 * 60))
)

# Logging and rate limiting
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
LOG_FILE = os.getenv("LOG_FILE", "/var/log/garderobus/api.log")
LOG_FILE_BACKUP_COUNT = int(os.getenv("LOG_FILE_BACKUP_COUNT", "7"))
API_RATE_LIMIT = os.getenv("API_RATE_LIMIT", "120/minute")

# Distributed tracing / OpenTelemetry
TRACING_ENABLED = os.getenv("TRACING_ENABLED", "true").lower() == "true"
TRACING_SERVICE_NAME = os.getenv("TRACING_SERVICE_NAME", "garderobus-api")
JAEGER_AGENT_HOST = os.getenv("JAEGER_AGENT_HOST", "jaeger")
JAEGER_AGENT_PORT = int(os.getenv("JAEGER_AGENT_PORT", "6831"))
OTEL_EXPORTER_OTLP_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
OTEL_EXPORTER_OTLP_HEADERS = os.getenv("OTEL_EXPORTER_OTLP_HEADERS")

# Hot-path profiling
PROFILING_ENABLED = os.getenv("PROFILING_ENABLED", "false").lower() == "true"
PROFILING_ENDPOINT_PREFIXES = [
    prefix.strip()
    for prefix in os.getenv(
        "PROFILING_ENDPOINT_PREFIXES",
        "/clothes/user,/outfits/history,/weather/user",
    ).split(",")
    if prefix.strip()
]
PROFILING_OUTPUT_DIR = Path(
    os.getenv("PROFILING_OUTPUT_DIR", str(BASE_DIR / "logs" / "profiles"))
)
PROFILING_SAMPLING_INTERVAL = float(
    os.getenv("PROFILING_SAMPLING_INTERVAL", "0.001")
)
PROFILING_WRITE_FLAMEGRAPH = (
    os.getenv("PROFILING_WRITE_FLAMEGRAPH", "true").lower() == "true"
)

# HTTP client resilience
HTTP_CLIENT_TIMEOUT = float(os.getenv("HTTP_CLIENT_TIMEOUT", "5.0"))
HTTP_CLIENT_CIRCUIT_MAX_FAILURES = int(os.getenv("HTTP_CLIENT_CIRCUIT_MAX_FAILURES", "5"))
HTTP_CLIENT_CIRCUIT_RESET_TIMEOUT = int(os.getenv("HTTP_CLIENT_CIRCUIT_RESET_TIMEOUT", "60"))
HTTP_CLIENT_RATE_LIMIT = int(os.getenv("HTTP_CLIENT_RATE_LIMIT", "60"))
HTTP_CLIENT_RATE_PERIOD = float(os.getenv("HTTP_CLIENT_RATE_PERIOD", "60"))

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
CACHE_USE_LOCAL_FALLBACK = (
    os.getenv("CACHE_USE_LOCAL_FALLBACK", "true").lower() == "true"
)
CACHE_LOCAL_TTL = int(os.getenv("CACHE_LOCAL_TTL", "60"))
CACHE_MAX_CONNECTIONS = int(os.getenv("CACHE_MAX_CONNECTIONS", "50"))

# Static content caching / CDN hints
STATIC_CACHE_CONTROL = os.getenv(
    "STATIC_CACHE_CONTROL", "public, max-age=604800, immutable"
)
CDN_CACHE_CONTROL = os.getenv("CDN_CACHE_CONTROL", STATIC_CACHE_CONTROL)
STATIC_ENABLE_ETAG = os.getenv("STATIC_ENABLE_ETAG", "true").lower() == "true"

# CORS configuration
CORS_ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ALLOWED_ORIGINS",
        "http://garderobus.noksovsteam.ru,https://garderobus.noksovsteam.ru",
    ).split(",")
    if origin.strip()
]

# Celery / task queue configuration
CELERY_BROKER_URL = os.getenv(
    "CELERY_BROKER_URL", "amqp://guest:guest@localhost:5672//"
)
CELERY_RESULT_BACKEND = os.getenv("CELERY_RESULT_BACKEND", "rpc://")
CELERY_DEFAULT_QUEUE = os.getenv("CELERY_DEFAULT_QUEUE", "garderobus-tasks")
CELERY_DEAD_LETTER_QUEUE = os.getenv(
    "CELERY_DEAD_LETTER_QUEUE", "garderobus-dead-letter"
)
CELERY_RESULT_EXPIRES = int(os.getenv("CELERY_RESULT_EXPIRES", "3600"))
CELERY_IDEMPOTENCY_TTL = int(os.getenv("CELERY_IDEMPOTENCY_TTL", "7200"))
CELERY_RETRY_ALERT_THRESHOLD = int(os.getenv("CELERY_RETRY_ALERT_THRESHOLD", "2"))
CELERY_TASK_SOFT_TIME_LIMIT = int(os.getenv("CELERY_TASK_SOFT_TIME_LIMIT", "120"))
CELERY_TASK_HARD_TIME_LIMIT = int(os.getenv("CELERY_TASK_HARD_TIME_LIMIT", "180"))
CELERY_WORKER_PREFETCH_MULTIPLIER = int(
    os.getenv("CELERY_WORKER_PREFETCH_MULTIPLIER", "1")
)
CELERY_MAX_RETRIES = int(os.getenv("CELERY_MAX_RETRIES", "3"))
APP_ENV = os.getenv("APP_ENV", "production")
APP_VERSION = os.getenv("APP_VERSION", "development")

ADMIN_RESTART_COMMAND = os.getenv("ADMIN_RESTART_COMMAND", "")
ADMIN_ALLOW_RESTART = os.getenv("ADMIN_ALLOW_RESTART", "true").lower() == "true"
ADMIN_WORKER_RESTART_COMMAND = os.getenv("ADMIN_WORKER_RESTART_COMMAND", "")
ADMIN_ALLOW_WORKER_RESTART = os.getenv("ADMIN_ALLOW_WORKER_RESTART", "true").lower() == "true"
ADMIN_MAINTENANCE_ENABLE_COMMAND = os.getenv("ADMIN_MAINTENANCE_ENABLE_COMMAND", "")
ADMIN_MAINTENANCE_DISABLE_COMMAND = os.getenv("ADMIN_MAINTENANCE_DISABLE_COMMAND", "")
ADMIN_MAINTENANCE_INITIAL_STATE = os.getenv("ADMIN_MAINTENANCE_INITIAL_STATE", "false").lower() == "true"
ADMIN_TEST_WEBHOOK_URL = os.getenv("ADMIN_TEST_WEBHOOK_URL", "")

ADMIN_MANAGED_CODE_ROOT = Path(
    os.getenv("ADMIN_MANAGED_CODE_ROOT", str(BASE_DIR / "managed_code"))
)
ADMIN_MANAGED_CODE_ROOT.mkdir(parents=True, exist_ok=True)

ADMIN_MANAGED_CODE_MAX_SIZE = int(
    os.getenv("ADMIN_MANAGED_CODE_MAX_SIZE", str(128 * 1024))
)
ADMIN_MANAGED_CODE_EXTENSIONS = tuple(
    ext.strip().lower()
    for ext in os.getenv(
        "ADMIN_MANAGED_CODE_EXTENSIONS",
        ".py,.txt,.json,.yaml,.yml,.sh",
    ).split(",")
    if ext.strip()
)
