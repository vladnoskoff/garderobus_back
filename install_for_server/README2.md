# Ручная установка Smart Closet API (каталог `api_services`)

Этот документ описывает пошаговую установку серверной части Garderobus (FastAPI) на **чистую Ubuntu Server 22.04+** без использования автоматических скриптов. Все команды можно копировать и выполнять последовательно. Инструкции ориентированы на установку API, исходный код которого находится в каталоге `api` (служебные классы в `api/services`, далее именуемые `api_services`).

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

Проверяем структуру и переходим в каталог API:

```bash
cd /opt/garderobus_back/api
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
cat <<'ENV' | sudo tee /opt/garderobus_back/.env
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

При необходимости добавьте дополнительные переменные, перечисленные в `api/settings.py`.

Создаём каталоги для хранения изображений и выдаём права пользователю приложения:

```bash
sudo mkdir -p /opt/garderobus_back/api/clothes_images /opt/garderobus_back/api/mannequins
sudo chown -R garderobus:garderobus /opt/garderobus_back
```

## 7. Инициализация базы данных

На чистой базе достаточно один раз создать таблицы с помощью SQLAlchemy. Запустите Python внутри окружения и выполните команду:

```bash
cd /opt/garderobus_back/api
source /opt/garderobus_back/.venv/bin/activate
python -c "from models import Base; from database import engine; Base.metadata.create_all(bind=engine)"
```

Если в будущем будут добавляться новые поля, используйте SQL-скрипты из `api/README.md` (раздел «Миграции базы данных»).

## 8. Локальный запуск API (uvicorn)

Для проверки работоспособности можно запустить сервер вручную:

```bash
cd /opt/garderobus_back/api
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
WorkingDirectory=/opt/garderobus_back/api
EnvironmentFile=/opt/garderobus_back/.env
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
WorkingDirectory=/opt/garderobus_back/api
EnvironmentFile=/opt/garderobus_back/.env
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
        alias /opt/garderobus_back/api/clothes_images/;
    }

    location /mannequins/ {
        alias /opt/garderobus_back/api/mannequins/;
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
