# Mock-данные для локальной разработки

Этот каталог содержит минимальный набор JSON-файлов, которые помогают быстро наполнить API тестовыми данными:

- `users.json` — тело запроса для регистрации пользователя.
- `locations.json` — список локаций гардероба, которые можно создать после авторизации.
- `clothes.json` — набор вещей с привязкой к локациям (по умолчанию `location_id` = 1 и 2).
- `weather.json` — пример погодной записи, чтобы собирать аутфиты.
- `outfits.json` — готовый аутфит, ссылается на созданные вещи и погоду.

## Как пользоваться
1. Запустите API (локально или в Docker) и создайте пользователя:
   ```bash
   curl -X POST http://localhost:8000/users/register \\
     -H 'Content-Type: application/json' \\
     -d @api/docs/fixtures/users.json
   ```
2. Получите токен:
   ```bash
   curl -X POST http://localhost:8000/users/login \\
     -H 'Content-Type: application/json' \\
     -d '{"email":"demo@example.com","password":"Secret123"}'
   ```
   Сохраните `access_token` из ответа в переменную окружения `TOKEN`.
3. Создайте локации (требуется токен):
   ```bash
   while IFS= read -r body; do
     curl -X POST http://localhost:8000/locations/ \\
       -H "Authorization: Bearer $TOKEN" \\
       -H 'Content-Type: application/json' \\
       -d "$body";
   done < <(jq -c '.[]' api/docs/fixtures/locations.json)
   ```
   Если ID локаций отличаются от `1` и `2`, скорректируйте `location_id` в `clothes.json`.
4. Добавьте погоду и аутфит:
   ```bash
   curl -X POST http://localhost:8000/weather \\
     -H "Authorization: Bearer $TOKEN" \\
     -H 'Content-Type: application/json' \\
     -d @api/docs/fixtures/weather.json

   curl -X POST http://localhost:8000/outfits \\
     -H "Authorization: Bearer $TOKEN" \\
     -H 'Content-Type: application/json' \\
     -d @api/docs/fixtures/outfits.json
   ```
5. Нагрузите гардероб вещами:
   ```bash
   while IFS= read -r body; do
     curl -X POST http://localhost:8000/clothes/ \\
       -H "Authorization: Bearer $TOKEN" \\
       -H 'Content-Type: application/json' \\
       -d "$body";
   done < <(jq -c '.[]' api/docs/fixtures/clothes.json)
   ```

При необходимости можно клонировать файлы и создавать собственные вариации, сохраняя структуру полей.
