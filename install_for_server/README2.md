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
    redis-server nginx \
    php-fpm php-cli php-xml php-curl php-mbstring
```

Включаем автозапуск Redis и Nginx:

```bash
sudo systemctl enable redis-server
sudo systemctl enable nginx
sudo systemctl enable php8.1-fpm  # замените версию, если система устанавливает другой PHP-FPM
sudo systemctl start redis-server nginx php8.1-fpm
```

## 3. Настройка PostgreSQL

Входим в оболочку `psql` от имени пользователя `postgres` и создаём базу/пользователя для API.

```bash
sudo -u postgres psql
```

Внутри `psql` выполните команды (пароль уже совпадает с тем, что указан в `.env`):

```sql
CREATE USER garderobus WITH PASSWORD 'InoskoffStrelkov18';
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
сохранить. Репозиторий уже содержит заполненные `.env`-файлы в каждой папке сервиса, поэтому сразу после клонирования
у вас доступны конфигурации по умолчанию. Они настроены на локальные сервисы (PostgreSQL, Redis, RabbitMQ) и публичный
домен `http://garderobus.tech` для конечных пользователей. Значения `DATABASE_URL` уже указывают на
`postgresql+psycopg2://garderobus:InoskoffStrelkov18@127.0.0.1:5432/`, а в AI-сервисе прописан рабочий
`OPENAI_API_KEY=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`.
Проверьте и, при необходимости, отредактируйте остальные секреты (`change-me-please`, `hf_your_huggingface_key`,
`SG_your_segmind_key` и т.п.) прежде чем запускать сервисы в продакшене.

Путь `/var/log/garderobus` используется для логов микросервисов, а Wardrobe хранит изображения в каталоге
`/opt/garderobus_back/api_microservice/wardrobe_service/storage`. Подготовим директории заранее:

```bash
sudo mkdir -p /var/log/garderobus
sudo chown garderobus:garderobus /var/log/garderobus
sudo mkdir -p /etc/garderobus
sudo mkdir -p /opt/garderobus_back/api_microservice/wardrobe_service/storage/{clothes_images,mannequins,static}
sudo chown -R garderobus:garderobus /opt/garderobus_back
```

> Параметры подключения к PostgreSQL и Redis ориентированы на локальные сервисы (127.0.0.1). Если вы используете внешние узлы,
> замените адреса и порты. Значения `CLOTHES_IMAGE_URL_PREFIX`, `MANNEQUIN_IMAGE_URL_PREFIX` и `TEST_PERSON_IMAGE_URL`
> уже указывают на `http://garderobus.tech`, чтобы изображения, отданные Wardrobe, были доступны через ваш домен.

Чтобы изменить конфигурацию, достаточно открыть нужный файл, например:

```bash
sudo -u garderobus nano /opt/garderobus_back/api_microservice/auth_service/.env
```

> При желании замените пароль `InoskoffStrelkov18`, JWT-секрет `change-me-please`, OpenAI-ключ
> `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`,
> `hf_your_huggingface_key`, `SG_your_segmind_key` и другие чувствительные значения на собственные секреты.
> Если используете MinIO, не забудьте создать бакет `wardrobe-media`
> и задать реальные `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`.

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

## 10. Настройка Nginx и публикация сайта

Nginx обслуживает сразу три задачи: отдаёт веб-сайт из каталога `web`, проксирует запросы к API-шлюзу и публикует изображения Wardrobe. Перед настройкой убедитесь, что в `/opt/garderobus_back/web` лежит свежая версия фронтенда и владельцем каталога является пользователь `garderobus`.

Создадим единый серверный блок для домена `garderobus.tech` и его поддоменов. Если у вас активирован `www`, добавьте его в `server_name`.

```bash
sudo tee /etc/nginx/sites-available/garderobus.conf > /dev/null <<'NGINX'
server {
    listen 80;
    server_name garderobus.tech www.garderobus.tech;

    root /opt/garderobus_back/web;
    index index.php index.html;

    access_log /var/log/nginx/garderobus.access.log;
    error_log  /var/log/nginx/garderobus.error.log;

    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /media/clothes/ {
        alias /opt/garderobus_back/api_microservice/wardrobe_service/storage/clothes_images/;
        add_header Cache-Control "public, max-age=604800, immutable";
        try_files $uri $uri/ =404;
    }

    location /media/mannequins/ {
        alias /opt/garderobus_back/api_microservice/wardrobe_service/storage/mannequins/;
        add_header Cache-Control "public, max-age=604800, immutable";
        try_files $uri $uri/ =404;
    }

    location /media/static/ {
        alias /opt/garderobus_back/api_microservice/wardrobe_service/storage/static/;
        add_header Cache-Control "public, max-age=604800, immutable";
        try_files $uri $uri/ =404;
    }

    location ~ \.(php|phps)$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock; # замените на актуальный сокет (например, php8.1-fpm)
    }

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
}
NGINX
```

Если используется другая версия PHP, проверьте фактический путь до сокета командой
`ls /run/php/` и поправьте значение `fastcgi_pass`.

Активируем конфигурацию и проверяем синтаксис:

```bash
sudo ln -sfn /etc/nginx/sites-available/garderobus.conf /etc/nginx/sites-enabled/garderobus.conf
sudo nginx -t
sudo systemctl reload nginx
```

После перезагрузки Nginx сайт будет доступен по адресу `http://garderobus.tech/`, API — по `http://garderobus.tech/api/`,
а изображения Wardrobe — через `/media/clothes/…` и `/media/mannequins/…`.

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
