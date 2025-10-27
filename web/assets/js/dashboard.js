(function () {
  const config = window.APP_CONFIG || {};
  const apiBaseUrl = config.apiBaseUrl || "http://aapanel-api.noksovsteam.ru";

  const token = localStorage.getItem("authToken");
  if (!token) {
    window.location.replace("index.php");
    return;
  }

  const elements = {
    logoutButton: document.getElementById("logout-button"),
    refreshButton: document.getElementById("refresh-button"),
    createUserButton: document.getElementById("create-user-button"),
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
    drawerOverlay: document.getElementById("drawer-overlay"),
    drawer: document.getElementById("drawer"),
    drawerTitle: document.getElementById("drawer-title"),
    drawerClose: document.getElementById("drawer-close"),
    drawerCreateSection: document.getElementById("drawer-create-user"),
    drawerDetailSection: document.getElementById("drawer-user-detail"),
    detailName: document.getElementById("detail-name"),
    detailEmail: document.getElementById("detail-email"),
    detailPhone: document.getElementById("detail-phone"),
    detailGender: document.getElementById("detail-gender"),
    detailTheme: document.getElementById("detail-theme"),
    detailLanguage: document.getElementById("detail-language"),
    detailPin: document.getElementById("detail-pin"),
    detailQueueBadge: document.getElementById("detail-queue-badge"),
    detailTotalClothes: document.getElementById("detail-total-clothes"),
    detailTotalClothesImages: document.getElementById("detail-total-clothes-images"),
    detailTotalMannequins: document.getElementById("detail-total-mannequins"),
    detailWear30: document.getElementById("detail-wear-30"),
    detailWearTotal: document.getElementById("detail-wear-total"),
    detailNewClothes30: document.getElementById("detail-new-clothes-30"),
    detailLocationsCount: document.getElementById("detail-locations-count"),
    detailQueueValue: document.getElementById("detail-queue-value"),
    detailLastWear: document.getElementById("detail-last-wear"),
    detailLastMannequin: document.getElementById("detail-last-mannequin"),
    detailTopItems: document.getElementById("detail-top-items"),
    detailLocationsList: document.getElementById("detail-locations-list"),
    detailLocationsEmpty: document.getElementById("detail-no-locations"),
    detailError: document.getElementById("detail-error"),
    detailLoading: document.getElementById("detail-loading"),
  };

  const state = {
    drawerMode: null,
    activeDetailUserId: null,
    detailAbortController: null,
  };

  function handleUnauthorized() {
    localStorage.removeItem("authToken");
    localStorage.removeItem("userId");
    window.location.replace("index.php");
  }

  function setDrawerVisibility(open) {
    if (!elements.drawerOverlay || !elements.drawer) {
      return;
    }
    if (open) {
      elements.drawerOverlay.classList.remove("hidden");
      requestAnimationFrame(() => {
        elements.drawerOverlay?.classList.add("active");
        elements.drawer?.classList.add("active");
      });
    } else {
      elements.drawerOverlay.classList.remove("active");
      elements.drawer.classList.remove("active");
      window.setTimeout(() => {
        if (!elements.drawerOverlay?.classList.contains("active")) {
          elements.drawerOverlay?.classList.add("hidden");
        }
      }, 220);
    }
  }

  function showDrawerSection(section) {
    if (!elements.drawer) {
      return;
    }
    const sections = [elements.drawerCreateSection, elements.drawerDetailSection];
    sections.forEach((item) => {
      if (item) {
        toggleHidden(item, item !== section);
      }
    });
  }

  function openDrawer(mode) {
    state.drawerMode = mode;
    if (elements.drawerTitle) {
      elements.drawerTitle.textContent =
        mode === "create" ? "Создание пользователя" : "Карточка пользователя";
    }
    setDrawerVisibility(true);
    if (mode === "create") {
      showDrawerSection(elements.drawerCreateSection);
      toggleHidden(elements.createError, true);
      toggleHidden(elements.createSuccess, true);
    } else {
      showDrawerSection(elements.drawerDetailSection);
    }
  }

  function closeDrawer() {
    state.drawerMode = null;
    state.activeDetailUserId = null;
    if (state.detailAbortController) {
      state.detailAbortController.abort();
      state.detailAbortController = null;
    }
    setDrawerVisibility(false);
    showDrawerSection(null);
    if (elements.detailError) {
      toggleHidden(elements.detailError, true);
    }
    if (elements.detailLoading) {
      toggleHidden(elements.detailLoading, true);
    }
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

  function renderQueueBadge(count) {
    const badge = document.createElement("span");
    badge.className = "status-badge " + (count > 0 ? "warning" : "success");
    badge.textContent = count > 0 ? `${count} в очереди` : "Очередь пуста";
    return badge;
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

      const queueCell = document.createElement("td");
      queueCell.appendChild(renderQueueBadge(user.pending_metadata_items || 0));
      row.appendChild(queueCell);

      const locationCell = document.createElement("td");
      locationCell.textContent = String(user.locations_count ?? 0);
      row.appendChild(locationCell);

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

      const detailButton = document.createElement("button");
      detailButton.className = "secondary";
      detailButton.type = "button";
      detailButton.textContent = "Подробнее";
      detailButton.addEventListener("click", () => {
        void loadUserDetail(user.id);
      });
      actionsCell.appendChild(detailButton);

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

  function setDetailQueueBadge(value) {
    if (!elements.detailQueueBadge) {
      return;
    }
    elements.detailQueueBadge.textContent = value > 0 ? `${value} в очереди` : "Очередь пуста";
    elements.detailQueueBadge.className =
      "detail-pill" + (value > 0 ? " detail-pill-warning" : " detail-pill-success");
  }

  function renderLocationCard(location) {
    const card = document.createElement("div");
    card.className = "location-card";

    const header = document.createElement("div");
    header.className = "location-card-header";
    const title = document.createElement("strong");
    title.textContent = location.name || "Без названия";
    header.appendChild(title);

    if (location.created_at && !location.is_virtual) {
      const meta = document.createElement("span");
      meta.className = "location-meta";
      meta.textContent = `Создана: ${formatDate(location.created_at, false)}`;
      header.appendChild(meta);
    }

    card.appendChild(header);

    if (location.pending_metadata_items > 0) {
      const queueBadge = renderQueueBadge(location.pending_metadata_items);
      card.appendChild(queueBadge);
    }

    const stats = document.createElement("dl");
    stats.className = "location-stats";

    function appendStat(label, value) {
      const term = document.createElement("dt");
      term.textContent = label;
      stats.appendChild(term);
      const data = document.createElement("dd");
      data.textContent = String(value ?? 0);
      stats.appendChild(data);
    }

    appendStat("Вещи", location.total_clothes);
    appendStat("Новые", location.new_clothes_last_30_days);
    appendStat("Фото", location.total_clothes_images);
    appendStat("Примерки", location.total_wear_events);
    appendStat("Манекены", location.mannequins_generated);
    appendStat("Очередь", location.pending_metadata_items);

    card.appendChild(stats);
    return card;
  }

  function renderUserDetail(detail) {
    if (elements.detailError) {
      toggleHidden(elements.detailError, true);
    }
    setText(elements.detailName, detail.name || "Без имени");
    setText(elements.detailEmail, detail.email || "—");
    setText(elements.detailPhone, detail.phone || "Телефон не указан");

    const genderMap = { female: "Женский", male: "Мужской" };
    setText(elements.detailGender, genderMap[detail.gender] || detail.gender || "Не указан");

    const themeMap = { light: "Светлая", dark: "Тёмная" };
    setText(elements.detailTheme, themeMap[detail.theme_preference] || detail.theme_preference);

    const languageMap = { ru: "Русский", en: "English" };
    setText(elements.detailLanguage, languageMap[detail.language_preference] || detail.language_preference);

    setText(elements.detailPin, detail.has_pin ? "Установлен" : "Нет");

    setText(elements.detailTotalClothes, detail.total_clothes ?? 0);
    setText(elements.detailTotalClothesImages, detail.total_clothes_images ?? 0);
    setText(elements.detailTotalMannequins, detail.total_mannequins ?? 0);
    setText(elements.detailWear30, detail.wear_events_last_30_days ?? 0);
    setText(elements.detailWearTotal, detail.total_wear_events ?? 0);
    setText(elements.detailNewClothes30, detail.new_clothes_last_30_days ?? 0);
    setText(elements.detailLocationsCount, detail.locations_count ?? 0);
    setText(elements.detailQueueValue, detail.pending_metadata_items ?? 0);

    setText(elements.detailLastWear, formatDate(detail.last_wear_at, true));
    setText(elements.detailLastMannequin, formatDate(detail.last_mannequin_at, true));

    setDetailQueueBadge(detail.pending_metadata_items || 0);

    if (elements.detailTopItems) {
      elements.detailTopItems.innerHTML = "";
      elements.detailTopItems.appendChild(formatTopItems(detail));
    }

    if (elements.detailLocationsList) {
      elements.detailLocationsList.innerHTML = "";
      const locations = Array.isArray(detail.locations) ? detail.locations : [];
      if (locations.length === 0) {
        toggleHidden(elements.detailLocationsEmpty, false);
      } else {
        toggleHidden(elements.detailLocationsEmpty, true);
        locations.forEach((location) => {
          elements.detailLocationsList?.appendChild(renderLocationCard(location));
        });
      }
    }
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

  async function loadUserDetail(userId, options) {
    const keepDrawer = options?.keepDrawerOpen ?? false;
    state.activeDetailUserId = userId;

    if (!keepDrawer) {
      openDrawer("detail");
    } else {
      showDrawerSection(elements.drawerDetailSection);
    }

    if (elements.detailError) {
      toggleHidden(elements.detailError, true);
    }
    if (elements.detailLoading) {
      elements.detailLoading.textContent = "Загрузка данных...";
      toggleHidden(elements.detailLoading, false);
    }
    if (elements.detailLocationsList) {
      elements.detailLocationsList.innerHTML = "";
    }
    if (elements.detailLocationsEmpty) {
      toggleHidden(elements.detailLocationsEmpty, true);
    }
    if (elements.detailTopItems) {
      elements.detailTopItems.innerHTML = "";
    }
    if (elements.detailQueueBadge) {
      elements.detailQueueBadge.className = "detail-pill";
      elements.detailQueueBadge.textContent = "Загрузка...";
    }

    if (state.detailAbortController) {
      state.detailAbortController.abort();
    }
    const controller = new AbortController();
    state.detailAbortController = controller;

    try {
      const response = await fetch(`${apiBaseUrl}/admin/users/${userId}`, {
        headers: {
          Authorization: `Bearer ${localStorage.getItem("authToken")}`,
        },
        signal: controller.signal,
      });

      if (response.status === 401) {
        handleUnauthorized();
        return;
      }
      if (!response.ok) {
        throw new Error("Request failed");
      }

      const detail = await response.json();
      renderUserDetail(detail);
    } catch (error) {
      if (error.name === "AbortError") {
        return;
      }
      console.error(error);
      if (elements.detailError) {
        elements.detailError.textContent = "Не удалось загрузить карточку пользователя.";
        toggleHidden(elements.detailError, false);
      }
    } finally {
      if (elements.detailLoading) {
        toggleHidden(elements.detailLoading, true);
      }
      if (state.detailAbortController === controller) {
        state.detailAbortController = null;
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

      if (state.drawerMode === "detail" && state.activeDetailUserId) {
        void loadUserDetail(state.activeDetailUserId, { keepDrawerOpen: true });
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

  if (elements.createUserButton) {
    elements.createUserButton.addEventListener("click", () => {
      openDrawer("create");
    });
  }

  if (elements.drawerClose) {
    elements.drawerClose.addEventListener("click", () => {
      closeDrawer();
    });
  }

  if (elements.drawerOverlay) {
    elements.drawerOverlay.addEventListener("click", (event) => {
      if (event.target === elements.drawerOverlay) {
        closeDrawer();
      }
    });
  }

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && state.drawerMode) {
      closeDrawer();
    }
  });

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
