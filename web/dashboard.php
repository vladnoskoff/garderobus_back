<?php
$apiBaseUrl = getenv('API_BASE_URL') ?: 'http://aapanel-api.noksovsteam.ru';
?>
<!DOCTYPE html>
<html lang="ru">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Garderobus Admin — Пользователи</title>
    <link rel="stylesheet" href="assets/css/styles.css" />
  </head>
  <body data-page="users">
    <div class="layout">
      <aside class="sidebar">
        <div class="flex-column gap-sm">
          <h1>Garderobus Admin</h1>
          <span class="text-muted">Панель управления гардеробом</span>
        </div>
        <nav>
          <a href="dashboard.php" class="active">Пользователи</a>
          <a href="stats.php">Статистика</a>
          <a href="system.php">Система</a>
        </nav>
        <button class="link" type="button" id="logout-button">Выйти</button>
      </aside>
      <main class="content">
        <div class="flex-between" style="margin-bottom: 32px;">
          <div>
            <h2 class="page-title">Пользователи</h2>
            <p class="text-muted">Управление учетными записями и обзор активности гардероба.</p>
          </div>
          <div class="flex gap-sm">
            <button class="secondary" type="button" id="refresh-button">Обновить</button>
            <button class="primary" type="button" id="create-user-button">Добавить пользователя</button>
          </div>
        </div>

        <section class="card">
          <div class="flex-between" style="margin-bottom: 20px;">
            <div>
              <h3 style="margin: 0;">Статистика пользователей</h3>
              <span class="text-muted">Отсортировано по идентификатору</span>
            </div>
            <div class="flex gap-sm">
              <button class="secondary" type="button" id="export-csv-button">Экспорт CSV</button>
            </div>
          </div>

          <div class="activity-metrics" aria-live="polite">
            <div class="metrics-grid">
              <div class="metric-card">
                <div class="metric-card-header">Активные сессии</div>
                <div class="metric-values">
                  <div class="metric-value">
                    <span class="metric-label">Сейчас</span>
                    <strong id="metrics-active-now">—</strong>
                  </div>
                  <div class="metric-value">
                    <span class="metric-label">За 24 часа</span>
                    <strong id="metrics-active-day">—</strong>
                  </div>
                </div>
                <p class="metric-hint">Данные обновляются каждые 30 секунд.</p>
              </div>
              <div class="metric-card">
                <div class="metric-card-header">Активность по платформам</div>
                <ul class="platform-breakdown" id="metrics-platforms"></ul>
              </div>
            </div>
            <div id="metrics-error" class="alert hidden" role="status"></div>
          </div>

          <div id="load-error" class="alert hidden" style="margin-bottom: 16px;"></div>
          <p id="loading-indicator" class="text-muted">Загрузка...</p>
          <p id="empty-state" class="text-muted hidden">Пользователи пока не добавлены.</p>
          <div class="table-wrapper hidden" id="users-table-wrapper">
            <table class="table">
              <thead>
                <tr>
                  <th>Пользователь</th>
                  <th>Вещи</th>
                  <th>Фотографии</th>
                  <th>Манекены</th>
                  <th>Примерки (30 дней)</th>
                  <th>Всего примерок</th>
                  <th>Новые вещи (30 дней)</th>
                  <th>Очередь обработки</th>
                  <th>Локации</th>
                  <th>Последнее использование</th>
                  <th>Популярные вещи</th>
                  <th class="actions"></th>
                </tr>
              </thead>
              <tbody id="users-table-body"></tbody>
            </table>
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
          <section id="drawer-create-user" class="drawer-section hidden">
            <p class="text-muted" style="margin-top: 0;">
              Добавьте нового участника, чтобы он мог пользоваться приложением и админ-панелью.
            </p>
            <form id="create-user-form" class="grid drawer-form-grid">
              <label class="flex-column gap-sm">
                <span>Имя</span>
                <input name="name" type="text" placeholder="Иван Иванов" required />
              </label>
              <label class="flex-column gap-sm">
                <span>Email</span>
                <input name="email" type="email" placeholder="user@example.com" required />
              </label>
              <label class="flex-column gap-sm">
                <span>Пароль</span>
                <input name="password" type="password" placeholder="Минимум 6 символов" required />
              </label>
              <label class="flex-column gap-sm">
                <span>Телефон</span>
                <input name="phone" type="text" placeholder="+7 900 000-00-00" />
              </label>
              <label class="flex-column gap-sm">
                <span>Пол</span>
                <input name="gender" type="text" placeholder="female / male" />
              </label>
              <label class="flex-column gap-sm">
                <span>PIN-код (необязательно)</span>
                <input name="pin_code" type="text" placeholder="4-8 цифр" />
              </label>
              <label class="flex-column gap-sm">
                <span>Тема оформления</span>
                <select name="theme_preference">
                  <option value="light">Светлая</option>
                  <option value="dark">Темная</option>
                </select>
              </label>
              <label class="flex-column gap-sm">
                <span>Язык интерфейса</span>
                <select name="language_preference">
                  <option value="ru">Русский</option>
                  <option value="en">English</option>
                </select>
              </label>
              <div class="drawer-form-actions">
                <button class="primary" type="submit" id="create-user-submit">Добавить</button>
              </div>
            </form>
            <div id="create-user-error" class="alert hidden" style="margin-top: 16px;"></div>
            <div id="create-user-success" class="alert success hidden" style="margin-top: 16px;">
              Пользователь успешно создан.
            </div>
          </section>

          <section id="drawer-user-detail" class="drawer-section hidden">
            <div class="detail-header">
              <div>
                <h3 id="detail-name" class="detail-name"></h3>
                <div class="detail-contact">
                  <span id="detail-email"></span>
                  <span id="detail-phone"></span>
                </div>
              </div>
              <div class="detail-pill" id="detail-queue-badge">—</div>
            </div>

            <div class="detail-meta">
              <div class="detail-meta-item">
                <span class="detail-meta-label">Пол</span>
                <strong id="detail-gender">—</strong>
              </div>
              <div class="detail-meta-item">
                <span class="detail-meta-label">Тема</span>
                <strong id="detail-theme">—</strong>
              </div>
              <div class="detail-meta-item">
                <span class="detail-meta-label">Язык</span>
                <strong id="detail-language">—</strong>
              </div>
              <div class="detail-meta-item">
                <span class="detail-meta-label">PIN-код</span>
                <strong id="detail-pin">—</strong>
              </div>
            </div>

            <div class="detail-stats-grid">
              <div class="detail-stat">
                <span class="detail-stat-label">Всего вещей</span>
                <strong id="detail-total-clothes">0</strong>
              </div>
              <div class="detail-stat">
                <span class="detail-stat-label">Фотографии</span>
                <strong id="detail-total-clothes-images">0</strong>
              </div>
              <div class="detail-stat">
                <span class="detail-stat-label">Манекены</span>
                <strong id="detail-total-mannequins">0</strong>
              </div>
              <div class="detail-stat">
                <span class="detail-stat-label">Примерки 30 дней</span>
                <strong id="detail-wear-30">0</strong>
              </div>
              <div class="detail-stat">
                <span class="detail-stat-label">Всего примерок</span>
                <strong id="detail-wear-total">0</strong>
              </div>
              <div class="detail-stat">
                <span class="detail-stat-label">Новые вещи 30 дней</span>
                <strong id="detail-new-clothes-30">0</strong>
              </div>
              <div class="detail-stat">
                <span class="detail-stat-label">Локаций</span>
                <strong id="detail-locations-count">0</strong>
              </div>
              <div class="detail-stat">
                <span class="detail-stat-label">Очередь</span>
                <strong id="detail-queue-value">0</strong>
              </div>
            </div>

            <div class="detail-dates">
              <div>
                <span class="detail-meta-label">Последняя примерка</span>
                <strong id="detail-last-wear">—</strong>
              </div>
              <div>
                <span class="detail-meta-label">Последний манекен</span>
                <strong id="detail-last-mannequin">—</strong>
              </div>
            </div>

            <div class="detail-section">
              <h4>Популярные вещи</h4>
              <div id="detail-top-items" class="detail-top-items"></div>
            </div>

            <div class="detail-section">
              <h4>Локации и гардеробы</h4>
              <p id="detail-loading" class="text-muted hidden">Загрузка данных...</p>
              <div id="detail-error" class="alert hidden" style="margin-bottom: 16px;"></div>
              <p id="detail-no-locations" class="text-muted hidden">Локации ещё не добавлены.</p>
              <div id="detail-locations-list" class="location-list"></div>
            </div>
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
