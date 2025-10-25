(function () {
  const config = window.APP_CONFIG || {};
  const apiBaseUrl = config.apiBaseUrl || "http://localhost:8000";

  const token = localStorage.getItem("authToken");
  if (!token) {
    window.location.replace("index.php");
    return;
  }

  const elements = {
    logoutButton: document.getElementById("logout-button"),
    refreshButton: document.getElementById("refresh-button"),
    loadingIndicator: document.getElementById("loading-indicator"),
    loadError: document.getElementById("load-error"),
    tableWrapper: document.getElementById("users-table-wrapper"),
    tableBody: document.getElementById("users-table-body"),
    emptyState: document.getElementById("empty-state"),
    statUsers: document.getElementById("stat-users"),
    statActiveUsers: document.getElementById("stat-active-users"),
    statClothes: document.getElementById("stat-clothes"),
    statNewClothes: document.getElementById("stat-new-clothes"),
    statPhotos: document.getElementById("stat-photos"),
    statMannequins: document.getElementById("stat-mannequins"),
    statOutfits: document.getElementById("stat-outfits"),
    statWearEvents: document.getElementById("stat-wear-events"),
    createForm: document.getElementById("create-user-form"),
    createSubmit: document.getElementById("create-user-submit"),
    createError: document.getElementById("create-user-error"),
    createSuccess: document.getElementById("create-user-success"),
  };

  function handleUnauthorized() {
    localStorage.removeItem("authToken");
    localStorage.removeItem("userId");
    window.location.replace("index.php");
  }

  function toggleHidden(element, hidden) {
    if (!element) {
      return;
    }
    if (hidden) {
      element.classList.add("hidden");
    } else {
      element.classList.remove("hidden");
    }
  }

  function setText(element, value) {
    if (element) {
      element.textContent = value;
    }
  }

  function formatDate(value, withTime) {
    if (!value) {
      return "—";
    }
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      return "—";
    }
    const pad = (num) => String(num).padStart(2, "0");
    const day = pad(date.getDate());
    const month = pad(date.getMonth() + 1);
    const year = date.getFullYear();
    if (withTime) {
      const hours = pad(date.getHours());
      const minutes = pad(date.getMinutes());
      return `${day}.${month}.${year} ${hours}:${minutes}`;
    }
    return `${day}.${month}.${year}`;
  }

  function formatTopItems(user) {
    if (!user.top_worn_items || !user.top_worn_items.length) {
      const span = document.createElement("span");
      span.className = "text-muted";
      span.textContent = "Нет данных";
      return span;
    }
    const container = document.createElement("div");
    container.className = "tag-list";
    user.top_worn_items.forEach((item) => {
      const badge = document.createElement("span");
      badge.className = "badge";
      badge.textContent = `${item.name} · ${item.usage_count}`;
      container.appendChild(badge);
    });
    return container;
  }

  function renderUsers(users) {
    if (!elements.tableBody) {
      return;
    }
    elements.tableBody.innerHTML = "";
    const sorted = [...users].sort((a, b) => a.id - b.id);
    sorted.forEach((user) => {
      const row = document.createElement("tr");

      const userCell = document.createElement("td");
      const userInfo = document.createElement("div");
      userInfo.className = "flex-column gap-sm";
      const name = document.createElement("strong");
      name.textContent = user.name || "Без имени";
      const email = document.createElement("span");
      email.className = "text-muted";
      email.textContent = user.email;
      userInfo.appendChild(name);
      userInfo.appendChild(email);
      if (user.phone) {
        const phone = document.createElement("span");
        phone.className = "text-muted";
        phone.textContent = user.phone;
        userInfo.appendChild(phone);
      }
      userCell.appendChild(userInfo);
      row.appendChild(userCell);

      function createTextCell(value) {
        const cell = document.createElement("td");
        cell.textContent = String(value ?? 0);
        return cell;
      }

      row.appendChild(createTextCell(user.total_clothes));
      row.appendChild(createTextCell(user.total_clothes_images));
      row.appendChild(createTextCell(user.total_mannequins));
      row.appendChild(createTextCell(user.wear_events_last_30_days));
      row.appendChild(createTextCell(user.total_wear_events));
      row.appendChild(createTextCell(user.new_clothes_last_30_days));

      const lastWearCell = document.createElement("td");
      const datesContainer = document.createElement("div");
      datesContainer.className = "flex-column gap-sm";
      const wearSpan = document.createElement("span");
      wearSpan.textContent = formatDate(user.last_wear_at, true);
      const mannequinSpan = document.createElement("span");
      mannequinSpan.className = "text-muted";
      mannequinSpan.textContent = `Манекен: ${formatDate(user.last_mannequin_at, false)}`;
      datesContainer.appendChild(wearSpan);
      datesContainer.appendChild(mannequinSpan);
      lastWearCell.appendChild(datesContainer);
      row.appendChild(lastWearCell);

      const topItemsCell = document.createElement("td");
      topItemsCell.appendChild(formatTopItems(user));
      row.appendChild(topItemsCell);

      const actionsCell = document.createElement("td");
      actionsCell.className = "actions";
      const deleteButton = document.createElement("button");
      deleteButton.className = "danger";
      deleteButton.type = "button";
      deleteButton.textContent = "Удалить";
      deleteButton.addEventListener("click", () => {
        const confirmed = window.confirm(
          `Удалить пользователя ${user.name || user.email}? Это действие необратимо.`
        );
        if (!confirmed) {
          return;
        }
        deleteUser(user.id);
      });
      actionsCell.appendChild(deleteButton);
      row.appendChild(actionsCell);

      elements.tableBody.appendChild(row);
    });
  }

  function updateStats(users) {
    const totals = users.reduce(
      (acc, user) => {
        acc.clothes += user.total_clothes || 0;
        acc.photos += user.total_clothes_images || 0;
        acc.mannequins += user.total_mannequins || 0;
        acc.outfits += user.total_outfits || 0;
        acc.wearEvents += user.total_wear_events || 0;
        acc.newClothes += user.new_clothes_last_30_days || 0;
        if ((user.wear_events_last_30_days || 0) > 0) {
          acc.activeUsers += 1;
        }
        return acc;
      },
      { clothes: 0, photos: 0, mannequins: 0, outfits: 0, wearEvents: 0, activeUsers: 0, newClothes: 0 }
    );

    setText(elements.statUsers, users.length.toString());
    setText(elements.statActiveUsers, totals.activeUsers.toString());
    setText(elements.statClothes, totals.clothes.toString());
    setText(elements.statNewClothes, totals.newClothes.toString());
    setText(elements.statPhotos, totals.photos.toString());
    setText(elements.statMannequins, totals.mannequins.toString());
    setText(elements.statOutfits, totals.outfits.toString());
    setText(elements.statWearEvents, totals.wearEvents.toString());
  }

  async function deleteUser(userId) {
    toggleHidden(elements.loadError, true);
    try {
      const response = await fetch(`${apiBaseUrl}/admin/users/${userId}`, {
        method: "DELETE",
        headers: {
          Authorization: `Bearer ${localStorage.getItem("authToken")}`,
        },
      });
      if (response.status === 401) {
        handleUnauthorized();
        return;
      }
      if (!response.ok) {
        throw new Error("Request failed");
      }
      await loadUsers();
    } catch (error) {
      console.error(error);
      if (elements.loadError) {
        elements.loadError.textContent = "Не удалось удалить пользователя. Попробуйте снова.";
        toggleHidden(elements.loadError, false);
      }
    }
  }

  async function loadUsers() {
    if (elements.loadingIndicator) {
      elements.loadingIndicator.textContent = "Загрузка...";
      toggleHidden(elements.loadingIndicator, false);
    }
    toggleHidden(elements.loadError, true);
    toggleHidden(elements.emptyState, true);
    toggleHidden(elements.tableWrapper, true);

    try {
      const response = await fetch(`${apiBaseUrl}/admin/users/summary`, {
        headers: {
          Authorization: `Bearer ${localStorage.getItem("authToken")}`,
        },
      });
      if (response.status === 401) {
        handleUnauthorized();
        return;
      }
      if (!response.ok) {
        throw new Error("Request failed");
      }
      const data = await response.json();
      const users = Array.isArray(data) ? data : [];
      updateStats(users);
      renderUsers(users);
      if (users.length === 0) {
        toggleHidden(elements.emptyState, false);
      } else {
        toggleHidden(elements.tableWrapper, false);
      }
    } catch (error) {
      console.error(error);
      if (elements.loadError) {
        elements.loadError.textContent = "Не удалось загрузить пользователей. Попробуйте позже.";
        toggleHidden(elements.loadError, false);
      }
    } finally {
      if (elements.loadingIndicator) {
        toggleHidden(elements.loadingIndicator, true);
      }
    }
  }

  if (elements.logoutButton) {
    elements.logoutButton.addEventListener("click", () => {
      localStorage.removeItem("authToken");
      localStorage.removeItem("userId");
      window.location.replace("index.php");
    });
  }

  if (elements.refreshButton) {
    elements.refreshButton.addEventListener("click", () => {
      void loadUsers();
    });
  }

  if (elements.createForm) {
    elements.createForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (!elements.createSubmit) {
        return;
      }
      toggleHidden(elements.createError, true);
      toggleHidden(elements.createSuccess, true);
      elements.createSubmit.disabled = true;
      elements.createSubmit.textContent = "Создание...";

      try {
        const formData = new FormData(elements.createForm);
        const payload = {
          name: (formData.get("name") || "").toString().trim(),
          email: (formData.get("email") || "").toString().trim().toLowerCase(),
          password: (formData.get("password") || "").toString(),
          theme_preference: (formData.get("theme_preference") || "light").toString(),
          language_preference: (formData.get("language_preference") || "ru").toString(),
        };

        const optionalFields = ["phone", "gender", "pin_code"];
        optionalFields.forEach((field) => {
          const value = (formData.get(field) || "").toString().trim();
          if (value) {
            payload[field] = value;
          }
        });

        const response = await fetch(`${apiBaseUrl}/admin/users`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${localStorage.getItem("authToken")}`,
          },
          body: JSON.stringify(payload),
        });

        if (response.status === 401) {
          handleUnauthorized();
          return;
        }
        if (!response.ok) {
          throw new Error("Request failed");
        }

        elements.createForm.reset();
        toggleHidden(elements.createSuccess, false);
        void loadUsers();
      } catch (error) {
        console.error(error);
        if (elements.createError) {
          elements.createError.textContent = "Не удалось создать пользователя. Проверьте данные и повторите попытку.";
          toggleHidden(elements.createError, false);
        }
      } finally {
        if (elements.createSubmit) {
          elements.createSubmit.disabled = false;
          elements.createSubmit.textContent = "Добавить";
        }
      }
    });
  }

  void loadUsers();
})();
