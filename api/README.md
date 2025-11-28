# Garderobus Back (Smart Closet API)

REST API для «умного» гардероба, построенный на FastAPI. Сервис хранит гардероб пользователя, генерирует манекены с подходящими образами, подсказывает что надеть с учётом погоды, а также поддерживает несколько локаций (дом, дача и т.п.) с индивидуальными координатами.

## Возможности
- Регистрация, аутентификация и управление профилем пользователя, включая выбор пола и персональных API-ключей.
- Загрузка одежды с фотографиями, описанием, рекомендациями по уходу и привязкой к конкретному месту хранения.
- Управление локациями гардероба: создание, обновление, переключение активного места и хранение координат для погодных запросов.
- Генерация рекомендаций и манекенов на основе содержимого гардероба, пола пользователя и выбранной локации.
- Получение погодной информации с привязкой к координатам пользователя или выбранной локации.
- Аналитика по гардеробу и история ношения (если поддерживается клиентскими приложениями).

## Технологический стек
- **FastAPI** — основной веб-фреймворк.
- **SQLAlchemy** — ORM для работы с PostgreSQL.
- **Pydantic** — валидация входных/выходных данных.
- **Uvicorn** — ASGI-сервер для локального запуска.
- **OpenAI, Segmind, HuggingFace, Uploadcare, OpenWeather** — интеграции для генерации изображений и погоды (конфигурируются через переменные окружения).

## Структура проекта
```
.
├── main.py                # Точка входа FastAPI
├── database.py            # Подключение к БД и SessionLocal
├── models.py              # SQLAlchemy-модели
├── schemas.py             # Pydantic-схемы
├── routes/                # Маршруты API (users, clothes, outfits, weather, locations и др.)
├── settings.py            # Загрузка переменных окружения и путей к медиа
├── clothes_images/        # Каталог изображений одежды (создаётся автоматически)
├── mannequins/            # Каталог изображений манекенов
├── requirements.txt       # Python-зависимости
└── run.sh                 # Пример скрипта запуска
```

## Требования
- Python 3.10+
- PostgreSQL 12+
- Git

## Установка и запуск
1. **Клонировать репозиторий**
   ```bash
   git clone https://github.com/your-org/garderobus_back.git
   cd garderobus_back
   ```

2. **Создать и активировать виртуальное окружение**
   ```bash
   python -m venv .venv
   source .venv/bin/activate      # Linux/Mac
   # .venv\Scripts\activate      # Windows PowerShell
   ```

3. **Установить зависимости**
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt
   ```

4. **Создать файл `.env`** (см. раздел «Переменные окружения») и заполнить его актуальными значениями.

5. **Подготовить базу данных**
   - Создайте базу PostgreSQL и пользователя с правами на неё.
   - Выполните SQL-команды из раздела «Миграции базы данных» (если база создаётся с нуля, достаточно запустить приложение — SQLAlchemy создаст таблицы; однако добавление новых колонок требует ручного `ALTER TABLE`).

6. **Запустить приложение**
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```
   или воспользуйтесь скриптом `run.sh`:
   ```bash
   chmod +x run.sh
   ./run.sh
   ```

7. **Открыть документацию**
   После запуска API будет доступно по адресу `http://localhost:8000`. Автогенерированная документация Swagger UI — `http://localhost:8000/docs`, Redoc — `http://localhost:8000/redoc`.

## Переменные окружения
Создайте файл `.env` в корне проекта. Ниже основные параметры (значения по умолчанию из `settings.py` приведены для ориентира, их следует заменить на реальные секреты):

| Переменная | Назначение | Значение по умолчанию |
|------------|------------|-----------------------|
| `DATABASE_URL` | Строка подключения к PostgreSQL | `postgresql://postgres:password@localhost:5432/smart-closet` |
| `CLOTHES_IMAGE_DIR` | Каталог для сохранения изображений одежды | `clothes_images` |
| `MANNEQUIN_IMAGE_DIR` | Каталог для изображений манекенов | `mannequins` |
| `CLOTHES_IMAGE_URL_PREFIX` | Публичный URL-префикс для фотографий одежды | `http://<host>/clothes_images` |
| `MANNEQUIN_IMAGE_URL_PREFIX` | Публичный URL-префикс манекенов | `http://<host>/mannequins` |
| `TEST_PERSON_IMAGE_URL` | Статичное изображение-заглушка для тестов | — |
| `OPENAI_API_KEY` | Ключ OpenAI для генерации описаний/изображений | — |
| `OPENWEATHER_API_KEY` | Ключ OpenWeatherMap для прогноза погоды | — |
| `HUGGINGFACE_API_KEY` | Ключ HuggingFace для ML-инференса | — |
| `SEGMIND_API_KEY` | Ключ Segmind для генерации изображений | — |
| `UPLOADCARE_PUBLIC_KEY` / `UPLOADCARE_SECRET_KEY` | Доступ к Uploadcare CDN | — |
| `SOCKS_PROXY_URL`, `ENABLE_SOCKS_PROXY` | Настройки прокси (если требуется) | `socks5://127.0.0.1:10808`, `true` |
| `APP_NAME`, `ESP_DISPLAY_IP`, `DEBUG` | Дополнительные настройки сервиса | `Smart Closet`, `http://192.168.1.100`, `false` |

## Миграции базы данных
Проект не использует Alembic; изменения схемы вносятся вручную. Ниже перечислены основные команды, которые нужно выполнить при обновлении существующей базы:
```sql
-- Добавить пол пользователя
ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR(16);

-- Контактный телефон пользователя
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(32);
UPDATE users
SET phone = NULL
WHERE phone IS NOT NULL AND TRIM(phone) IN ('', 'null', 'undefined');

-- Таблица локаций гардероба
CREATE TABLE IF NOT EXISTS wardrobe_locations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_wardrobe_locations_user_id ON wardrobe_locations(user_id);

-- Привязка одежды к локациям и дополнительные поля
ALTER TABLE clothes ADD COLUMN IF NOT EXISTS care_instructions TEXT;
ALTER TABLE clothes ADD COLUMN IF NOT EXISTS location_id INTEGER REFERENCES wardrobe_locations(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_clothes_location_id ON clothes(location_id);
```

## Основные маршруты API
| Маршрут | Описание |
|---------|----------|
| `POST /users/register`, `POST /users/login`, `PUT /users/{id}` | Управление пользователями, обновление пола и API-ключей |
| `GET/POST/PUT/DELETE /clothes/...` | CRUD для вещей, загрузка изображений, рекомендации по уходу |
| `POST /ai/recommendation/...` | Генерация образов, манекенов и описаний с учётом пола и локации |
| `GET /outfits` | Подбор готовых комплектов, фильтрация по погоде и месту |
| `GET /weather` | Погодные данные для координат пользователя или выбранной локации |
| `GET/POST/PUT/DELETE /locations/...` | Управление локациями гардероба и их координатами |
| `GET /wardrobe-analytics/...` | Дополнительная аналитика по гардеробу |
| `POST /esp-display/...` | Интеграция с внешними устройствами отображения |

Полное описание контрактов см. в Swagger UI.

## Работа с файлами изображений
Каталоги `clothes_images/` и `mannequins/` создаются автоматически на основании переменных окружения. Для каждого пользователя формируются отдельные подпапки, а URL выдаются с учётом соответствующих префиксов. Убедитесь, что процесс имеет права на запись в эти директории и что статическая раздача файлов настроена на выбранном хостинге.

## Тестирование
Запуск unit-тестов осуществляется командой:
```bash
pytest
```

## Дополнительные советы
- Регулярно создавайте резервные копии базы данных перед применением SQL-миграций.
- Храните секретные ключи в защищённом хранилище (например, в переменных CI/CD или менеджере секретов).
- Для production-запуска рекомендуем использовать менеджер процессов (systemd, Supervisor) или контейнеризацию.

Готово! Теперь API можно интегрировать с мобильным или веб-клиентом умного гардероба.
