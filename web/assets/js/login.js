(function () {
  const config = window.APP_CONFIG || {};
  const apiBaseUrl =
    config.apiBaseUrl || "http://garderobus.tech";

  const token = localStorage.getItem("authToken");
  if (token) {
    window.location.replace("dashboard.php");
    return;
  }

  const form = document.getElementById("login-form");
  if (!form) {
    return;
  }

  const emailInput = document.getElementById("login-email");
  const passwordInput = document.getElementById("login-password");
  const errorBox = document.getElementById("login-error");
  const submitButton = document.getElementById("login-submit");

  function showError(message) {
    if (errorBox) {
      errorBox.textContent = message;
      errorBox.classList.remove("hidden");
    }
  }

  function clearError() {
    if (errorBox) {
      errorBox.textContent = "";
      errorBox.classList.add("hidden");
    }
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    clearError();

    const email = (emailInput?.value || "").trim();
    const password = passwordInput?.value || "";

    if (!email || !password) {
      showError("Введите email и пароль.");
      return;
    }

    if (submitButton) {
      submitButton.disabled = true;
      submitButton.textContent = "Вход...";
    }

    try {
      const response = await fetch(`${apiBaseUrl}/admin/login`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email, password }),
      });

      if (!response.ok) {
        throw new Error("Request failed");
      }

      const data = await response.json();
      if (!data || !data.access_token) {
        throw new Error("Invalid response");
      }

      localStorage.setItem("authToken", data.access_token);
      if (typeof data.user_id !== "undefined") {
        localStorage.setItem("userId", String(data.user_id));
      }

      window.location.replace("dashboard.php");
    } catch (error) {
      console.error(error);
      showError("Не удалось войти. Проверьте email и пароль.");
    } finally {
      if (submitButton) {
        submitButton.disabled = false;
        submitButton.textContent = "Войти";
      }
    }
  });
})();
