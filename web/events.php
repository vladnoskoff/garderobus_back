<?php
$host = $_SERVER['HTTP_HOST'] ?? '';
$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https://' : 'http://';
$guessedBaseUrl = $host ? $scheme . $host : 'http://localhost';
$apiBaseUrl = rtrim(getenv('API_BASE_URL') ?: $guessedBaseUrl, '/');
?>
<!DOCTYPE html>
<html lang="ru">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Garderobus Admin — События и логи</title>
    <link rel="stylesheet" href="assets/css/styles.css" />
  </head>
  <body data-page="events">
    <div class="layout">
      <aside class="sidebar">
        <div class="flex-column gap-sm">
          <h1>Garderobus Admin</h1>
          <span class="text-muted">Панель управления гардеробом</span>
        </div>
        <nav>
          <a href="dashboard.php">Пользователи</a>
          <a href="stats.php">Статистика</a>
          <a href="system.php">Система</a>
          <a href="events.php" class="active">События и логи</a>
          <a href="database.php">База данных</a>
          <a href="notifications.php">Уведомления</a>
        </nav>
        <button class="link" type="button" id="logout-button">Выйти</button>
      </aside>
      <main class="content">
        <div class="flex-between" style="margin-bottom: 24px; align-items: center; gap: 12px; flex-wrap: wrap;">
          <div class="flex-column gap-xs">
            <h2 class="page-title">События и логи</h2>
            <p class="text-muted" style="margin: 0;">Мониторинг последних системных записей.</p>
          </div>
          <div class="flex gap-sm">
            <button class="secondary" type="button" id="system-events-refresh">Обновить</button>
            <label class="toggle" style="align-self: center;">
              <input type="checkbox" id="system-events-show-empty" />
              <span>Показывать пустые категории</span>
            </label>
          </div>
        </div>

        <section class="card system-events" aria-live="polite">
          <div class="flex-between" style="margin: 16px 0; align-items: flex-start; gap: 12px; flex-wrap: wrap;">
            <div>
              <h3 style="margin: 0;">События и логи</h3>
              <p class="text-muted" style="margin: 4px 0 0;">Отображаются последние системные записи.</p>
            </div>
            <div class="flex-column gap-xs" style="flex: 1 1 420px;">
              <div class="flex gap-sm" style="flex-wrap: wrap;">
                <label class="filter-control">
                  <span class="text-muted">Тип события</span>
                  <select id="system-events-level">
                    <option value="">Все</option>
                    <option value="info">Информация</option>
                    <option value="warning">Предупреждения</option>
                    <option value="error">Ошибки</option>
                  </select>
                </label>
                <label class="filter-control">
                  <span class="text-muted">Период</span>
                  <select id="system-events-period">
                    <option value="">Весь</option>
                    <option value="24">24 часа</option>
                    <option value="72">3 дня</option>
                    <option value="168">7 дней</option>
                  </select>
                </label>
                <label class="filter-control">
                  <span class="text-muted">Авторизация</span>
                  <select id="system-events-auth">
                    <option value="">Всё</option>
                    <option value="authorized">Авторизованные</option>
                    <option value="unauthorized">Неавторизованные</option>
                  </select>
                </label>
                <label class="filter-control">
                  <span class="text-muted">На странице</span>
                  <select id="system-events-limit">
                    <option value="10" selected>10</option>
                    <option value="20">20</option>
                    <option value="50">50</option>
                    <option value="100">100</option>
                  </select>
                </label>
              </div>
              <div class="flex gap-sm system-events-meta" style="flex-wrap: wrap; align-items: center;">
                <span class="text-muted" id="system-events-updated-at">Автообновление каждые 5 секунд</span>
                <button class="secondary" type="button" id="system-ip-blocks">Блокировка IP</button>
                <button class="secondary" type="button" id="system-events-exclusions">Исключения запросов</button>
              </div>
            </div>
          </div>

          <div id="system-events-error" class="alert hidden" style="margin-bottom: 12px;"></div>
          <p id="system-events-loading" class="text-muted">Загрузка событий...</p>
          <p id="system-events-empty" class="text-muted hidden">Событий не найдено за выбранный период.</p>

          <div class="events-group-container hidden" id="system-events-wrapper">
            <div id="system-events-groups" class="events-groups"></div>
          </div>

          <div class="pagination" id="system-events-pagination">
            <button class="secondary" type="button" id="system-events-prev">Назад</button>
            <span class="text-muted" id="system-events-page-info">Страница 1</span>
            <button class="secondary" type="button" id="system-events-next">Вперед</button>
          </div>
        </section>
      </main>
    </div>

    <div class="drawer-overlay hidden" id="drawer-overlay" role="presentation">
      <div class="drawer" id="drawer" role="dialog" aria-modal="true" aria-labelledby="drawer-title">
        <div class="drawer-header">
          <h3 id="drawer-title" class="drawer-title"></h3>
          <button class="icon-button" type="button" id="drawer-close" aria-label="Закрыть панель">
            <span aria-hidden="true">&times;</span>
          </button>
        </div>
        <div class="drawer-body" id="drawer-content">
          <section id="drawer-event-exclusions" class="drawer-section hidden">
            <p class="text-muted" style="margin-top: 0;">
              Настройте, какие запросы скрывать из лент событий. Добавленные правила сразу применяются ко всем категориям логов.
            </p>
            <form id="event-exclusions-form" class="flex-column gap-sm" style="margin-bottom: 16px;">
              <div class="flex gap-sm" style="flex-wrap: wrap;">
                <label class="flex-column gap-xs" style="flex: 1 1 200px; min-width: 200px;">
                  <span>Категория</span>
                  <select id="event-exclusions-category"></select>
                </label>
                <label class="flex-column gap-xs" style="width: 140px;">
                  <span>Метод</span>
                  <select id="event-exclusions-method">
                    <option value="">Любой</option>
                    <option value="GET">GET</option>
                    <option value="POST">POST</option>
                    <option value="PUT">PUT</option>
                    <option value="PATCH">PATCH</option>
                    <option value="DELETE">DELETE</option>
                  </select>
                </label>
                <label class="flex-column gap-xs" style="flex: 2 1 260px; min-width: 240px;">
                  <span>Путь запроса</span>
                  <input id="event-exclusions-path" type="text" placeholder="Например: /admin/system/status" required />
                </label>
              </div>
              <div class="flex gap-sm" style="flex-wrap: wrap; align-items: center;">
                <button class="primary" type="submit">Добавить правило</button>
                <span class="text-muted">Сравнение выполняется по точному пути. Метод можно оставить пустым.</span>
              </div>
            </form>

            <div id="event-exclusions-status" class="alert hidden" style="margin-bottom: 12px;"></div>
            <div class="table-wrapper">
              <table class="table events-table" id="event-exclusions-table">
                <thead>
                  <tr>
                    <th style="width: 180px;">Категория</th>
                    <th style="width: 100px;">Метод</th>
                    <th>Путь</th>
                    <th style="width: 100px; text-align: right;">Действия</th>
                  </tr>
                </thead>
                <tbody id="event-exclusions-body"></tbody>
              </table>
            </div>
            <p class="text-muted" id="event-exclusions-empty">Пока нет скрытых запросов.</p>
          </section>

          <section id="drawer-ip-blocks" class="drawer-section hidden">
            <p class="text-muted" style="margin-top: 0;">
              Управляйте списком IP-адресов, которым запрещено обращаться к API. Блокировка применяется как к пользовательскому API, так и к админ-панели.
            </p>

            <form id="ip-blocks-form" class="flex-column gap-sm" style="margin-bottom: 16px;">
              <div class="flex gap-sm" style="flex-wrap: wrap; align-items: flex-end;">
                <label class="flex-column gap-xs" style="flex: 1 1 220px; min-width: 200px;">
                  <span>IP-адрес</span>
                  <input id="ip-blocks-address" type="text" placeholder="Например: 203.0.113.42" required />
                </label>
                <label class="flex-column gap-xs" style="flex: 1 1 240px; min-width: 200px;">
                  <span>Комментарий</span>
                  <input id="ip-blocks-note" type="text" placeholder="Например: тестовый стенд" />
                </label>
                <button class="primary" type="submit">Добавить блокировку</button>
              </div>
            </form>

            <div id="ip-blocks-status" class="alert hidden" style="margin-bottom: 12px;"></div>
            <div class="table-wrapper">
              <table class="table events-table" id="ip-blocks-table">
                <thead>
                  <tr>
                    <th style="width: 200px;">IP-адрес</th>
                    <th>Комментарий</th>
                    <th style="width: 180px;">Добавлено</th>
                    <th style="width: 120px; text-align: right;">Действия</th>
                  </tr>
                </thead>
                <tbody id="ip-blocks-body"></tbody>
              </table>
            </div>
            <p class="text-muted" id="ip-blocks-empty">Список блокировок пуст.</p>
          </section>
        </div>
      </div>
    </div>

    <script>
      window.APP_CONFIG = {
        apiBaseUrl: "<?php echo htmlspecialchars($apiBaseUrl, ENT_QUOTES); ?>",
      };
    </script>
    <script src="assets/js/events.js" defer></script>
  </body>
</html>
