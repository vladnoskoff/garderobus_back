#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Запустите скрипт от имени root (используйте sudo)." >&2
    exit 1
fi

APT_UPDATED=false

if ! command -v git >/dev/null 2>&1; then
    echo "[INFO] Устанавливаем git для клонирования репозитория..."
    apt-get update -y
    APT_UPDATED=true
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git ca-certificates
fi

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
DEFAULT_PROJECT_ROOT_GUESS=""

if [[ -n "${SCRIPT_SOURCE}" && "${SCRIPT_SOURCE}" != "-" ]]; then
    SCRIPT_PARENT="$(dirname "${SCRIPT_SOURCE}")"
    if [[ -d "${SCRIPT_PARENT}" ]]; then
        DEFAULT_PROJECT_ROOT_GUESS="$(cd "${SCRIPT_PARENT}/.." && pwd)"
    fi
fi

PROJECT_ROOT="${PROJECT_ROOT:-${DEFAULT_PROJECT_ROOT_GUESS:-/opt/garderobus_back}}"
PROJECT_ROOT="$(mkdir -p "${PROJECT_ROOT}" && cd "${PROJECT_ROOT}" && pwd)"
API_DIR="${PROJECT_ROOT}/api"

CLONED_REPO=false

if [[ ! -d "${API_DIR}" ]]; then
    if [[ -z "${REPO_URL:-}" ]]; then
        cat >&2 <<'EOF'
[ERROR] Репозиторий проекта не найден. Укажите REPO_URL с HTTPS-адресом GitHub,
например:

    REPO_URL=https://github.com/your-org/garderobus_back.git \
        bash install_for_server/install.sh

или предварительно клонируйте проект и запустите скрипт из его каталога.
EOF
        exit 1
    fi

    if [[ -n "$(ls -A "${PROJECT_ROOT}" 2>/dev/null)" ]]; then
        echo "[ERROR] Каталог ${PROJECT_ROOT} не пуст. Укажите PROJECT_ROOT для чистого каталога." >&2
        exit 1
    fi

    echo "[INFO] Клонируем репозиторий ${REPO_URL} в ${PROJECT_ROOT}..."
    git clone --depth 1 "${REPO_URL}" "${PROJECT_ROOT}"
    CLONED_REPO=true
fi

if [[ ! -d "${API_DIR}" ]]; then
    echo "[ERROR] Не найден каталог api внутри проекта (PROJECT_ROOT=${PROJECT_ROOT})." >&2
    exit 1
fi

DB_NAME="${DB_NAME:-smart_closet}"
DB_USER="${DB_USER:-garderobus}"
DB_PASSWORD="${DB_PASSWORD:-garderobus_pass}"

APP_PORT="${APP_PORT:-8000}"
VENV_DIR="${VENV_DIR:-${PROJECT_ROOT}/.venv}"
ENV_FILE="${ENV_FILE:-${PROJECT_ROOT}/.env}"
LOG_DIR="${LOG_DIR:-/var/log/garderobus}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
CELERY_CONCURRENCY="${CELERY_CONCURRENCY:-2}"

PROJECT_OWNER="$(stat -c '%U' "${PROJECT_ROOT}")"
PROJECT_GROUP="$(stat -c '%G' "${PROJECT_ROOT}")"

if [[ -z "${SERVICE_USER:-}" ]]; then
    if [[ "${PROJECT_OWNER}" == "root" && "${CLONED_REPO}" == "true" ]]; then
        SERVICE_USER="garderobus"
    else
        SERVICE_USER="${PROJECT_OWNER}"
    fi
else
    SERVICE_USER="${SERVICE_USER}"
fi

if [[ -z "${SERVICE_GROUP:-}" ]]; then
    if [[ "${SERVICE_USER}" == "${PROJECT_OWNER}" ]]; then
        SERVICE_GROUP="${PROJECT_GROUP}"
    else
        SERVICE_GROUP="${SERVICE_USER}"
    fi
else
    SERVICE_GROUP="${SERVICE_GROUP}"
fi

if ! getent group "${SERVICE_GROUP}" >/dev/null 2>&1; then
    echo "[INFO] Создаём системную группу ${SERVICE_GROUP}..."
    groupadd --system "${SERVICE_GROUP}"
fi

if ! id -u "${SERVICE_USER}" >/dev/null 2>&1; then
    echo "[INFO] Создаём системного пользователя ${SERVICE_USER}..."
    useradd --system --create-home --shell /usr/sbin/nologin --gid "${SERVICE_GROUP}" "${SERVICE_USER}"
fi

if ! id -nG "${SERVICE_USER}" | tr ' ' '\n' | grep -qx "${SERVICE_GROUP}"; then
    usermod -a -G "${SERVICE_GROUP}" "${SERVICE_USER}"
fi

TAKE_OWNERSHIP_FLAG="${TAKE_OWNERSHIP:-false}"
if [[ "${CLONED_REPO}" == "true" || "${TAKE_OWNERSHIP_FLAG,,}" =~ ^(true|1|yes)$ ]]; then
    echo "[INFO] Передаём владение каталогом проекта пользователю ${SERVICE_USER}:${SERVICE_GROUP}..."
    chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${PROJECT_ROOT}"
fi

if [[ "${APT_UPDATED}" == "false" ]]; then
    echo "[INFO] Обновляем индекс пакетов..."
    apt-get update -y
else
    echo "[INFO] Индекс пакетов уже обновлён."
fi

echo "[INFO] Устанавливаем системные зависимости..."
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git curl ca-certificates build-essential \
    python3 python3-venv python3-pip python3-dev \
    libpq-dev postgresql postgresql-contrib \
    redis-server nginx

systemctl enable postgresql
systemctl enable redis-server
systemctl enable nginx

systemctl start postgresql
systemctl start redis-server
systemctl start nginx

sql_escape_literal() {
    printf "%s" "${1-}" | sed "s/'/''/g"
}

DB_USER_ESCAPED="$(sql_escape_literal "${DB_USER}")"
DB_PASSWORD_ESCAPED="$(sql_escape_literal "${DB_PASSWORD}")"
DB_NAME_ESCAPED="$(sql_escape_literal "${DB_NAME}")"

echo "[INFO] Создаём базу данных PostgreSQL (если отсутствует)..."
sudo -Hiu postgres psql <<EOSQL
\set ON_ERROR_STOP on
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USER_ESCAPED}') THEN
        EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', '${DB_USER_ESCAPED}', '${DB_PASSWORD_ESCAPED}');
    ELSE
        EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', '${DB_USER_ESCAPED}', '${DB_PASSWORD_ESCAPED}');
    END IF;
END
$$;
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME_ESCAPED}') THEN
        EXECUTE format('CREATE DATABASE %I OWNER %I', '${DB_NAME_ESCAPED}', '${DB_USER_ESCAPED}');
    ELSE
        EXECUTE format('ALTER DATABASE %I OWNER TO %I', '${DB_NAME_ESCAPED}', '${DB_USER_ESCAPED}');
    END IF;
END
$$;
DO $$
BEGIN
    EXECUTE format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', '${DB_NAME_ESCAPED}', '${DB_USER_ESCAPED}');
END
$$;
EOSQL

echo "[INFO] Готовим директории логов и медиа..."
mkdir -p "${LOG_DIR}"
chown "${SERVICE_USER}:${SERVICE_GROUP}" "${LOG_DIR}"
chmod 750 "${LOG_DIR}"

mkdir -p "${API_DIR}/clothes_images" "${API_DIR}/mannequins"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${API_DIR}/clothes_images" "${API_DIR}/mannequins"

if [[ ! -f "${LOG_DIR}/api.log" ]]; then
    touch "${LOG_DIR}/api.log"
    chown "${SERVICE_USER}:${SERVICE_GROUP}" "${LOG_DIR}/api.log"
    chmod 640 "${LOG_DIR}/api.log"
fi

echo "[INFO] Готовим Python virtualenv..."
if [[ "${SERVICE_USER}" == "root" ]]; then
    if [[ ! -d "${VENV_DIR}" ]]; then
        python3 -m venv "${VENV_DIR}"
    fi
    source "${VENV_DIR}/bin/activate"
    pip install --upgrade pip setuptools wheel
    pip install -r "${API_DIR}/requirements.txt"
    deactivate
else
    if [[ ! -d "${VENV_DIR}" ]]; then
        runuser -u "${SERVICE_USER}" -- python3 -m venv "${VENV_DIR}"
    fi
    runuser -u "${SERVICE_USER}" -- bash -lc "source '${VENV_DIR}/bin/activate' && pip install --upgrade pip setuptools wheel"
    runuser -u "${SERVICE_USER}" -- bash -lc "source '${VENV_DIR}/bin/activate' && pip install -r '${API_DIR}/requirements.txt'"
fi

echo "[INFO] Создаём .env (если отсутствует)..."
if [[ ! -f "${ENV_FILE}" ]]; then
    cat <<EOF_ENV > "${ENV_FILE}"
# Garderobus API server configuration
APP_NAME=Smart Closet
APP_PORT=${APP_PORT}
DEBUG=false

DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}
DATABASE_POOL_SIZE=10
DATABASE_MAX_OVERFLOW=20
DATABASE_POOL_TIMEOUT=30
DATABASE_POOL_RECYCLE=1800
DATABASE_POOL_PRE_PING=true

CLOTHES_IMAGE_DIR=clothes_images
MANNEQUIN_IMAGE_DIR=mannequins
CLOTHES_IMAGE_URL_PREFIX=http://your-domain.example.com/clothes_images
MANNEQUIN_IMAGE_URL_PREFIX=http://your-domain.example.com/mannequins

CACHE_URL=redis://127.0.0.1:6379/0
CACHE_BACKEND=redis
CACHE_ENABLED=true
CACHE_DEFAULT_TTL=300
CACHE_TTL_WEATHER=900
CACHE_SOCKET_TIMEOUT=1.5
CACHE_KEY_PREFIX=garderobus

CELERY_BROKER_URL=redis://127.0.0.1:6379/0
CELERY_RESULT_BACKEND=redis://127.0.0.1:6379/1
CELERY_DEFAULT_QUEUE=garderobus-tasks
CELERY_RESULT_EXPIRES=3600
CELERY_TASK_SOFT_TIME_LIMIT=120
CELERY_TASK_HARD_TIME_LIMIT=180
CELERY_WORKER_PREFETCH_MULTIPLIER=1

OPENAI_API_KEY=changeme-openai
OPENWEATHER_API_KEY=changeme-openweather
HUGGINGFACE_API_KEY=changeme-huggingface
SEGMIND_API_KEY=changeme-segmind
UPLOADCARE_PUBLIC_KEY=changeme-uploadcare-public
UPLOADCARE_SECRET_KEY=changeme-uploadcare-secret

SOCKS_PROXY_URL=
ENABLE_SOCKS_PROXY=false

ESP_DISPLAY_IP=http://192.168.1.100
LOG_LEVEL=INFO
LOG_FILE=${LOG_DIR}/api.log
API_RATE_LIMIT=120/minute

TRACING_ENABLED=false
TRACING_SERVICE_NAME=garderobus-api
JAEGER_AGENT_HOST=localhost
JAEGER_AGENT_PORT=6831

HTTP_CLIENT_TIMEOUT=5.0
HTTP_CLIENT_CIRCUIT_MAX_FAILURES=5
HTTP_CLIENT_CIRCUIT_RESET_TIMEOUT=60
HTTP_CLIENT_RATE_LIMIT=60
HTTP_CLIENT_RATE_PERIOD=60

TEST_PERSON_IMAGE_URL=
EOF_ENV
    chown "${SERVICE_USER}:${SERVICE_GROUP}" "${ENV_FILE}"
    chmod 640 "${ENV_FILE}"
fi

echo "[INFO] Создаём unit-файл systemd для API..."
cat <<EOF_API > "${SYSTEMD_DIR}/garderobus-api.service"
[Unit]
Description=Garderobus FastAPI service
After=network.target postgresql.service redis-server.service
Requires=postgresql.service redis-server.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${API_DIR}
Environment="PYTHONPATH=${API_DIR}"
EnvironmentFile=${ENV_FILE}
ExecStart=${VENV_DIR}/bin/uvicorn main:app --host 0.0.0.0 --port ${APP_PORT}
Restart=on-failure
RestartSec=5
StandardOutput=append:${LOG_DIR}/api.log
StandardError=append:${LOG_DIR}/api.log

[Install]
WantedBy=multi-user.target
EOF_API


echo "[INFO] Создаём unit-файл systemd для Celery воркера..."
cat <<EOF_CELERY > "${SYSTEMD_DIR}/garderobus-celery.service"
[Unit]
Description=Garderobus Celery worker
After=network.target redis-server.service postgresql.service
Requires=redis-server.service postgresql.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${API_DIR}
Environment="PYTHONPATH=${API_DIR}"
EnvironmentFile=${ENV_FILE}
ExecStart=${VENV_DIR}/bin/celery -A celery_app.celery_app worker --loglevel=INFO --concurrency=${CELERY_CONCURRENCY}
Restart=always
RestartSec=5
StandardOutput=append:${LOG_DIR}/celery.log
StandardError=append:${LOG_DIR}/celery.log

[Install]
WantedBy=multi-user.target
EOF_CELERY

if [[ ! -f "${LOG_DIR}/celery.log" ]]; then
    touch "${LOG_DIR}/celery.log"
    chown "${SERVICE_USER}:${SERVICE_GROUP}" "${LOG_DIR}/celery.log"
    chmod 640 "${LOG_DIR}/celery.log"
fi

chmod 640 "${SYSTEMD_DIR}/garderobus-api.service" "${SYSTEMD_DIR}/garderobus-celery.service"

systemctl daemon-reload

echo "[INFO] Скрипт завершён. Проверьте и отредактируйте ${ENV_FILE} перед запуском сервисов."
echo "[INFO] Для запуска используйте:"
echo "       systemctl enable garderobus-api garderobus-celery"
echo "       systemctl start garderobus-api garderobus-celery"
echo "[INFO] Статус сервисов: systemctl status garderobus-api garderobus-celery"
