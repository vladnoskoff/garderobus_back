# Ручная установка Smart Closet API (каталог `api_microservice`)

Этот документ описывает пошаговую установку серверной части Garderobus (FastAPI) на **чистую Ubuntu Server 22.04+** без использования автоматических скриптов. Все команды можно копировать и выполнять последовательно. Инструкции ориентированы на установку API, исходный код которого находится в каталоге `api_microservice` репозитория.

## 1. Подготовка системы

Все команды ниже выполняются от имени пользователя с правами `sudo`.

```bash
sudo apt update
sudo apt upgrade -y
```

Создаём системного пользователя, которому будут принадлежать файлы и процессы приложения (можно выбрать другое имя):

```bash
sudo adduser --system --group --home /opt/garderobus garderobus
```

## 2. Установка системных зависимостей

Устанавливаем необходимые пакеты: Python, инструменты сборки, PostgreSQL, Redis и Nginx.

```bash
sudo apt install -y \
    git curl build-essential \
    python3 python3-venv python3-pip python3-dev \
    libpq-dev postgresql postgresql-contrib \
    redis-server nginx
```

Включаем автозапуск Redis и Nginx:

```bash
sudo systemctl enable redis-server
sudo systemctl enable nginx
sudo systemctl start redis-server nginx
```

## 3. Настройка PostgreSQL

Входим в оболочку `psql` от имени пользователя `postgres` и создаём базу/пользователя для API.

```bash
sudo -u postgres psql
```

Внутри `psql` выполните команды (подставьте свои значения пароля):

```sql
CREATE USER garderobus WITH PASSWORD 'strong_password';
CREATE DATABASE smart_closet OWNER garderobus;
GRANT ALL PRIVILEGES ON DATABASE smart_closet TO garderobus;
\q
```

## 4. Получение исходников

Клонируем репозиторий в домашний каталог созданного пользователя. Если `git clone` выполняется от root, передадим права пользователю `garderobus`.

```bash
sudo mkdir -p /opt/garderobus_back
sudo chown garderobus:garderobus /opt/garderobus_back
sudo -u garderobus git clone https://github.com/vladnoskoff/garderobus_back.git /opt/garderobus_back
```

Проверяем структуру и переходим в каталог `api_microservice`:

```bash
cd /opt/garderobus_back/api_microservice
```

## 5. Создание виртуального окружения и установка зависимостей

```bash
python3 -m venv /opt/garderobus_back/.venv
source /opt/garderobus_back/.venv/bin/activate
pip install --upgrade pip
pip install -r gateway/requirements.txt \
            -r auth_service/requirements.txt \
            -r wardrobe_service/requirements.txt \
            -r weather_service/requirements.txt \
            -r ai_service/requirements.txt
```

> При выполнении этих команд убедитесь, что активированное окружение отображается в приглашении (`(.venv)`).

Большинству проектов достаточно **одного** виртуального окружения, потому что все микросервисы используют одинаковые
зависимости (FastAPI, SQLAlchemy, Celery и т.д.). Это упрощает обновление пакетов и развёртывание, а также позволяет
перезапускать каждый сервис отдельно — systemd-сервисы (см. раздел 9) ссылаются на один и тот же интерпретатор, но
каждый из них управляет только своим процессом. Если хотите полностью изолировать зависимости, создайте отдельные окружения
по аналогии (например, `/opt/garderobus_back/.venv_gateway`, `.venv_auth` и т.д.) и пропишите соответствующие пути в unit-файлах.

## 6. Конфигурация окружения

В монолите (`api/settings.py`) использовалось много переменных окружения, и при переходе на микросервисы их важно
сохранить. Ниже приведены полностью заполненные `.env`-файлы для каждого сервиса — их можно скопировать как есть и при
необходимости заменить пароли/ключи на свои значения. Путь `/var/log/garderobus` будет использован для логов, поэтому
создадим его сразу же:

```bash
sudo mkdir -p /var/log/garderobus
sudo chown garderobus:garderobus /var/log/garderobus
sudo mkdir -p /etc/garderobus
sudo chown -R garderobus:garderobus /opt/garderobus_back
```

> Параметры подключения к PostgreSQL и Redis в примерах ориентированы на локальные сервисы (127.0.0.1). Если вы
> используете внешние узлы, замените адреса и порты.

### 6.1 Gateway (`/opt/garderobus_back/api_microservice/gateway/.env`)

```bash
cat <<'ENV' | sudo tee /opt/garderobus_back/api_microservice/gateway/.env
# Основные настройки приложения
APP_NAME=Garderobus API Gateway
APP_ENV=production
APP_VERSION=2024.05
DEBUG=false

# Логирование и управление
LOG_LEVEL=INFO
LOG_FILE=/var/log/garderobus/gateway.log
LOG_FILE_BACKUP_COUNT=7
API_RATE_LIMIT=120/minute
ADMIN_RESTART_COMMAND=
ADMIN_ALLOW_RESTART=true
ADMIN_MANAGED_CODE_ROOT=/opt/garderobus_back/api_microservice/gateway/managed_code
ADMIN_MANAGED_CODE_MAX_SIZE=131072
ADMIN_MANAGED_CODE_EXTENSIONS=.py,.txt,.json,.yaml,.yml,.sh

# Сервисные URL
AUTH_SERVICE_URL=http://127.0.0.1:8001
WARDROBE_SERVICE_URL=http://127.0.0.1:8002
WEATHER_SERVICE_URL=http://127.0.0.1:8003
AI_SERVICE_URL=http://127.0.0.1:8004

# Локация по умолчанию и интеграция с дисплеем
DEFAULT_USER_LOCATION=55.755826,37.617299
ESP_DISPLAY_IP=http://192.168.1.100

# Настройки сети и прокси
SOCKS_PROXY_URL=socks5://127.0.0.1:10808
ENABLE_SOCKS_PROXY=false

# Трассировка и метрики
TRACING_ENABLED=true
TRACING_SERVICE_NAME=garderobus-gateway
JAEGER_AGENT_HOST=127.0.0.1
JAEGER_AGENT_PORT=6831

# HTTP-клиент
HTTP_CLIENT_TIMEOUT=5.0
HTTP_CLIENT_CIRCUIT_MAX_FAILURES=5
HTTP_CLIENT_CIRCUIT_RESET_TIMEOUT=60
HTTP_CLIENT_RATE_LIMIT=60
HTTP_CLIENT_RATE_PERIOD=60

# Кэширование
CACHE_URL=redis://127.0.0.1:6379/0
CACHE_BACKEND=redis
CACHE_ENABLED=true
CACHE_DEFAULT_TTL=300
CACHE_TTL_CLOTHES=300
CACHE_TTL_LOCATIONS=300
CACHE_TTL_OUTFITS=300
CACHE_TTL_WEATHER=900
CACHE_SOCKET_TIMEOUT=1.5
CACHE_KEY_PREFIX=garderobus
CACHE_INVALIDATION_BATCH_SIZE=50
STATIC_CACHE_CONTROL=public, max-age=604800, immutable
CDN_CACHE_CONTROL=public, max-age=604800, immutable
STATIC_ENABLE_ETAG=true

# Очередь задач
CELERY_BROKER_URL=amqp://guest:guest@127.0.0.1:5672//
CELERY_RESULT_BACKEND=rpc://
CELERY_DEFAULT_QUEUE=garderobus-tasks
CELERY_RESULT_EXPIRES=3600
CELERY_TASK_SOFT_TIME_LIMIT=120
CELERY_TASK_HARD_TIME_LIMIT=180
CELERY_WORKER_PREFETCH_MULTIPLIER=1
ENV
sudo chown garderobus:garderobus /opt/garderobus_back/api_microservice/gateway/.env
```

### 6.2 Auth Service (`/opt/garderobus_back/api_microservice/auth_service/.env`)

```bash
cat <<'ENV' | sudo tee /opt/garderobus_back/api_microservice/auth_service/.env
# Основные настройки
APP_NAME=Auth Service
APP_ENV=production
DEBUG=false

# Подключение к PostgreSQL
DATABASE_URL=postgresql+psycopg2://garderobus:strong_password@127.0.0.1:5432/auth_service
DATABASE_READ_REPLICAS=
DATABASE_USE_REPLICAS=false
DATABASE_POOL_SIZE=10
DATABASE_MAX_OVERFLOW=20
DATABASE_POOL_TIMEOUT=30
DATABASE_POOL_RECYCLE=1800
DATABASE_POOL_PRE_PING=true

# Аутентификация
JWT_SECRET=change-me-please
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60

# Логирование
LOG_LEVEL=INFO
LOG_FILE=/var/log/garderobus/auth_service.log
LOG_FILE_BACKUP_COUNT=7

# Очередь задач (для фоновых операций, если появятся)
CELERY_BROKER_URL=amqp://guest:guest@127.0.0.1:5672//
CELERY_RESULT_BACKEND=rpc://
CELERY_DEFAULT_QUEUE=garderobus-auth
CELERY_RESULT_EXPIRES=3600
CELERY_TASK_SOFT_TIME_LIMIT=120
CELERY_TASK_HARD_TIME_LIMIT=180
CELERY_WORKER_PREFETCH_MULTIPLIER=1

# Общие параметры
TRACING_ENABLED=true
TRACING_SERVICE_NAME=garderobus-auth
JAEGER_AGENT_HOST=127.0.0.1
JAEGER_AGENT_PORT=6831
ENV
sudo chown garderobus:garderobus /opt/garderobus_back/api_microservice/auth_service/.env
```

### 6.3 Wardrobe Service (`/opt/garderobus_back/api_microservice/wardrobe_service/.env`)

```bash
cat <<'ENV' | sudo tee /opt/garderobus_back/api_microservice/wardrobe_service/.env
# Основные настройки
APP_NAME=Wardrobe Service
APP_ENV=production
DEBUG=false

# PostgreSQL
DATABASE_URL=postgresql+psycopg2://garderobus:strong_password@127.0.0.1:5432/wardrobe_service
DATABASE_READ_REPLICAS=
DATABASE_USE_REPLICAS=false
DATABASE_POOL_SIZE=10
DATABASE_MAX_OVERFLOW=20
DATABASE_POOL_TIMEOUT=30
DATABASE_POOL_RECYCLE=1800
DATABASE_POOL_PRE_PING=true

# Медиа и статика
MEDIA_BUCKET=wardrobe-media
MINIO_ENDPOINT=http://127.0.0.1:9000
MINIO_ROOT_USER=minio
MINIO_ROOT_PASSWORD=minio123
CLOTHES_IMAGE_DIR=/opt/garderobus_back/api_microservice/wardrobe_service/storage/clothes_images
MANNEQUIN_IMAGE_DIR=/opt/garderobus_back/api_microservice/wardrobe_service/storage/mannequins
CLOTHES_IMAGE_URL_PREFIX=http://cdn.garderobus.local/clothes_images
MANNEQUIN_IMAGE_URL_PREFIX=http://cdn.garderobus.local/mannequins
TEST_PERSON_IMAGE_URL=http://cdn.garderobus.local/static/test_mannequin.png
UPLOADCARE_PUBLIC_KEY=9bbcfab1a72a8d1311ba
UPLOADCARE_SECRET_KEY=0ac770a85532060f0ed9

# Интеграции
AUTH_SERVICE_URL=http://127.0.0.1:8001

# Логирование и кэширование
LOG_LEVEL=INFO
LOG_FILE=/var/log/garderobus/wardrobe_service.log
LOG_FILE_BACKUP_COUNT=7
CACHE_URL=redis://127.0.0.1:6379/0
CACHE_BACKEND=redis
CACHE_ENABLED=true
CACHE_DEFAULT_TTL=300
CACHE_TTL_CLOTHES=300
CACHE_TTL_OUTFITS=300
CACHE_SOCKET_TIMEOUT=1.5
CACHE_KEY_PREFIX=garderobus-wardrobe

# Очередь задач (для генерации контента)
CELERY_BROKER_URL=amqp://guest:guest@127.0.0.1:5672//
CELERY_RESULT_BACKEND=rpc://
CELERY_DEFAULT_QUEUE=garderobus-wardrobe
CELERY_RESULT_EXPIRES=3600
CELERY_TASK_SOFT_TIME_LIMIT=120
CELERY_TASK_HARD_TIME_LIMIT=180
CELERY_WORKER_PREFETCH_MULTIPLIER=1

# Трассировка
TRACING_ENABLED=true
TRACING_SERVICE_NAME=garderobus-wardrobe
JAEGER_AGENT_HOST=127.0.0.1
JAEGER_AGENT_PORT=6831
ENV
sudo chown garderobus:garderobus /opt/garderobus_back/api_microservice/wardrobe_service/.env
```

### 6.4 Weather Service (`/opt/garderobus_back/api_microservice/weather_service/.env`)

```bash
cat <<'ENV' | sudo tee /opt/garderobus_back/api_microservice/weather_service/.env
APP_NAME=Weather Service
APP_ENV=production
DEBUG=false

# Погодный API
OPENWEATHERMAP_API_KEY=b12505dfa3865989452161d336d8ee5c
DEFAULT_USER_LOCATION=55.755826,37.617299

# HTTP и кэш
HTTP_TIMEOUT=5
CACHE_TTL_SECONDS=900
CACHE_URL=redis://127.0.0.1:6379/0
CACHE_KEY_PREFIX=garderobus-weather
CACHE_ENABLED=true

# Логи и трассировка
LOG_LEVEL=INFO
LOG_FILE=/var/log/garderobus/weather_service.log
LOG_FILE_BACKUP_COUNT=7
TRACING_ENABLED=true
TRACING_SERVICE_NAME=garderobus-weather
JAEGER_AGENT_HOST=127.0.0.1
JAEGER_AGENT_PORT=6831
ENV
sudo chown garderobus:garderobus /opt/garderobus_back/api_microservice/weather_service/.env
```

### 6.5 AI Service (`/opt/garderobus_back/api_microservice/ai_service/.env`)

```bash
cat <<'ENV' | sudo tee /opt/garderobus_back/api_microservice/ai_service/.env
# Основные настройки
APP_NAME=AI Service
APP_ENV=production
DEBUG=false

# PostgreSQL (для хранения результатов и очередей)
DATABASE_URL=postgresql+psycopg2://garderobus:strong_password@127.0.0.1:5432/ai_service
DATABASE_READ_REPLICAS=
DATABASE_USE_REPLICAS=false
DATABASE_POOL_SIZE=10
DATABASE_MAX_OVERFLOW=20
DATABASE_POOL_TIMEOUT=30
DATABASE_POOL_RECYCLE=1800
DATABASE_POOL_PRE_PING=true

# Очереди Celery
CELERY_BROKER_URL=amqp://guest:guest@127.0.0.1:5672//
CELERY_RESULT_BACKEND=rpc://
CELERY_DEFAULT_QUEUE=garderobus-ai
CELERY_RESULT_EXPIRES=3600
CELERY_TASK_SOFT_TIME_LIMIT=600
CELERY_TASK_HARD_TIME_LIMIT=900
CELERY_WORKER_PREFETCH_MULTIPLIER=1

# Внешние AI-API
OPENAI_API_KEY=sk-your-openai-key
HUGGINGFACE_API_KEY=hf_your_huggingface_key
SEGMIND_API_KEY=SG_your_segmind_key
UPLOADCARE_PUBLIC_KEY=9bbcfab1a72a8d1311ba
UPLOADCARE_SECRET_KEY=0ac770a85532060f0ed9

# Доступ к Wardrobe для загрузки изображений
WARDROBE_SERVICE_URL=http://127.0.0.1:8002

# Прокси (если требуется доступ к внешним API через SOCKS)
SOCKS_PROXY_URL=socks5://127.0.0.1:10808
ENABLE_SOCKS_PROXY=false

# Логи и трассировка
LOG_LEVEL=INFO
LOG_FILE=/var/log/garderobus/ai_service.log
LOG_FILE_BACKUP_COUNT=7
TRACING_ENABLED=true
TRACING_SERVICE_NAME=garderobus-ai
JAEGER_AGENT_HOST=127.0.0.1
JAEGER_AGENT_PORT=6831
ENV
sudo chown garderobus:garderobus /opt/garderobus_back/api_microservice/ai_service/.env
```

> Замените `strong_password`, `sk-your-openai-key`, `hf_your_huggingface_key`, `SG_your_segmind_key` и другие чувствительные
> значения на собственные секреты. Если используете MinIO, не забудьте создать бакет `wardrobe-media` и задать реальные
> `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`.

## 7. Инициализация баз данных

Каждый микросервис использует своё подключение к PostgreSQL. После заполнения `.env` создайте необходимые структуры.
Для примера ниже показано, как инициализировать таблицы `auth_service`:

```bash
cd /opt/garderobus_back/api_microservice
source /opt/garderobus_back/.venv/bin/activate
python -c "from sqlalchemy import create_engine; from auth_service.app.config import get_settings; from auth_service.app.models import Base; engine = create_engine(get_settings().database_url); Base.metadata.create_all(bind=engine)"
```

Остальные сервисы поставляются с заглушками и должны получить собственные миграции по мере переноса логики из монолита.
Рекомендации по разбиению схем приведены в `api_microservice/README.md` (раздел «Porting Strategy»).

## 8. Локальный запуск API (uvicorn)

Для проверки работоспособности можно запустить сервер вручную:

```bash
cd /opt/garderobus_back/api_microservice/gateway
source /opt/garderobus_back/.venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

API-шлюз будет доступен по адресу `http://<ваш_IP>:8000`. Документация Swagger — `/docs`, проверка здоровья — `/healthz`.
Остальные сервисы запускаются аналогично, но на своих портах (см. раздел 13.1).

## 9. Настройка systemd-сервисов для микросервисов

Чтобы каждый компонент запускался автоматически и мог перезапускаться независимо, создадим отдельные unit-файлы. Все они
используют общее виртуальное окружение, поэтому достаточно перезапускать только нужный сервис: например,
`sudo systemctl restart garderobus@auth_service.service` не затронет `garderobus@gateway.service`.

### 9.1 Шаблон unit-файла

```bash
sudo tee /etc/systemd/system/garderobus@.service > /dev/null <<'SERVICE'
[Unit]
Description=Garderobus microservice %i
After=network.target

[Service]
User=garderobus
Group=garderobus
WorkingDirectory=/opt/garderobus_back/api_microservice/%i
EnvironmentFile=-/etc/garderobus/%i.env
EnvironmentFile=/opt/garderobus_back/api_microservice/%i/.env
Environment=PYTHONPATH=/opt/garderobus_back/api_microservice
ExecStart=/opt/garderobus_back/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
```

В unit-шаблоне используется переменная окружения `PORT`, поэтому для каждого инстанса зададим собственный файл с портом.

```bash
sudo mkdir -p /etc/garderobus
cat <<'ENV' | sudo tee /etc/garderobus/gateway.env
PORT=8000
ENV
cat <<'ENV' | sudo tee /etc/garderobus/auth_service.env
PORT=8001
ENV
cat <<'ENV' | sudo tee /etc/garderobus/wardrobe_service.env
PORT=8002
ENV
cat <<'ENV' | sudo tee /etc/garderobus/weather_service.env
PORT=8003
ENV
cat <<'ENV' | sudo tee /etc/garderobus/ai_service.env
PORT=8004
ENV
```

Теперь активируем и запускаем systemd-инстансы:

```bash
sudo systemctl daemon-reload
sudo systemctl enable garderobus@gateway.service garderobus@auth_service.service \
  garderobus@wardrobe_service.service garderobus@weather_service.service \
  garderobus@ai_service.service
sudo systemctl start garderobus@gateway.service garderobus@auth_service.service \
  garderobus@wardrobe_service.service garderobus@weather_service.service \
  garderobus@ai_service.service
```

Теперь каждый микросервис можно обслуживать отдельно: `systemctl restart garderobus@weather_service.service`
перезапустит только сервис погоды.

### 9.2 Celery worker для `ai_service`

```bash
sudo tee /etc/systemd/system/garderobus-celery.service > /dev/null <<'SERVICE'
[Unit]
Description=Garderobus Celery worker
After=network.target redis-server.service

[Service]
User=garderobus
Group=garderobus
WorkingDirectory=/opt/garderobus_back/api_microservice/ai_service
EnvironmentFile=/opt/garderobus_back/api_microservice/ai_service/.env
ExecStart=/opt/garderobus_back/.venv/bin/celery -A app.worker worker --loglevel=INFO
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
```

Активируем и запускаем воркер:

```bash
sudo systemctl enable garderobus-celery
sudo systemctl start garderobus-celery
sudo systemctl status garderobus-celery
```

## 10. Настройка Nginx (reverse proxy)

Создадим новый серверный блок, который будет проксировать запросы к Uvicorn.

```bash
sudo tee /etc/nginx/sites-available/garderobus.conf > /dev/null <<'NGINX'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX
```

Активируем конфигурацию и проверяем синтаксис:

```bash
sudo ln -s /etc/nginx/sites-available/garderobus.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 11. Проверка работоспособности

Убедитесь, что сервисы запущены и отвечают:

```bash
sudo systemctl status garderobus@gateway.service garderobus@auth_service.service \
  garderobus@wardrobe_service.service garderobus@weather_service.service \
  garderobus@ai_service.service garderobus-celery
curl -f http://127.0.0.1:8000/healthz || curl -f http://127.0.0.1:8000/docs
```

Логи сервисов и Celery находятся в `journalctl`:

```bash
sudo journalctl -u garderobus@gateway.service -u garderobus@auth_service.service \
  -u garderobus@wardrobe_service.service -u garderobus@weather_service.service \
  -u garderobus@ai_service.service -u garderobus-celery -f
```

## 12. Дополнительные шаги

- Настройте файрвол (например, `ufw allow 'Nginx Full'`).
- Замените заглушки API-ключей реальными значениями.
- Настройте резервное копирование базы данных PostgreSQL.
- Для HTTPS можно использовать Certbot (`sudo apt install certbot python3-certbot-nginx`).

Готово! Теперь Smart Closet API из каталога `api_microservice` установлено и готово к работе на вашем сервере Ubuntu.

## 13. Что внутри `api_microservice` и как запускать микросервисы

Каталог `api_microservice` повторяет структуру предлагаемой микросервисной архитектуры: в нём по отдельным подпапкам лежат сервисы
`gateway`, `auth_service`, `wardrobe_service`, `ai_service` и `weather_service`, а общие классы и утилиты вынесены в пакет
`common`. Каждый сервис представляет собой самостоятельное приложение FastAPI со своей зависимостью и точкой входа в
`app/main.py`, поэтому их можно запускать как индивидуально, так и в связке через API-шлюз.【F:api_microservice/README.md†L1-L61】

### 13.1 Базовые команды запуска

Все сервисы используют одни и те же приёмы запуска: активируйте виртуальное окружение и из каталога конкретного сервиса
выполните `uvicorn app.main:app --host 0.0.0.0 --port <порт>`. Порты можно выбрать произвольно (например, 8000–8004) или
повторить значения из `docker-compose.yml`. Пример для основных компонентов:

```bash
export PYTHONPATH=/opt/garderobus_back/api_microservice
# API-шлюз, агрегирует запросы клиентов
cd /opt/garderobus_back/api_microservice/gateway
source /opt/garderobus_back/.venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000

# Auth Service: регистрация и авторизация пользователей
cd /opt/garderobus_back/api_microservice/auth_service
source /opt/garderobus_back/.venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8001

# Wardrobe Service: одежда, образы и медиа-файлы
cd /opt/garderobus_back/api_microservice/wardrobe_service
source /opt/garderobus_back/.venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8002

# Weather Service: метео-данные
cd /opt/garderobus_back/api_microservice/weather_service
source /opt/garderobus_back/.venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8003
```

`ai_service` помимо FastAPI-приложения использует Celery-воркер для длительных заданий. Запустите API-сервис командой, как
показано ниже, а воркер — отдельным процессом, аналогично тому, как мы создавали systemd unit в разделе 9.2.【F:api_microservice/README.md†L14-L51】

```bash
cd /opt/garderobus_back/api_microservice/ai_service
source /opt/garderobus_back/.venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8004

# фоновые задачи Celery (использует брокер, указанный в переменных окружения)
celery -A app.worker worker --loglevel=INFO
```

### 13.2 Взаимодействие сервисов и инфраструктура

- **Сообщения и очередь задач.** Для обмена заданиями `ai_service` и другие компоненты используют брокер (например, Redis или
  RabbitMQ). При установке по инструкции выше Redis уже установлен, его адрес настраивается переменными окружения.
- **База данных.** Каждый сервис отвечает за свою схему в PostgreSQL. Создайте отдельные БД или схемы и пропишите подключения в
  соответствующих `.env` файлах сервисов.
- **Общий код.** Пакет `common` содержит повторно используемые клиенты и DTO. Добавьте `/opt/garderobus_back/api_microservice`
  в `PYTHONPATH`, чтобы сервисы видели общий код, или вынесите пакет в отдельный артефакт при дальнейшей разработке.
- **Оркестрация.** Для локальной разработки можно воспользоваться `docker-compose.yml`, чтобы поднять сразу все сервисы и
  инфраструктуру одной командой `docker compose up --build`. В продакшене аналогичную роль выполняет API-шлюз `gateway`,
  маршрутизирующий внешние запросы к внутренним сервисам.【F:api_microservice/README.md†L32-L85】

Такой подход позволяет включать только нужные сервисы, масштабировать их независимо и постепенно переносить функциональность
из монолита в микросервисную архитектуру.
