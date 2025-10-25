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
        </nav>
        <button class="link" type="button" id="logout-button">Выйти</button>
      </aside>
      <main class="content">
        <div class="flex-between" style="margin-bottom: 32px;">
          <div>
            <h2 class="page-title">Пользователи и статистика</h2>
            <p class="text-muted">Обзор активности гардероба по всем учетным записям.</p>
          </div>
          <button class="primary" type="button" id="refresh-button">Обновить</button>
        </div>

        <section class="grid" style="margin-bottom: 32px;">
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
        </section>

        <section class="card" style="margin-bottom: 24px;">
          <h3 style="margin-top: 0;">Создание пользователя</h3>
          <p class="text-muted" style="margin-top: 8px;">
            Добавьте нового участника, чтобы он мог пользоваться приложением и админ-панелью.
          </p>
          <form id="create-user-form" class="grid" style="margin-top: 20px; gap: 16px;">
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
              <select name="theme_preference" style="padding: 10px 12px; border-radius: 10px; border: 1px solid #d1d5db;">
                <option value="light">Светлая</option>
                <option value="dark">Темная</option>
              </select>
            </label>
            <label class="flex-column gap-sm">
              <span>Язык интерфейса</span>
              <select name="language_preference" style="padding: 10px 12px; border-radius: 10px; border: 1px solid #d1d5db;">
                <option value="ru">Русский</option>
                <option value="en">English</option>
              </select>
            </label>
            <div class="flex" style="align-items: flex-end;">
              <button class="primary" type="submit" id="create-user-submit">Добавить</button>
            </div>
          </form>
          <div id="create-user-error" class="alert hidden" style="margin-top: 16px;"></div>
          <div id="create-user-success" class="alert success hidden" style="margin-top: 16px;">
            Пользователь успешно создан.
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

    <script>
      window.APP_CONFIG = {
        apiBaseUrl: "<?php echo htmlspecialchars($apiBaseUrl, ENT_QUOTES); ?>",
      };
    </script>
    <script src="assets/js/dashboard.js" defer></script>
  </body>
</html>
