# Серверный установочный скрипт

Этот каталог содержит скрипт `install.sh`, который автоматизирует развёртывание API Smart Closet на чистой Ubuntu.

Скрипт можно запускать как из уже клонированного репозитория, так и отдельно: при указании `REPO_URL` он сам скачает исходники из GitHub в заданный каталог.

## Что делает скрипт

1. Обновляет apt-индекс и устанавливает системные пакеты (Python 3, PostgreSQL, Redis, Nginx и др.).
2. Создаёт базу данных и пользователя PostgreSQL (значения можно переопределить переменными окружения `DB_NAME`, `DB_USER`, `DB_PASSWORD`).
3. Готовит каталоги для логов и медиа-файлов.
4. Создаёт и наполняет Python virtualenv, устанавливая зависимости из `api/requirements.txt`.
5. Генерирует `.env` с безопасными заглушками для секретов (если файл отсутствует).
6. Создаёт unit-файлы systemd для FastAPI-приложения и Celery-воркера.

## Использование

### Если репозиторий уже скачан

```bash
sudo bash install_for_server/install.sh
```

По умолчанию скрипт использует владельца репозитория как пользователя сервисов. При необходимости задайте переменные окружения:

```bash
sudo SERVICE_USER=deploy SERVICE_GROUP=deploy \
     DB_NAME=smart_closet DB_USER=garderobus DB_PASSWORD=strong_pass \
     APP_PORT=8000 \
     bash install_for_server/install.sh
```

### Чистая установка (когда репозиторий ещё не клонирован)

Укажите адрес GitHub-репозитория в `REPO_URL`. По умолчанию код будет скачан в `/opt/garderobus_back`, но путь можно переопределить через `PROJECT_ROOT`.

```bash
sudo REPO_URL=https://github.com/vladnoskoff/garderobus_back.git \
     PROJECT_ROOT=/opt/garderobus_back \
     bash install_for_server/install.sh
```

> Перед выполнением убедитесь, что файл `install_for_server/install.sh` доступен в текущем каталоге. Если вы на чистом сервере, скачайте его командой `curl` из раздела ниже либо предварительно клонируйте репозиторий.

Если вы запускаете скрипт напрямую из GitHub, можно использовать `curl`/`wget` и передать нужные переменные окружения:

```bash
curl -fsSL https://raw.githubusercontent.com/vladnoskoff/garderobus_back/main/install_for_server/bootstrap.sh \
  | sudo env "REPO_URL=https://github.com/vladnoskoff/garderobus_back.git" \
             "PROJECT_ROOT=/opt/garderobus_back" \
             bash
```

Скрипт `bootstrap.sh` скачивает последнюю версию `install.sh` во временный каталог и запускает её. Такой способ удобен для совсем «чистых» машин, где репозиторий ещё не доступен локально. При необходимости передайте `TAKE_OWNERSHIP=true`, чтобы принудительно изменить владельца каталога проекта на пользователя сервисов.

После выполнения обязательно откройте файл `.env` и пропишите реальные значения API-ключей и URL. Затем запустите сервисы:

```bash
sudo systemctl enable garderobus-api garderobus-celery
sudo systemctl start garderobus-api garderobus-celery
```

Проверить статус можно командой:

```bash
sudo systemctl status garderobus-api garderobus-celery
```

Скрипт создаёт логи в `/var/log/garderobus/`. Если сервисы не стартуют, изучите логи и убедитесь, что база данных доступна, а `.env` заполнен корректно.
