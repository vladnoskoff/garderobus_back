<?php
$apiBaseUrl = getenv('API_BASE_URL') ?: 'http://localhost:8000';
?>
<!DOCTYPE html>
<html lang="ru">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Garderobus Admin — Вход</title>
    <link rel="stylesheet" href="assets/css/styles.css" />
  </head>
  <body>
    <div class="full-height-center">
      <div class="card" style="max-width: 420px; width: 100%;">
        <div class="flex-column gap-md" style="margin-bottom: 24px;">
          <h2 style="margin: 0;">Вход в админ-панель</h2>
          <p class="text-muted" style="margin: 0;">
            Используйте учетную запись администратора, чтобы управлять пользователями и статистикой.
          </p>
        </div>
        <form id="login-form" class="flex-column gap-md" novalidate>
          <label class="flex-column gap-sm">
            <span>Email</span>
            <input id="login-email" type="email" placeholder="admin@example.com" required />
          </label>
          <label class="flex-column gap-sm">
            <span>Пароль</span>
            <input id="login-password" type="password" placeholder="Введите пароль" required />
          </label>
          <div id="login-error" class="alert hidden"></div>
          <button class="primary" type="submit" id="login-submit">Войти</button>
        </form>
      </div>
    </div>
    <script>
      window.APP_CONFIG = {
        apiBaseUrl: "<?php echo htmlspecialchars($apiBaseUrl, ENT_QUOTES); ?>",
      };
    </script>
    <script src="assets/js/login.js" defer></script>
  </body>
</html>
