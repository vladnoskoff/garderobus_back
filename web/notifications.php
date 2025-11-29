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
    <title>Garderobus Admin — Уведомления</title>
    <link rel="stylesheet" href="assets/css/styles.css" />
  </head>
  <body data-page="notifications">
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
          <a href="database.php">База данных</a>
          <a href="notifications.php" class="active">Уведомления</a>
        </nav>
        <button class="link" type="button" id="logout-button">Выйти</button>
      </aside>
      <main class="content">
        <div class="flex-between" style="margin-bottom: 24px; align-items: center; gap: 12px; flex-wrap: wrap;">
          <div class="flex-column gap-xs">
            <h2 class="page-title">Уведомления</h2>
            <p class="text-muted" style="margin: 0;">Каналы доставки, шаблоны и правила маршрутизации событий.</p>
          </div>
          <div class="flex gap-sm" style="flex-wrap: wrap;">
            <button class="secondary" type="button" id="refresh-button">Обновить</button>
            <button class="primary" type="button" id="create-channel-button">Добавить канал</button>
            <button class="primary" type="button" id="create-template-button">Новый шаблон</button>
            <button class="secondary" type="button" id="create-rule-button">Создать правило</button>
          </div>
        </div>

        <section class="card">
          <div class="flex-between" style="margin-bottom: 12px;">
            <div>
              <h3 style="margin: 0;">Каналы уведомлений</h3>
              <p class="text-muted" style="margin: 4px 0 0;">Email, Telegram, Slack или вебхуки с быстрым тестом подключения.</p>
            </div>
          </div>
          <div id="channels-error" class="alert hidden" style="margin-bottom: 12px;"></div>
          <p id="channels-loading" class="text-muted">Загрузка каналов...</p>
          <p id="channels-empty" class="text-muted hidden">Каналы еще не настроены.</p>
          <div class="table-wrapper hidden" id="channels-table-wrapper">
            <table class="table">
              <thead>
                <tr>
                  <th>Название</th>
                  <th>Тип</th>
                  <th>Статус</th>
                  <th>Активен</th>
                  <th>Последняя проверка</th>
                  <th class="actions"></th>
                </tr>
              </thead>
              <tbody id="channels-table-body"></tbody>
            </table>
          </div>
        </section>

        <section class="card" style="margin-top: 24px;">
          <div class="flex-between" style="margin-bottom: 12px;">
            <div>
              <h3 style="margin: 0;">Шаблоны</h3>
              <p class="text-muted" style="margin: 4px 0 0;">Используйте переменные {{user}} и {{issue}} для подстановки данных.</p>
            </div>
          </div>
          <div id="templates-error" class="alert hidden" style="margin-bottom: 12px;"></div>
          <p id="templates-loading" class="text-muted">Загрузка шаблонов...</p>
          <p id="templates-empty" class="text-muted hidden">Шаблоны пока не созданы.</p>
          <div class="table-wrapper hidden" id="templates-table-wrapper">
            <table class="table">
              <thead>
                <tr>
                  <th>Название</th>
                  <th>Канал</th>
                  <th>Обновлен</th>
                  <th class="actions"></th>
                </tr>
              </thead>
              <tbody id="templates-table-body"></tbody>
            </table>
          </div>
        </section>

        <section class="card" style="margin-top: 24px;">
          <div class="flex-between" style="margin-bottom: 12px;">
            <div>
              <h3 style="margin: 0;">Правила маршрутизации</h3>
              <p class="text-muted" style="margin: 4px 0 0;">Связь событий с каналами и приоритетами доставки.</p>
            </div>
            <label class="filter-control">
              <span class="text-muted">Фильтр по событию</span>
              <input type="text" id="rules-filter" placeholder="Например: user.created" />
            </label>
          </div>
          <div id="rules-error" class="alert hidden" style="margin-bottom: 12px;"></div>
          <p id="rules-loading" class="text-muted">Загрузка правил...</p>
          <p id="rules-empty" class="text-muted hidden">Правил нет.</p>
          <div class="table-wrapper hidden" id="rules-table-wrapper">
            <table class="table">
              <thead>
                <tr>
                  <th>Событие</th>
                  <th>Приоритет</th>
                  <th>Каналы</th>
                  <th>Шаблон</th>
                  <th class="actions"></th>
                </tr>
              </thead>
              <tbody id="rules-table-body"></tbody>
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
          <section id="drawer-channel" class="drawer-section hidden">
            <form class="grid drawer-form-grid" id="channel-form">
              <label class="flex-column gap-sm">
                <span>Название</span>
                <input name="name" type="text" placeholder="Поддержка" required />
              </label>
              <label class="flex-column gap-sm">
                <span>Тип</span>
                <select name="channel_type" required>
                  <option value="email">Email</option>
                  <option value="telegram">Telegram</option>
                  <option value="slack">Slack</option>
                  <option value="webhook">Webhook</option>
                </select>
              </label>
              <label class="flex-column gap-sm">
                <span>Конфигурация (JSON)</span>
                <textarea name="config" rows="6" placeholder='{"token": "..."}'></textarea>
              </label>
              <label class="flex gap-sm" style="align-items: center;">
                <input type="checkbox" name="is_active" checked />
                <span>Активен</span>
              </label>
              <div class="drawer-form-actions">
                <button class="secondary" type="button" id="channel-cancel">Отмена</button>
                <button class="primary" type="submit" id="channel-save">Сохранить</button>
              </div>
            </form>
            <div id="channel-status" class="alert hidden" style="margin-top: 12px;"></div>
          </section>

          <section id="drawer-template" class="drawer-section hidden">
            <form class="grid drawer-form-grid" id="template-form">
              <label class="flex-column gap-sm">
                <span>Название</span>
                <input name="name" type="text" placeholder="Инцидент" required />
              </label>
              <label class="flex-column gap-sm">
                <span>Канал</span>
                <select name="channel_type">
                  <option value="">Любой</option>
                  <option value="email">Email</option>
                  <option value="telegram">Telegram</option>
                  <option value="slack">Slack</option>
                  <option value="webhook">Webhook</option>
                </select>
              </label>
              <label class="flex-column gap-sm">
                <span>Текст</span>
                <textarea name="content" rows="10" placeholder="{{user}} столкнулся с {{issue}}" required></textarea>
              </label>
              <label class="flex-column gap-sm">
                <span>Доп. переменные (JSON)</span>
                <textarea name="variables" rows="4" placeholder='{"severity": "high"}'></textarea>
              </label>
              <div class="drawer-form-actions">
                <button class="secondary" type="button" id="template-cancel">Отмена</button>
                <button class="primary" type="submit" id="template-save">Сохранить</button>
              </div>
            </form>
            <div class="card" style="margin-top: 12px;">
              <h4 style="margin-top: 0;">Предпросмотр</h4>
              <p class="text-muted" style="margin-top: 0;">{{user}} и {{issue}} автоматически заменяются на реальные значения.</p>
              <pre id="template-preview" class="code-editor" style="min-height: 120px; white-space: pre-wrap;"></pre>
            </div>
            <div id="template-status" class="alert hidden" style="margin-top: 12px;"></div>
          </section>

          <section id="drawer-rule" class="drawer-section hidden">
            <form class="grid drawer-form-grid" id="rule-form">
              <label class="flex-column gap-sm">
                <span>Событие</span>
                <input name="event" type="text" placeholder="user.created" required />
              </label>
              <label class="flex-column gap-sm">
                <span>Приоритет</span>
                <input name="priority" type="number" value="0" />
              </label>
              <label class="flex-column gap-sm">
                <span>Каналы</span>
                <select name="channel_ids" id="rule-channels" multiple size="4"></select>
              </label>
              <label class="flex-column gap-sm">
                <span>Шаблон</span>
                <select name="template_id" id="rule-templates"></select>
              </label>
              <label class="flex-column gap-sm">
                <span>Фильтры (JSON)</span>
                <textarea name="filters" rows="4" placeholder='{"location": "msk"}'></textarea>
              </label>
              <div class="drawer-form-actions">
                <button class="secondary" type="button" id="rule-cancel">Отмена</button>
                <button class="primary" type="submit" id="rule-save">Сохранить</button>
              </div>
            </form>
            <div id="rule-status" class="alert hidden" style="margin-top: 12px;"></div>
          </section>
        </div>
      </div>
    </div>

    <script>
      window.APP_CONFIG = {
        apiBaseUrl: "<?php echo htmlspecialchars($apiBaseUrl, ENT_QUOTES); ?>",
      };
    </script>
    <script src="assets/js/notifications.js" defer></script>
  </body>
</html>
