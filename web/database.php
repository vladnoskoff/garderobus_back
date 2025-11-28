<?php
$apiBaseUrl = getenv('API_BASE_URL') ?: 'http://garderobus.tech';
?>
<!DOCTYPE html>
<html lang="ru">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Garderobus Admin — База данных</title>
    <link rel="stylesheet" href="assets/css/styles.css" />
  </head>
  <body data-page="database">
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
          <a href="database.php" class="active">База данных</a>
          <a href="notifications.php">Уведомления</a>
        </nav>
        <button class="link" type="button" id="logout-button">Выйти</button>
      </aside>
      <main class="content">
        <div class="flex-between" style="margin-bottom: 24px; align-items: center; gap: 12px; flex-wrap: wrap;">
          <div class="flex-column gap-xs">
            <h2 class="page-title">База данных</h2>
            <p class="text-muted" style="margin: 0;">Просмотр таблиц, создание бэкапов и восстановление данных.</p>
          </div>
          <div class="flex gap-sm" style="flex-wrap: wrap;">
            <button class="secondary" type="button" id="database-refresh-button">Обновить</button>
            <button class="secondary" type="button" id="database-backup-button">Скачать бэкап</button>
          </div>
        </div>

        <section class="card" aria-live="polite">
          <div class="flex-between" style="margin-bottom: 16px; align-items: center; gap: 12px; flex-wrap: wrap;">
            <div>
              <h3 style="margin: 0;">Структура базы</h3>
              <p class="text-muted" style="margin: 4px 0 0;">Список таблиц и количество записей.</p>
            </div>
          </div>

          <div id="database-summary-error" class="alert hidden" style="margin-bottom: 12px;"></div>
          <p id="database-summary-loading" class="text-muted">Загрузка таблиц...</p>
          <p id="database-summary-empty" class="text-muted hidden">Таблиц не найдено.</p>

          <div class="table-wrapper hidden" id="database-summary-wrapper">
            <table class="table">
              <thead>
                <tr>
                  <th>Таблица</th>
                  <th>Колонки</th>
                  <th>Записей</th>
                </tr>
              </thead>
              <tbody id="database-summary-body"></tbody>
            </table>
          </div>
        </section>

        <section class="card" style="margin-top: 24px;">
          <div class="flex-between" style="margin: 16px 0; align-items: center; gap: 12px; flex-wrap: wrap;">
            <div>
              <h3 style="margin: 0;">Данные таблицы</h3>
              <p class="text-muted" style="margin: 4px 0 0;">Быстрый просмотр содержимого выбранной таблицы.</p>
            </div>
            <div class="flex gap-sm" style="flex-wrap: wrap; align-items: flex-end;">
              <label class="filter-control">
                <span class="text-muted">Таблица</span>
                <select id="database-table-select"></select>
              </label>
              <button class="secondary" type="button" id="database-table-refresh">Показать</button>
            </div>
          </div>

          <div id="database-rows-error" class="alert hidden" style="margin-bottom: 12px;"></div>
          <p id="database-rows-loading" class="text-muted">Выберите таблицу для просмотра.</p>
          <p id="database-rows-empty" class="text-muted hidden">Нет данных для отображения.</p>

          <div class="table-wrapper hidden" id="database-rows-wrapper">
            <table class="table">
              <thead>
                <tr id="database-rows-head"></tr>
              </thead>
              <tbody id="database-rows-body"></tbody>
            </table>
          </div>
          <p class="text-muted" id="database-rows-total" style="margin-top: 12px;">—</p>
        </section>

        <section class="card" style="margin-top: 24px;">
          <div class="flex-between" style="margin: 16px 0; align-items: center; gap: 12px; flex-wrap: wrap;">
            <div>
              <h3 style="margin: 0;">Восстановление</h3>
              <p class="text-muted" style="margin: 4px 0 0;">Загрузите ранее скачанный JSON-бэкап, чтобы вернуть данные.</p>
            </div>
            <div class="flex" style="gap: 8px; flex-wrap: wrap; align-items: center;">
              <input type="file" id="database-restore-file" accept="application/json" />
              <button class="primary" type="button" id="database-restore-button">Восстановить</button>
            </div>
          </div>
          <div id="database-backup-status" class="alert hidden"></div>
          <p class="text-muted" style="margin-top: 8px;">При восстановлении текущие данные таблиц будут перезаписаны.</p>
        </section>
      </main>
    </div>

    <script>
      window.APP_CONFIG = {
        apiBaseUrl: "<?php echo htmlspecialchars($apiBaseUrl, ENT_QUOTES); ?>",
      };
    </script>
    <script src="assets/js/dashboard.js" defer></script>
  </body>
</html>
