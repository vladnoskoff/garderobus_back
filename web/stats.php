<?php
$apiBaseUrl = getenv('API_BASE_URL') ?: 'http://garderobus.tech';
?>
<!DOCTYPE html>
<html lang="ru">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Garderobus Admin — Статистика</title>
    <link rel="stylesheet" href="assets/css/styles.css" />
  </head>
  <body data-page="stats">
    <div class="layout">
      <aside class="sidebar">
        <div class="flex-column gap-sm">
          <h1>Garderobus Admin</h1>
          <span class="text-muted">Панель управления гардеробом</span>
        </div>
        <nav>
          <a href="dashboard.php">Пользователи</a>
          <a href="stats.php" class="active">Статистика</a>
          <a href="system.php">Система</a>
          <a href="database.php">База данных</a>
          <a href="notifications.php">Уведомления</a>
        </nav>
        <button class="link" type="button" id="logout-button">Выйти</button>
      </aside>
      <main class="content">
        <div class="flex-between" style="margin-bottom: 32px;">
          <div>
            <h2 class="page-title">Статистика</h2>
            <p class="text-muted">Обзор активности гардероба по всем учетным записям.</p>
          </div>
          <div class="flex gap-sm">
            <button class="secondary" type="button" id="refresh-button">Обновить</button>
          </div>
        </div>

        <section class="card">
          <div class="grid" style="margin-top: 8px;">
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
