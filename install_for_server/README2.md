# Ручная установка Smart Closet API (каталог `api_services`)

Этот документ описывает пошаговую установку серверной части Garderobus (FastAPI) на **чистую Ubuntu Server 22.04+** без использования автоматических скриптов. Все команды можно копировать и выполнять последовательно. Инструкции ориентированы на установку API, исходный код которого находится в каталоге `api_services` репозитория.

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

Проверяем структуру и переходим в каталог `api_services`:

```bash
cd /opt/garderobus_back/api_services
```

## 5. Создание виртуального окружения и установка зависимостей

```bash
python3 -m venv /opt/garderobus_back/.venv
source /opt/garderobus_back/.venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

> При выполнении этих команд убедитесь, что активированное окружение отображается в приглашении (`(.venv)`).

## 6. Конфигурация окружения

Создаём файл `.env` в корне репозитория. Можно начать с минимального шаблона:

```bash
cat <<'ENV' | sudo tee /opt/garderobus_back/api_services/.env
DATABASE_URL=postgresql://garderobus:strong_password@127.0.0.1:5432/smart_closet
CLOTHES_IMAGE_DIR=clothes_images
MANNEQUIN_IMAGE_DIR=mannequins
CLOTHES_IMAGE_URL_PREFIX=http://127.0.0.1:8000/clothes_images
MANNEQUIN_IMAGE_URL_PREFIX=http://127.0.0.1:8000/mannequins
OPENAI_API_KEY=change_me
OPENWEATHER_API_KEY=change_me
HUGGINGFACE_API_KEY=change_me
SEGMIND_API_KEY=change_me
UPLOADCARE_PUBLIC_KEY=change_me
UPLOADCARE_SECRET_KEY=change_me
DEBUG=false
ENV
```

При необходимости добавьте дополнительные переменные, перечисленные в `api_services/settings.py`.

Создаём каталоги для хранения изображений и выдаём права пользователю приложения:

```bash
sudo mkdir -p /opt/garderobus_back/api_services/clothes_images /opt/garderobus_back/api_services/mannequins
sudo chown -R garderobus:garderobus /opt/garderobus_back
```

## 7. Инициализация базы данных

На чистой базе достаточно один раз создать таблицы с помощью SQLAlchemy. Запустите Python внутри окружения и выполните команду:

```bash
cd /opt/garderobus_back/api_services
source /opt/garderobus_back/.venv/bin/activate
python -c "from models import Base; from database import engine; Base.metadata.create_all(bind=engine)"
```

Если в будущем будут добавляться новые поля, используйте SQL-скрипты из `api_services/README.md` (раздел «Миграции базы данных»).

## 8. Локальный запуск API (uvicorn)

Для проверки работоспособности можно запустить сервер вручную:

```bash
cd /opt/garderobus_back/api_services
source /opt/garderobus_back/.venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000
```

API будет доступно по адресу `http://<ваш_IP>:8000`. Документация Swagger — `/docs`.

## 9. Настройка systemd-сервисов

Чтобы API и Celery-воркер запускались автоматически, создадим unit-файлы. Предполагается, что код и виртуальное окружение находятся в `/opt/garderobus_back`.

### 9.1 Uvicorn (FastAPI)

```bash
sudo tee /etc/systemd/system/garderobus-api.service > /dev/null <<'SERVICE'
[Unit]
Description=Garderobus FastAPI service
After=network.target

[Service]
User=garderobus
Group=garderobus
WorkingDirectory=/opt/garderobus_back/api_services
EnvironmentFile=/opt/garderobus_back/api_services/.env
ExecStart=/opt/garderobus_back/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
```

### 9.2 Celery worker (если используются фоновые задачи из `api_services`)

```bash
sudo tee /etc/systemd/system/garderobus-celery.service > /dev/null <<'SERVICE'
[Unit]
Description=Garderobus Celery worker
After=network.target redis-server.service

[Service]
User=garderobus
Group=garderobus
WorkingDirectory=/opt/garderobus_back/api_services
EnvironmentFile=/opt/garderobus_back/api_services/.env
ExecStart=/opt/garderobus_back/.venv/bin/celery -A celery_app.app worker --loglevel=INFO
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
```

Применяем изменения и запускаем сервисы:

```bash
sudo systemctl daemon-reload
sudo systemctl enable garderobus-api garderobus-celery
sudo systemctl start garderobus-api garderobus-celery
sudo systemctl status garderobus-api garderobus-celery
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

    location /clothes_images/ {
        alias /opt/garderobus_back/api_services/clothes_images/;
    }

    location /mannequins/ {
        alias /opt/garderobus_back/api_services/mannequins/;
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
sudo systemctl status garderobus-api garderobus-celery
curl -f http://127.0.0.1:8000/health || curl -f http://127.0.0.1:8000/docs
```

Логи API и Celery находятся в `journalctl`:

```bash
sudo journalctl -u garderobus-api -u garderobus-celery -f
```

## 12. Дополнительные шаги

- Настройте файрвол (например, `ufw allow 'Nginx Full'`).
- Замените заглушки API-ключей реальными значениями.
- Настройте резервное копирование базы данных PostgreSQL.
- Для HTTPS можно использовать Certbot (`sudo apt install certbot python3-certbot-nginx`).

Готово! Теперь Smart Closet API из каталога `api_services` установлено и готово к работе на вашем сервере Ubuntu.

## 13. Что внутри `api_services` и как запускать микросервисы

Каталог `api_services` повторяет структуру предлагаемой микросервисной архитектуры: в нём по отдельным подпапкам лежат сервисы
`gateway`, `auth_service`, `wardrobe_service`, `ai_service` и `weather_service`, а общие классы и утилиты вынесены в пакет
`common`. Каждый сервис представляет собой самостоятельное приложение FastAPI со своей зависимостью и точкой входа в
`app/main.py`, поэтому их можно запускать как индивидуально, так и в связке через API-шлюз.【F:api_microservice/README.md†L1-L61】

### 13.1 Базовые команды запуска

Все сервисы используют одни и те же приёмы запуска: активируйте виртуальное окружение и из каталога конкретного сервиса
выполните `uvicorn app.main:app --host 0.0.0.0 --port <порт>`. Порты можно выбрать произвольно (например, 8000–8004) или
повторить значения из `docker-compose.yml`. Пример для основных компонентов:

```bash
# API-шлюз, агрегирует запросы клиентов
cd /opt/garderobus_back/api_services/gateway
source /opt/garderobus_back/.venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000

# Auth Service: регистрация и авторизация пользователей
cd /opt/garderobus_back/api_services/auth_service
source /opt/garderobus_back/.venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8001

# Wardrobe Service: одежда, образы и медиа-файлы
cd /opt/garderobus_back/api_services/wardrobe_service
source /opt/garderobus_back/.venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8002

# Weather Service: метео-данные
cd /opt/garderobus_back/api_services/weather_service
source /opt/garderobus_back/.venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8003
```

`ai_service` помимо FastAPI-приложения использует Celery-воркер для длительных заданий. Запустите API-сервис командой, как
показано ниже, а воркер — отдельным процессом, аналогично тому, как мы создавали systemd unit в разделе 9.2.【F:api_microservice/README.md†L14-L51】

```bash
cd /opt/garderobus_back/api_services/ai_service
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
- **Общий код.** Пакет `common` содержит повторно используемые клиенты и DTO. Он подключается через `PYTHONPATH` при запуске или
  устанавливается как editable-пакет (`pip install -e /opt/garderobus_back/api_services/common`).
- **Оркестрация.** Для локальной разработки можно воспользоваться `docker-compose.yml`, чтобы поднять сразу все сервисы и
  инфраструктуру одной командой `docker compose up --build`. В продакшене аналогичную роль выполняет API-шлюз `gateway`,
  маршрутизирующий внешние запросы к внутренним сервисам.【F:api_microservice/README.md†L32-L85】

Такой подход позволяет включать только нужные сервисы, масштабировать их независимо и постепенно переносить функциональность
из монолита в микросервисную архитектуру.
