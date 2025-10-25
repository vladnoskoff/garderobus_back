# Отчёт по оптимизации производительности БД

## 1. Анализ медленных запросов

### 1.1 Источник данных
* Файл `logs/postgres/slow_query.log` (снимок от 2024-07-02)
* Включено логирование запросов длительностью > 500 мс: `log_min_duration_statement = 500`

### 1.2 Выборка медленных запросов
| Время | Длительность | Запрос |
| --- | --- | --- |
| 2024-07-02 13:43:18 | 812 мс | `SELECT * FROM clothes WHERE user_id = $1 AND location_id = $2 ORDER BY created_at DESC` |
| 2024-07-02 13:44:52 | 678 мс | `SELECT clothing_id, worn_at FROM wear_history WHERE user_id = $1 AND worn_at > $2` |
| 2024-07-02 14:05:11 | 593 мс | `SELECT id, clothing_ids FROM outfits WHERE user_id = $1 ORDER BY created_at DESC LIMIT 10` |

### 1.3 `EXPLAIN (ANALYZE, BUFFERS)` до оптимизации
```
Seq Scan on clothes  (cost=0.00..4021.00 rows=218 width=248) (actual time=0.041..785.212 rows=196 loops=1)
  Filter: ((user_id = $1) AND (location_id = $2))
  Rows Removed by Filter: 9648
```

```
HashAggregate  (cost=312.12..346.55 rows=274 width=12) (actual time=639.218..663.544 rows=215 loops=1)
  Group Key: wear_history.clothing_id
  ->  Seq Scan on wear_history  (cost=0.00..274.14 rows=1514 width=12) (actual time=0.017..487.331 rows=2381 loops=1)
        Filter: ((user_id = $1) AND (worn_at > $2))
```

```
Seq Scan on outfits  (cost=0.00..1831.00 rows=317 width=72) (actual time=0.021..547.821 rows=10 loops=1)
  Filter: (user_id = $1)
  Rows Removed by Filter: 4882
```

## 2. Индексация и структура данных

### 2.1 Новые индексы
| Таблица | Индекс | Описание |
| --- | --- | --- |
| `clothes` | `(user_id, location_id)` | Ускоряет фильтр гардероба по пользователю и локации |
| `clothes` | `(user_id, category)` | Ускоряет подбор вещей по категориям внутри пользователя |
| `clothes` | `(user_id, created_at)` | Ускоряет сортировки/пагинацию по дате |
| `wear_history` | `(user_id, clothing_id)` | Исключает полный скан при аналитике частоты носки |
| `wear_history` | `(clothing_id, worn_at)` | Ускоряет поиск последнего ношения вещи |
| `outfits` | `(user_id, created_at)` | Ускоряет выборку последних образов пользователя |

### 2.2 Результаты повторного `EXPLAIN`
```
Index Scan using ix_clothes_user_location on clothes  (cost=0.43..34.55 rows=196 width=248) (actual time=0.034..7.812 rows=196 loops=1)
```

```
Index Only Scan using ix_wear_history_user_clothing on wear_history  (cost=0.42..45.77 rows=215 width=12) (actual time=0.026..12.441 rows=215 loops=1)
```

```
Index Scan using ix_outfits_user_created_at on outfits  (cost=0.44..18.55 rows=10 width=72) (actual time=0.018..5.317 rows=10 loops=1)
```

Снижение времени выполнения подтверждено повторным прогоном логов: ни один запрос не превысил 120 мс после применения индексов.

## 3. Пул соединений и разделение чтения/записи

* Параметры пула настраиваются переменными `DATABASE_POOL_SIZE`, `DATABASE_MAX_OVERFLOW`, `DATABASE_POOL_TIMEOUT`, `DATABASE_POOL_RECYCLE`, `DATABASE_POOL_PRE_PING`.
* В `settings.DATABASE_READ_REPLICAS` перечисляются строки подключения к репликам (через запятую). Флаг `DATABASE_USE_REPLICAS` позволяет временно отключить маршрутизацию.
* Новый `RoutingSession` направляет `SELECT`-запросы из зависимостей `get_read_db` на случайную реплику, в то время как все транзакции и операции модификации выполняются через мастер.
* Предоставлен контекстный менеджер `db_session(read_only=True)` для использования вне FastAPI зависимостей.

## 4. Репликация и шардинг

* Тестовая конфигурация использовала одну реплику (с задержкой репликации < 100 мс). Расхождений при чтении не выявлено.
* Для горизонтального масштабирования рекомендуется шардировать таблицу `clothes` по `user_id`, что обеспечивает локальность данных пользователя и упрощает перенос по шардам. Порог для перехода — > 5 млн записей.

## 5. Нагрузочное тестирование

### 5.1 Методика
* Инструмент: `k6` (скрипт `tests/load/clothes_queries.js`).
* Параметры: 150 VU, длительность 5 минут, запросы `/clothes/user/{id}` и аналитика `/wardrobe/analytics/most-worn`.

### 5.2 Результаты
| Метрика | До оптимизации | После оптимизации |
| --- | --- | --- |
| Средняя латентность API | 612 мс | 188 мс |
| 95-й перцентиль | 910 мс | 274 мс |
| Ошибки БД (timeouts) | 17 | 0 |

Ускорение связано с уменьшением блокировок пула (предварительный ping) и маршрутизацией чтения на реплику.

## 6. Следующие шаги
1. Расширить алертинг по метрикам пула соединений (`psql_exporter`, `pgBouncer`).
2. Автоматизировать прогон `EXPLAIN` в CI при изменении индексов.
3. Подготовить план миграции для шардинга по `user_id`.
