# Работа с одеждой через API

Ниже приведены примеры вызовов для добавления и обновления вещей. Все запросы выполняются к бекенду FastAPI. Подставьте фактический базовый URL сервера (в примерах используется `http://localhost:8000`).

## Добавление одежды с автозаполнением

```bash
curl -X POST "http://localhost:8000/clothes" \
  -H "Authorization: Bearer <TOKEN>" \
  -F "user_id=1" \
  -F "auto_fill=true" \
  -F "language_code=en" \
  -F "files=@/path/to/photo.jpg"
```

Параметры формы:

- `user_id` — идентификатор владельца одежды.
- `auto_fill` — если `true`, сервис заполнит недостающие поля через ИИ.
- `language_code` — код языка (`ru` или `en`), на котором нужно вернуть описание и метаданные. Если параметр не передан, используется `ru`.
- `files` — одно или несколько изображений одежды (можно повторять параметр `files`).
- Дополнительные поля (`name`, `category`, `season`, `color`, `material`, `prompt_description`, `care_instructions`, `temperature_min`, `temperature_max`, `location_id`) заполняются вручную при необходимости. Если они не указаны, но `auto_fill=false`, сервис всё равно попытается дополнить пропущенные значения на основе анализа изображения.

В ответ вы получите JSON с созданной вещью, включая массив `image_gallery`.

## Автозаполнение без сохранения вещи

```bash
curl -X POST "http://localhost:8000/clothes/autofill" \
  -F "language_code=ru" \
  -F "file=@/path/to/photo.jpg"
```

Ответ содержит структуру `ClothesAutoFill` со всеми подсказками и метаданными. Эти данные можно отобразить в UI перед фактическим сохранением вещи.

## Обновление одежды

```bash
curl -X PATCH "http://localhost:8000/clothes/42" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "Лёгкая куртка",
        "season": "Весна",
        "temperature_min": 5,
        "temperature_max": 18
      }'
```

Поле `language_code` при обновлении не требуется — язык влияет только на генерацию новых данных ИИ. Для изменения локации передайте `location_id`, сервис автоматически перенесёт изображения между папками.

## Сохранение предпочтения языка пользователя

Чтобы язык автозаполнения совпадал с настройками конкретного пользователя, установите `language_preference` при регистрации или обновлении пользователя:

```bash
curl -X POST "http://localhost:8000/users/register" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "Иван",
        "email": "ivan@example.com",
        "password": "secret123",
        "gender": "male",
        "language_preference": "ru"
      }'
```

Для обновления языка уже созданного пользователя отправьте:

```bash
curl -X PUT "http://localhost:8000/users/1" \
  -H "Content-Type: application/json" \
  -d '{"language_preference": "en"}'
```

Колонку `language_preference` нужно добавить в таблицу `users` (см. [инструкцию](./language_setup.md)).
