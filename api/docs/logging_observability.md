# Структура логов и трассировок

## Стандартные поля JSON-логов

Все записи логов выводятся в формате JSON и содержат следующие ключи:

- `asctime` — время события в UTC.
- `level` — уровень (`INFO`, `WARNING`, `ERROR` и т.д.).
- `logger` — имя логгера/модуля.
- `service` — название сервиса (`APP_NAME` или `garderobus-api` по умолчанию).
- `message` — текстовое сообщение.
- `request_id` — идентификатор запроса (берётся из заголовка `X-Request-ID` или генерируется автоматически).
- `trace_id` — идентификатор трассы OpenTelemetry (возвращается в `X-Trace-Id`).
- `exc_info` — стек-трейс при наличии исключения.
- Дополнительные бизнес-поля (`user_id`, `client_ip`, `task_id`, `location_id` и т.д.) — передаются через `extra`.

## Чувствительные данные

Перед логированием полезной нагрузки поля `password`, `token`, `refresh_token`, `access_token`, `authorization` маскируются значением `***`. Для вложенных структур применяется рекурсивная маскировка.

## Примеры

```json
{
  "asctime": "2024-06-01T10:15:30Z",
  "level": "INFO",
  "logger": "api.routes.users",
  "service": "garderobus-api",
  "message": "Login succeeded",
  "request_id": "9f8a0c9e7c724c8a9fbb0b5f1efcbe55",
  "trace_id": "0f1d2c3b4a5968778899aabbccddeeff",
  "user_id": 42,
  "email": "user@example.com",
  "client_ip": "203.0.113.10"
}
```

```json
{
  "asctime": "2024-06-01T10:16:05Z",
  "level": "WARNING",
  "logger": "api.routes.ai_recommendation",
  "service": "garderobus-api",
  "message": "Failed to enqueue Celery task generate_recommendation_task; executing inline due to queue error",
  "request_id": "9f8a0c9e7c724c8a9fbb0b5f1efcbe55",
  "trace_id": "0f1d2c3b4a5968778899aabbccddeeff",
  "user_id": 42,
  "location_id": 7,
  "exc_info": "..."
}
```

## Трассировка OpenTelemetry

- Настраивается через `TRACING_ENABLED=true` и `TRACING_SERVICE_NAME`.
- По умолчанию экспорт идёт в Jaeger агент (`JAEGER_AGENT_HOST`, `JAEGER_AGENT_PORT`).
- Альтернатива: OTLP/HTTP экспорт через `OTEL_EXPORTER_OTLP_ENDPOINT` и заголовки `OTEL_EXPORTER_OTLP_HEADERS` (формат `k1:v1,k2:v2`).
- FastAPI и исходящие `requests` инструментируются автоматически; ключевые атрибуты (`user.id`, `auth.email`, `ai.task_name` и др.) добавляются в текущий спан в обработчиках.

## Корреляция

- Клиент может передать `X-Request-ID` и/или `X-Trace-Id`; оба значения возвращаются в ответе.
- При отсутствии входящих идентификаторов сервис генерирует их автоматически, чтобы связать логи и трассы для запроса.
