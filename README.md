# Garderobus Back (Smart Closet API)

[![CI](https://github.com/your-org/garderobus_back/actions/workflows/ci.yml/badge.svg)](https://github.com/your-org/garderobus_back/actions/workflows/ci.yml)
[![Performance regression](https://github.com/your-org/garderobus_back/actions/workflows/performance-regression.yml/badge.svg)](https://github.com/your-org/garderobus_back/actions/workflows/performance-regression.yml)

REST API для «умного» гардероба, построенный на FastAPI. Сервис хранит гардероб пользователя, генерирует манекены с подходящими образами, подсказывает что надеть с учётом погоды и поддерживает несколько локаций с индивидуальными координатами.

## Быстрый старт
### Вариант 1: Docker
1. Соберите образ API:
   ```bash
   docker build -t garderobus-api ./api
   ```
2. Поднимите PostgreSQL (локально или отдельным контейнером):
   ```bash
   docker run -d --name garderobus-db \
     -e POSTGRES_DB=smart-closet -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres \
     -p 5432:5432 postgres:14
   ```
3. Создайте файл `api/.env` (см. раздел «Переменные окружения»).
4. Запустите контейнер API:
   ```bash
   docker run --env-file ./api/.env -p 8000:8000 --network host garderobus-api
   ```
   Swagger UI будет доступен на `http://localhost:8000/docs`.

### Вариант 2: Локальное окружение (venv)
1. Клонировать репозиторий и перейти в каталог:
   ```bash
   git clone https://github.com/your-org/garderobus_back.git
   cd garderobus_back
   ```
2. Создать виртуальное окружение и установить зависимости:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install --upgrade pip
   pip install -r api/requirements.txt -r api/requirements-dev.txt
   ```
3. Создать файл `api/.env` и заполнить ключевые параметры.
4. Запустить приложение:
   ```bash
   make run
   # или uvicorn main:app --host 0.0.0.0 --port 8000 --reload из каталога api
   ```

## Переменные окружения
Основные параметры, которые нужны для запуска (располагайте в `api/.env`):

| Переменная | Назначение | Значение по умолчанию |
|------------|------------|-----------------------|
| `DATABASE_URL` | Строка подключения к БД | `postgresql://postgres:password@localhost:5432/smart-closet` |
| `DATABASE_USE_REPLICAS` | Использовать реплики для чтения | `true` + список в `DATABASE_READ_REPLICAS` |
| `CACHE_URL` | Подключение к Redis для кеша | `redis://localhost:6379/0` |
| `CLOTHES_IMAGE_DIR`, `MANNEQUIN_IMAGE_DIR` | Каталоги хранения изображений | `clothes_images`, `mannequins` |
| `CLOTHES_IMAGE_URL_PREFIX`, `MANNEQUIN_IMAGE_URL_PREFIX` | Публичные URL для выдачи медиа | `http://<host>/clothes_images`, `http://<host>/mannequins` |
| `OPENAI_API_KEY`, `OPENWEATHER_API_KEY`, `HUGGINGFACE_API_KEY`, `SEGMIND_API_KEY` | Ключи интеграций | — |
| `UPLOADCARE_PUBLIC_KEY`, `UPLOADCARE_SECRET_KEY` | Доступ к CDN Uploadcare | — |
| `JWT_SECRET_KEY`, `JWT_ALGORITHM` | Настройки JWT | `supersecretkey`, `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES`, `REFRESH_TOKEN_EXPIRE_DAYS` | TTL токенов | `15`, `7` |
| `API_RATE_LIMIT` | Лимит запросов | `120/minute` |
| `TRACING_ENABLED`, `PROFILING_ENABLED` | Трассировка и профилирование | `true`, `false` |
| `LOG_LEVEL`, `LOG_FILE` | Логирование | `INFO`, `/var/log/garderobus/api.log` |

> Совет: храните `.env` вне репозитория и используйте менеджер секретов CI/CD.

## Makefile
Типовые команды вынесены в `Makefile` (выполняются из корня репозитория):

- `make install` / `make install-dev` — установка зависимостей для приложения и разработки.
- `make run` / `make run-prod` — запуск FastAPI с/без режима hot-reload.
- `make docker-build` и `make docker-run` — сборка и запуск контейнера.
- `make lint` — статический анализ (ruff, критичные ошибки).
- `make format` / `make format-check` — автоформатирование Black и проверка.
- `make typecheck` — mypy с базовыми настройками.
- `make test` — pytest.
- `make check` — полный пакет проверок.

## Примеры запросов
Все примеры предполагают базовый URL `http://localhost:8000`.

Регистрация пользователя:
```bash
curl -X POST http://localhost:8000/users/register \
  -H 'Content-Type: application/json' \
  -d @api/docs/fixtures/users.json
```

Авторизация и получение токена:
```bash
curl -X POST http://localhost:8000/users/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@example.com","password":"Secret123"}'
```

Создание локации:
```bash
curl -X POST http://localhost:8000/locations/ \
  -H "Authorization: Bearer <access_token>" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Home wardrobe","latitude":55.7558,"longitude":37.6173}'
```

Добавление вещи (привязка к локации `1`):
```bash
curl -X POST http://localhost:8000/clothes/ \
  -H "Authorization: Bearer <access_token>" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Black jeans","category":"jeans","season":"all","color":"black","location_id":1}'
```

Получение подборок аутфитов:
```bash
curl -X GET 'http://localhost:8000/outfits/history?limit=5' \
  -H "Authorization: Bearer <access_token>"
```

## Mock-данные
В каталоге [`api/docs/fixtures`](api/docs/fixtures/README.md) лежат готовые JSON-файлы для локальной разработки (пользователь, локации, одежда, погода, аутфиты) и пошаговая инструкция по их загрузке через `curl`/`jq`.

## Документация и OpenAPI
- Swagger UI — `http://localhost:8000/docs`, Redoc — `http://localhost:8000/redoc`.
- OpenAPI схема — `http://localhost:8000/openapi.json`. Артефакт можно сгенерировать без запуска сервера: `make openapi-fixtures` (использует SQLite и подставные ключи).

## CI/CD
Workflow `ci.yml` запускает `ruff check`, `black --check`, `mypy` и `pytest` на пуши/PR. Отдельный `performance-regression.yml` выполняет k6-тесты, если заполнены секреты `PERF_BASE_URL` и `PERF_TEST_USER_ID`.

## Работа с медиа
Каталоги `clothes_images/` и `mannequins/` создаются автоматически на основании переменных окружения. Проверьте права на запись и настройте раздачу статических файлов на выбранном хостинге или CDN.
