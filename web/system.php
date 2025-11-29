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
    <title>Garderobus Admin — Система</title>
    <link rel="stylesheet" href="assets/css/styles.css" />
  </head>
  <body data-page="system">
    <div class="layout">
      <aside class="sidebar">
        <div class="flex-column gap-sm">
          <h1>Garderobus Admin</h1>
          <span class="text-muted">Панель управления гардеробом</span>
        </div>
        <nav>
          <a href="dashboard.php">Пользователи</a>
          <a href="stats.php">Статистика</a>
          <a href="system.php" class="active">Система</a>
          <a href="database.php">База данных</a>
          <a href="notifications.php">Уведомления</a>
        </nav>
        <button class="link" type="button" id="logout-button">Выйти</button>
      </aside>
      <main class="content">
          <div class="flex-between" style="margin-bottom: 24px; align-items: center; gap: 12px; flex-wrap: wrap;">
            <div class="flex-column gap-xs">
              <h2 class="page-title">Система</h2>
              <p class="text-muted" style="margin: 0;">Мониторинг API, версии и состояния сервисов.</p>
              <div class="status-badges">
                <span class="status-pill" id="maintenance-status-pill">Maintenance: неизвестно</span>
              </div>
            </div>
            <div class="flex gap-sm" id="system-tab-actions">
              <button class="secondary" type="button" id="system-refresh-button">Обновить</button>
              <button class="secondary" type="button" id="queue-button">
                Очередь задач <span class="badge" id="queue-count">—</span>
              </button>
              <button class="secondary" type="button" id="open-code-editor-button">Редактировать код</button>
              <div class="action-menu" id="system-actions-menu">
                <button class="primary action-toggle" type="button" id="system-actions-toggle">
                  Действия
                  <span class="chevron" aria-hidden="true">▾</span>
                </button>
                <div class="action-menu-list hidden" id="system-actions-list" role="menu">
                  <button type="button" class="action-menu-item" data-action="restart-api">Перезапустить API</button>
                  <button type="button" class="action-menu-item" data-action="restart-workers">Перезапустить воркеры</button>
                  <button type="button" class="action-menu-item" data-action="enable-maintenance">Включить maintenance</button>
                  <button type="button" class="action-menu-item" data-action="disable-maintenance">Выключить maintenance</button>
                  <button type="button" class="action-menu-item" data-action="send-test-webhook">Отправить тестовый webhook</button>
                </div>
              </div>
            </div>
          </div>

        <section class="card" aria-live="polite">
          <div id="system-status-error" class="alert hidden" style="margin-bottom: 16px;"></div>
          <div id="system-status-feedback" class="alert success hidden" style="margin-bottom: 16px;"></div>
          <p id="system-status-loading" class="text-muted">Загрузка состояния сервиса...</p>
          <div class="system-metrics-grid hidden" id="system-status-grid">
            <div class="stat-card system-card">
              <h3>Аптайм сервиса</h3>
              <strong id="system-uptime">—</strong>
              <span>В секундах: <span id="system-uptime-seconds">0</span></span>
            </div>
            <div class="stat-card system-card">
              <h3>Версия и окружение</h3>
              <strong id="system-app-name">—</strong>
              <span>Версия: <span id="system-app-version">—</span> · Окружение: <span id="system-environment">—</span></span>
            </div>
            <div class="stat-card system-card">
              <h3>Перезапуск API</h3>
              <strong id="system-restart-state">Недоступно</strong>
              <span>Последний запрос: <span id="system-last-restart">—</span></span>
            </div>
            <div class="stat-card system-card">
              <h3>Редактируемые файлы</h3>
              <strong id="system-files-count">0</strong>
              <div id="system-files-list" class="system-files-list tag-list"></div>
            </div>
            <div class="stat-card system-card">
              <h3>Статусы сервисов</h3>
              <div id="system-service-statuses" class="service-status-list"></div>
            </div>
          </div>
        </section>

        <section class="card system-events" style="margin-top: 24px;">
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
                  <span class="text-muted">На странице</span>
                  <select id="system-events-limit">
                    <option value="10">10</option>
                    <option value="20" selected>20</option>
                    <option value="50">50</option>
                    <option value="100">100</option>
                  </select>
                </label>
              </div>
              <div class="flex gap-sm system-events-meta" style="flex-wrap: wrap; align-items: center;">
                <span class="text-muted" id="system-events-updated-at">Автообновление каждые 5 секунд</span>
                <button class="secondary" type="button" id="system-events-refresh">Обновить сейчас</button>
                <label class="toggle" style="margin-left: auto;">
                  <input type="checkbox" id="system-events-show-empty" />
                  <span>Показывать пустые категории</span>
                </label>
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
          <section id="drawer-queue" class="drawer-section hidden">
            <p class="text-muted" style="margin-top: 0;">
              Здесь отображаются задачи Celery: активные, отложенные и ожидающие обработки.
            </p>

            <div class="flex-between queue-summary">
              <div class="flex-column gap-xs">
                <div class="status-pill" id="queue-total-pill">Всего: —</div>
                <div id="queue-state-badges" class="tag-list"></div>
              </div>
              <div class="flex gap-sm" style="flex-wrap: wrap;">
                <span class="text-muted" id="queue-updated-at">—</span>
                <button class="secondary" type="button" id="queue-refresh">Обновить</button>
              </div>
            </div>

            <div id="queue-error" class="alert hidden" style="margin-top: 12px;"></div>
            <p id="queue-loading" class="text-muted">Загрузка очереди...</p>
            <p id="queue-empty" class="text-muted hidden">Очередь пуста.</p>

            <div id="queue-list" class="queue-list"></div>
          </section>

          <section id="drawer-code-editor" class="drawer-section hidden">
            <p class="text-muted" style="margin-top: 0;">
              Управляйте сервисными сценариями прямо из браузера. Все изменения сразу сохраняются в файловой системе API.
            </p>
            <div class="flex-column gap-md">
              <label class="flex-column gap-sm">
                <span>Файл</span>
                <select id="code-editor-file-select"></select>
              </label>
              <p id="code-editor-empty" class="text-muted hidden">Нет доступных файлов для редактирования. Добавьте их на сервер.</p>
              <div class="flex" style="gap: 8px; flex-wrap: wrap;">
                <button class="secondary" type="button" id="code-editor-refresh">Обновить файл</button>
              </div>
              <label class="flex-column gap-sm">
                <span>Содержимое</span>
                <textarea id="code-editor-content" class="code-editor" rows="18" spellcheck="false"></textarea>
              </label>
              <label class="flex-column gap-sm">
                <span>Комментарий к изменению</span>
                <input type="text" id="code-editor-message" placeholder="Например: обновление логики очистки" />
              </label>
              <div class="drawer-form-actions gap-sm">
                <button class="secondary" type="button" id="code-editor-cancel">Закрыть</button>
                <button class="primary" type="button" id="code-editor-save">Сохранить изменения</button>
              </div>
            </div>
            <p id="code-editor-loading" class="text-muted hidden">Загрузка файла...</p>
            <div id="code-editor-status" class="alert hidden" style="margin-top: 16px;"></div>
          </section>
        </div>
      </div>
    </div>

    <script>
      window.APP_CONFIG = {
        apiBaseUrl: "<?php echo htmlspecialchars($apiBaseUrl, ENT_QUOTES); ?>",
      };
    </script>
    <script src="assets/js/dashboard.js" defer></script>
  </body>
</html>
