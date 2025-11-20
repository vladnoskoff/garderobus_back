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
  <body>
    <div class="layout">
      <aside class="sidebar">
        <div class="flex-column gap-sm">
          <h1>Garderobus Admin</h1>
          <span class="text-muted">Панель управления гардеробом</span>
        </div>
        <nav>
          <a href="dashboard.php" class="active">Пользователи</a>
          <a href="#tab-system" data-open-overview-tab="system">Система</a>
        </nav>
        <button class="link" type="button" id="logout-button">Выйти</button>
      </aside>
      <main class="content">
        <div class="flex-between" style="margin-bottom: 32px;">
          <div>
            <h2 class="page-title">Пользователи и статистика</h2>
            <p class="text-muted">Обзор активности гардероба по всем учетным записям.</p>
          </div>
          <div class="flex gap-sm">
            <button class="secondary" type="button" id="refresh-button">Обновить</button>
            <button class="primary" type="button" id="create-user-button">Добавить пользователя</button>
          </div>
        </div>

        <section class="card" id="overview-tabs">
          <div class="tabs-header flex-between">
            <div class="tabs" role="tablist" aria-label="Переключатель панелей">
              <button
                class="tab-button active"
                type="button"
                role="tab"
                aria-selected="true"
                aria-controls="tab-stats"
                id="tab-button-stats"
                data-overview-tab="stats"
              >
                Статистика
              </button>
              <button
                class="tab-button"
                type="button"
                role="tab"
                aria-selected="false"
                aria-controls="tab-system"
                id="tab-button-system"
                data-overview-tab="system"
              >
                Система
              </button>
            </div>
            <div class="flex gap-sm" id="system-tab-actions">
              <button class="secondary hidden" type="button" id="system-refresh-button">Обновить</button>
              <button class="secondary hidden" type="button" id="open-code-editor-button">Редактировать код</button>
              <button class="danger hidden" type="button" id="restart-api-button">Перезапустить API</button>
            </div>
          </div>

          <div id="tab-stats" class="tab-panel active" role="tabpanel" aria-labelledby="tab-button-stats">
            <div class="grid" style="margin-top: 16px;">
              <div class="stat-card">
                <h3>Всего пользователей</h3>
                <strong id="stat-users">0</strong>
                <span>Активные (30 дней): <span id="stat-active-users">0</span></span>
              </div>
              <div class="stat-card">
                <h3>Вещей в гардеробах</h3>
                <strong id="stat-clothes">0</strong>
                <span>Новые за 30 дней: <span id="stat-new-clothes">0</span></span>
              </div>
              <div class="stat-card">
                <h3>Фотографии</h3>
                <strong id="stat-photos">0</strong>
                <span>Манекены: <span id="stat-mannequins">0</span></span>
              </div>
              <div class="stat-card">
                <h3>Образы и использование</h3>
                <strong id="stat-outfits">0</strong>
                <span>Примерок за все время: <span id="stat-wear-events">0</span></span>
              </div>
            </div>
          </div>

          <div
            id="tab-system"
            class="tab-panel hidden"
            role="tabpanel"
            aria-labelledby="tab-button-system"
            aria-live="polite"
          >
            <div class="tab-panel-body">
              <div class="flex-between" style="margin-bottom: 16px;">
                <div>
                  <h3 style="margin: 0;">Сервис и инфраструктура</h3>
                  <p class="text-muted" style="margin: 4px 0 0;">
                    Мониторинг API, версии и состояния сервисов.
                  </p>
                </div>
              </div>
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

              <div class="system-events" id="system-events-block">
                <div class="flex-between" style="margin: 16px 0; align-items: center; gap: 12px; flex-wrap: wrap;">
                  <div>
                    <h3 style="margin: 0;">События и логи</h3>
                    <p class="text-muted" style="margin: 4px 0 0;">Отображаются последние системные записи.</p>
                  </div>
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
                </div>

                <div id="system-events-error" class="alert hidden" style="margin-bottom: 12px;"></div>
                <p id="system-events-loading" class="text-muted">Загрузка событий...</p>
                <p id="system-events-empty" class="text-muted hidden">Событий не найдено за выбранный период.</p>

                <div class="table-wrapper hidden" id="system-events-wrapper">
                  <table class="table">
                    <thead>
                      <tr>
                        <th>Время</th>
                        <th>Уровень</th>
                        <th>Сообщение</th>
                        <th>Источник</th>
                      </tr>
                    </thead>
                    <tbody id="system-events-body"></tbody>
                  </table>
                </div>

                <div class="pagination" id="system-events-pagination">
                  <button class="secondary" type="button" id="system-events-prev">Назад</button>
                  <span class="text-muted" id="system-events-page-info">Страница 1</span>
                  <button class="secondary" type="button" id="system-events-next">Вперед</button>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section class="card">
          <div class="flex-between" style="margin-bottom: 20px;">
            <h3 style="margin: 0;">Статистика пользователей</h3>
            <span class="text-muted">Отсортировано по идентификатору</span>
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
