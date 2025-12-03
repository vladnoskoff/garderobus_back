(function () {
  const config = window.APP_CONFIG || {};
  const apiBaseUrl = (config.apiBaseUrl || window.location.origin || "http://garderobus.tech").replace(/\/$/, "");

  const token = localStorage.getItem("authToken");
  if (!token) {
    window.location.replace("index.php");
    return;
  }

  const elements = {
    logoutButton: document.getElementById("logout-button"),
    systemEventsWrapper: document.getElementById("system-events-wrapper"),
    systemEventsGroups: document.getElementById("system-events-groups"),
    systemEventsLoading: document.getElementById("system-events-loading"),
    systemEventsEmpty: document.getElementById("system-events-empty"),
    systemEventsError: document.getElementById("system-events-error"),
    systemEventsLevel: document.getElementById("system-events-level"),
    systemEventsPeriod: document.getElementById("system-events-period"),
    systemEventsLimit: document.getElementById("system-events-limit"),
    systemEventsRefresh: document.getElementById("system-events-refresh"),
    systemIpBlocks: document.getElementById("system-ip-blocks"),
    systemEventsExclusions: document.getElementById("system-events-exclusions"),
    systemEventsUpdatedAt: document.getElementById("system-events-updated-at"),
    systemEventsShowEmpty: document.getElementById("system-events-show-empty"),
    systemEventsPrev: document.getElementById("system-events-prev"),
    systemEventsNext: document.getElementById("system-events-next"),
    systemEventsPageInfo: document.getElementById("system-events-page-info"),
    drawerOverlay: document.getElementById("drawer-overlay"),
    drawer: document.getElementById("drawer"),
    drawerTitle: document.getElementById("drawer-title"),
    drawerClose: document.getElementById("drawer-close"),
    drawerEventExclusionsSection: document.getElementById("drawer-event-exclusions"),
    drawerIpBlocksSection: document.getElementById("drawer-ip-blocks"),
    eventExclusionsForm: document.getElementById("event-exclusions-form"),
    eventExclusionsCategory: document.getElementById("event-exclusions-category"),
    eventExclusionsMethod: document.getElementById("event-exclusions-method"),
    eventExclusionsPath: document.getElementById("event-exclusions-path"),
    eventExclusionsEmpty: document.getElementById("event-exclusions-empty"),
    eventExclusionsStatus: document.getElementById("event-exclusions-status"),
    eventExclusionsBody: document.getElementById("event-exclusions-body"),
    ipBlocksForm: document.getElementById("ip-blocks-form"),
    ipBlocksAddress: document.getElementById("ip-blocks-address"),
    ipBlocksNote: document.getElementById("ip-blocks-note"),
    ipBlocksStatus: document.getElementById("ip-blocks-status"),
    ipBlocksBody: document.getElementById("ip-blocks-body"),
    ipBlocksEmpty: document.getElementById("ip-blocks-empty"),
  };

  const state = {
    drawerMode: null,
    systemEvents: {
      page: 1,
      limit: 20,
      level: "",
      hours: "",
      total: 0,
      loadedOnce: false,
      loading: false,
      lastSignature: "",
      refreshInterval: null,
      latestEvents: [],
      showEmpty: false,
      exclusions: [],
      exclusionsLoaded: false,
      exclusionsLoading: false,
    },
    ipBlocks: {
      items: [],
      loaded: false,
      loading: false,
    },
  };

  function handleUnauthorized() {
    localStorage.removeItem("authToken");
    localStorage.removeItem("userId");
    window.location.replace("index.php");
  }

  function toggleHidden(element, hidden) {
    if (!element) return;
    element.classList.toggle("hidden", Boolean(hidden));
  }

  function showAlert(element, message, type = "error") {
    if (!element) return;
    if (!message) {
      element.textContent = "";
      element.classList.remove("success");
      element.classList.add("hidden");
      return;
    }
    element.textContent = message;
    element.classList.remove("hidden");
    element.classList.toggle("success", type === "success");
  }

  async function safeReadError(response) {
    try {
      const text = await response.text();
      return text || response.statusText || "";
    } catch (err) {
      console.error("Failed to read error response", err);
      return response.statusText || "";
    }
  }

  function setDrawerVisibility(open) {
    if (!elements.drawerOverlay || !elements.drawer) return;
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

  function setDrawerSectionVisibility(target) {
    const sections = [elements.drawerEventExclusionsSection, elements.drawerIpBlocksSection];
    sections.forEach((section) => {
      if (!section) return;
      toggleHidden(section, section !== target);
    });
  }

  function openDrawer(mode) {
    state.drawerMode = mode;
    setDrawerVisibility(true);
    switch (mode) {
      case "event-exclusions":
        setDrawerSectionVisibility(elements.drawerEventExclusionsSection);
        if (elements.drawerTitle) elements.drawerTitle.textContent = "Исключения запросов";
        break;
      case "ip-blocks":
        setDrawerSectionVisibility(elements.drawerIpBlocksSection);
        if (elements.drawerTitle) elements.drawerTitle.textContent = "Блокировка IP";
        break;
      default:
        setDrawerVisibility(false);
        break;
    }
  }

  function closeDrawer() {
    state.drawerMode = null;
    setDrawerVisibility(false);
    setDrawerSectionVisibility(null);
  }

  function formatDate(value, withTime) {
    if (!value) return "—";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "—";
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

  function formatEventLevel(level) {
    const normalized = (level || "info").toLowerCase();
    const map = { info: "Инфо", warning: "Внимание", error: "Ошибка" };
    return map[normalized] || normalized;
  }

  function formatEventMessage(event) {
    if (!event) return "—";
    return event.message || "—";
  }

  const EVENT_CATEGORY_ORDER = ["application", "api_admin", "database", "xray", "workers", "other"];
  const EVENT_CATEGORY_LABELS = {
    application: "Приложение",
    api_admin: "Api_admin",
    database: "База данных",
    xray: "VPN / Xray",
    workers: "Очереди и воркеры",
    other: "Прочее",
  };
  const EVENT_CATEGORY_HINTS = {
    application: "Основные сервисы и логи из папки api (main:8000).",
    api_admin: "HTTP-запросы и ошибки админского API (api_admin:8100).",
    database: "Подключения к БД, запросы и миграции.",
    xray: "VPN/Xray-тоннель и прокси-доступ к внешним API.",
    workers: "Очереди Celery и фоновые задания.",
    other: "Логи без явной категории.",
  };
  const CLIENT_ORIGIN_LABELS = {
    flutter_app: "Мобильное приложение",
    browser: "Браузер",
    api_client: "Инструмент API",
    unknown: "Неизвестно",
  };

  function formatClientOrigin(origin, hint) {
    const normalized = String(origin || "unknown").toLowerCase();
    const label = CLIENT_ORIGIN_LABELS[normalized] || CLIENT_ORIGIN_LABELS.unknown;
    return hint ? `${label} (${hint})` : label;
  }

  function normalizeEventCategory(category) {
    const raw = String(category || "").toLowerCase();
    const normalized = (() => {
      if (raw === "api") return "application";
      if (["vpn", "xray", "proxy", "socks"].includes(raw)) return "xray";
      return raw;
    })();
    if (EVENT_CATEGORY_ORDER.includes(normalized)) {
      return normalized;
    }
    return normalized ? "other" : "application";
  }

  function detectFallbackCategory(event) {
    const parts = [event?.service, event?.logger, event?.message]
      .filter(Boolean)
      .map((value) => String(value).toLowerCase())
      .join(" ");
    const contextText = Object.values(event?.context || {})
      .filter((value) => typeof value === "string")
      .join(" ")
      .toLowerCase();
    const searchable = `${parts} ${contextText}`.trim();
    const hasAny = (tokens) => tokens.some((token) => searchable.includes(token));
    if (hasAny(["xray", "vpn", "socks"])) return "xray";
    if (hasAny(["db", "database", "postgres", "psql", "sqlalchemy", "mysql", "sqlite"])) return "database";
    if (hasAny(["admin", "api_admin", "8100"])) return "api_admin";
    if (hasAny(["uvicorn", "fastapi", "api", "http", "request", "endpoint", "8000", "main"])) return "application";
    if (hasAny(["celery", "worker", "queue", "task"])) return "workers";
    return "application";
  }

  function getEventCategory(event) {
    const hasExplicit = event?.category !== undefined && event?.category !== null && event?.category !== "";
    if (hasExplicit) {
      return normalizeEventCategory(event.category);
    }
    return detectFallbackCategory(event);
  }

  function groupEventsByCategory(events) {
    const buckets = EVENT_CATEGORY_ORDER.reduce((acc, key) => {
      acc[key] = [];
      return acc;
    }, {});
    (events || []).forEach((event) => {
      const category = getEventCategory(event);
      const bucketKey = EVENT_CATEGORY_ORDER.includes(category) ? category : "other";
      buckets[bucketKey].push(event);
    });
    return buckets;
  }

  function buildEventRow(event) {
    const row = document.createElement("tr");

    const timeCell = document.createElement("td");
    const timeText = document.createElement("div");
    timeText.className = "event-time";
    timeText.textContent = formatDate(event.timestamp, true);
    timeCell.appendChild(timeText);
    row.appendChild(timeCell);

    const levelCell = document.createElement("td");
    const badge = document.createElement("span");
    const levelClass = event.level === "error" ? "error" : event.level === "warning" ? "warning" : "info";
    badge.className = `status-badge ${levelClass}`;
    badge.textContent = formatEventLevel(event.level);
    levelCell.appendChild(badge);
    row.appendChild(levelCell);

    const messageCell = document.createElement("td");
    const messagePrimary = document.createElement("div");
    messagePrimary.className = "event-message-primary";
    messagePrimary.textContent = formatEventMessage(event);
    messageCell.appendChild(messagePrimary);

    const categoryLabel = EVENT_CATEGORY_LABELS[getEventCategory(event)];
    if (categoryLabel) {
      const messageMeta = document.createElement("div");
      messageMeta.className = "event-message-meta";
      messageMeta.textContent = categoryLabel;
      messageCell.appendChild(messageMeta);
    }

    const details = buildEventDetails(event);
    if (details.length) {
      const detailsContainer = document.createElement("ul");
      detailsContainer.className = "event-message-details";
      details.forEach((item) => {
        const li = document.createElement("li");
        li.textContent = `${item.label}: ${item.value}`;
        detailsContainer.appendChild(li);
      });
      messageCell.appendChild(detailsContainer);
    }
    row.appendChild(messageCell);

    const sourceCell = document.createElement("td");
    const sourceChip = document.createElement("span");
    sourceChip.className = "tag";
    sourceChip.textContent = event.source || event.service || "—";
    sourceCell.appendChild(sourceChip);
    row.appendChild(sourceCell);

    return row;
  }

  function buildEventDetails(event) {
    if (!event) return [];
    const context = event.context || {};
    const details = [];
    if (context.method && context.path) {
      details.push({ label: "Запрос", value: `${context.method} ${context.path}` });
    } else if (context.method) {
      details.push({ label: "Метод", value: context.method });
    }
    if (typeof context.status_code === "number") {
      details.push({ label: "Статус", value: String(context.status_code) });
    }
    if (typeof context.duration_ms === "number") {
      const rounded = Math.round(Number(context.duration_ms));
      details.push({ label: "Время", value: `${rounded} мс` });
    }
    if (context.client) {
      details.push({ label: "Клиент", value: context.client });
    }
    if (context.client_origin || context.client_origin_hint) {
      details.push({ label: "Источник клиента", value: formatClientOrigin(context.client_origin, context.client_origin_hint) });
    }
    if (context.user_email || context.user_id) {
      const parts = [];
      if (context.user_email) parts.push(context.user_email);
      if (context.user_id) parts.push(`#${context.user_id}`);
      const label = parts.length ? parts.join(" · ") : "-";
      details.push({ label: "Пользователь", value: label });
    }
    if (context.token !== undefined) {
      details.push({ label: "Токен", value: context.token || "-" });
    }
    if (context.request_id) {
      details.push({ label: "Request ID", value: context.request_id });
    }
    return details.filter(Boolean);
  }

  function renderSystemEvents(events) {
    if (!elements.systemEventsGroups) return;
    elements.systemEventsGroups.innerHTML = "";
    if (!events || !events.length) {
      toggleHidden(elements.systemEventsWrapper, true);
      toggleHidden(elements.systemEventsEmpty, false);
      return;
    }
    toggleHidden(elements.systemEventsWrapper, false);
    toggleHidden(elements.systemEventsEmpty, true);
    const buckets = groupEventsByCategory(events);
    const showEmpty = state.systemEvents.showEmpty;
    let rendered = 0;
    EVENT_CATEGORY_ORDER.forEach((category) => {
      const bucket = buckets[category] || [];
      if (!bucket.length && !showEmpty) return;
      const section = document.createElement("section");
      section.className = "event-category";
      const header = document.createElement("div");
      header.className = "event-category-header";
      const info = document.createElement("div");
      info.className = "event-category-info";
      const title = document.createElement("div");
      title.className = "event-category-title";
      title.textContent = EVENT_CATEGORY_LABELS[category] || category;
      const hint = document.createElement("p");
      hint.className = "text-muted event-category-hint";
      hint.textContent = EVENT_CATEGORY_HINTS[category] || "";
      info.appendChild(title);
      info.appendChild(hint);
      const count = document.createElement("span");
      count.className = "badge event-category-count";
      count.textContent = `${bucket.length || 0} записей`;
      header.appendChild(info);
      header.appendChild(count);
      section.appendChild(header);
      if (!bucket.length) {
        const empty = document.createElement("p");
        empty.className = "text-muted event-category-empty";
        empty.textContent = "Нет событий в этой категории";
        section.appendChild(empty);
        elements.systemEventsGroups.appendChild(section);
        rendered += 1;
        return;
      }
      const tableWrapper = document.createElement("div");
      tableWrapper.className = "table-wrapper event-category-table";
      const table = document.createElement("table");
      table.className = "table events-table events-subtable";
      const thead = document.createElement("thead");
      const headerRow = document.createElement("tr");
      ["Время", "Уровень", "Сообщение", "Источник"].forEach((label) => {
        const th = document.createElement("th");
        th.textContent = label;
        headerRow.appendChild(th);
      });
      thead.appendChild(headerRow);
      table.appendChild(thead);
      const tbody = document.createElement("tbody");
      bucket.forEach((event) => {
        tbody.appendChild(buildEventRow(event));
      });
      table.appendChild(tbody);
      tableWrapper.appendChild(table);
      section.appendChild(tableWrapper);
      elements.systemEventsGroups.appendChild(section);
      rendered += 1;
    });
    if (rendered === 0) {
      toggleHidden(elements.systemEventsWrapper, true);
      toggleHidden(elements.systemEventsEmpty, false);
    }
  }

  function computeEventsSignature(events) {
    if (!events || !events.length) return "";
    return events
      .slice(0, 20)
      .map((event) => {
        const requestId = event.context?.request_id || event.request_id || "";
        return [event.timestamp || "", event.level || "", event.message || "", requestId].join("|");
      })
      .join(";");
  }

  function updateSystemEventsPagination() {
    if (!elements.systemEventsPageInfo) return;
    const totalPages = Math.max(1, Math.ceil(state.systemEvents.total / state.systemEvents.limit));
    const currentPage = Math.min(state.systemEvents.page, totalPages);
    state.systemEvents.page = currentPage;
    elements.systemEventsPageInfo.textContent = `Страница ${currentPage} из ${totalPages}`;
    if (elements.systemEventsPrev) {
      elements.systemEventsPrev.disabled = currentPage <= 1;
    }
    if (elements.systemEventsNext) {
      elements.systemEventsNext.disabled = currentPage >= totalPages;
    }
  }

  function updateEventsTimestamp(hasChanges) {
    if (!elements.systemEventsUpdatedAt) return;
    const now = new Date();
    const pad = (num) => String(num).padStart(2, "0");
    const timestamp = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
    const suffix = hasChanges ? " (обновлено)" : "";
    elements.systemEventsUpdatedAt.textContent = `Обновлено ${timestamp}${suffix}`;
    elements.systemEventsUpdatedAt.classList.toggle("highlight", hasChanges);
    if (hasChanges) {
      window.setTimeout(() => elements.systemEventsUpdatedAt?.classList.remove("highlight"), 1200);
    }
  }

  function populateExclusionCategoriesSelect() {
    if (!elements.eventExclusionsCategory) return;
    elements.eventExclusionsCategory.innerHTML = "";
    EVENT_CATEGORY_ORDER.forEach((category) => {
      const option = document.createElement("option");
      option.value = category;
      option.textContent = EVENT_CATEGORY_LABELS[category] || category;
      elements.eventExclusionsCategory.appendChild(option);
    });
  }

  function renderEventExclusionsTable() {
    if (!elements.eventExclusionsBody || !elements.eventExclusionsEmpty) return;
    const list = state.systemEvents.exclusions || [];
    elements.eventExclusionsBody.innerHTML = "";
    if (!list.length) {
      toggleHidden(elements.eventExclusionsEmpty, false);
      return;
    }
    toggleHidden(elements.eventExclusionsEmpty, true);
    list.forEach((item) => {
      const row = document.createElement("tr");
      const categoryCell = document.createElement("td");
      categoryCell.textContent = EVENT_CATEGORY_LABELS[item.category] || item.category || "—";
      const methodCell = document.createElement("td");
      methodCell.textContent = item.method || "Любой";
      const pathCell = document.createElement("td");
      pathCell.textContent = item.path || "—";
      const actionsCell = document.createElement("td");
      actionsCell.style.textAlign = "right";
      const deleteButton = document.createElement("button");
      deleteButton.className = "link danger";
      deleteButton.dataset.action = "delete-exclusion";
      deleteButton.dataset.id = item.id;
      deleteButton.textContent = "Удалить";
      actionsCell.appendChild(deleteButton);
      [categoryCell, methodCell, pathCell, actionsCell].forEach((cell) => row.appendChild(cell));
      elements.eventExclusionsBody.appendChild(row);
    });
  }

  function setIpBlocksStatus(message, type = "error") {
    showAlert(elements.ipBlocksStatus, message, type);
  }

  function renderIpBlocks() {
    if (!elements.ipBlocksBody || !elements.ipBlocksEmpty) return;
    const list = state.ipBlocks.items || [];
    elements.ipBlocksBody.innerHTML = "";
    if (!list.length) {
      toggleHidden(elements.ipBlocksEmpty, false);
      return;
    }
    toggleHidden(elements.ipBlocksEmpty, true);
    list.forEach((item) => {
      const row = document.createElement("tr");
      const ipCell = document.createElement("td");
      ipCell.textContent = item.ip || "—";
      const noteCell = document.createElement("td");
      noteCell.textContent = item.note || "—";
      const addedCell = document.createElement("td");
      addedCell.textContent = item.created_at ? formatDate(item.created_at, true) : "—";
      const actionsCell = document.createElement("td");
      actionsCell.style.textAlign = "right";
      const deleteButton = document.createElement("button");
      deleteButton.className = "link danger";
      deleteButton.dataset.action = "delete-ip-block";
      deleteButton.dataset.ip = item.ip;
      deleteButton.textContent = "Удалить";
      actionsCell.appendChild(deleteButton);
      [ipCell, noteCell, addedCell, actionsCell].forEach((cell) => row.appendChild(cell));
      elements.ipBlocksBody.appendChild(row);
    });
  }

  async function loadEventExclusions(options = {}) {
    if (state.systemEvents.exclusionsLoading) return;
    const { silent = false } = options;
    state.systemEvents.exclusionsLoading = true;
    if (!silent) showAlert(elements.eventExclusionsStatus, "Загружаем правила...", "success");
    try {
      const response = await fetch(`${apiBaseUrl}/admin/system/events/exclusions`, {
        headers: { Authorization: `Bearer ${localStorage.getItem("authToken")}` },
      });
      if (response.status === 401) return handleUnauthorized();
      if (!response.ok) throw new Error("Request failed");
      const payload = await response.json();
      state.systemEvents.exclusions = payload.exclusions || [];
      state.systemEvents.exclusionsLoaded = true;
      renderEventExclusionsTable();
      if (!silent) showAlert(elements.eventExclusionsStatus, "Правила загружены", "success");
    } catch (error) {
      console.error(error);
      showAlert(elements.eventExclusionsStatus, error?.message || "Не удалось загрузить правила");
    } finally {
      state.systemEvents.exclusionsLoading = false;
    }
  }

  async function submitEventExclusion(event) {
    event.preventDefault();
    const category = elements.eventExclusionsCategory?.value || "application";
    const method = elements.eventExclusionsMethod?.value || "";
    const path = (elements.eventExclusionsPath?.value || "").trim();
    if (!path) {
      showAlert(elements.eventExclusionsStatus, "Укажите путь", "error");
      return;
    }
    showAlert(elements.eventExclusionsStatus, "Сохраняем правило...", "success");
    try {
      const response = await fetch(`${apiBaseUrl}/admin/system/events/exclusions`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${localStorage.getItem("authToken")}`,
        },
        body: JSON.stringify({ category, method, path }),
      });
      if (response.status === 401) return handleUnauthorized();
      if (!response.ok) throw new Error(await safeReadError(response));
      const payload = await response.json();
      state.systemEvents.exclusions = payload.exclusions || [];
      state.systemEvents.exclusionsLoaded = true;
      renderEventExclusionsTable();
      if (elements.eventExclusionsForm) elements.eventExclusionsForm.reset();
      showAlert(elements.eventExclusionsStatus, "Правило добавлено", "success");
    } catch (error) {
      console.error(error);
      showAlert(elements.eventExclusionsStatus, error?.message || "Не удалось сохранить правило");
    }
  }

  async function deleteEventExclusion(id) {
    if (!id) return;
    showAlert(elements.eventExclusionsStatus, "Удаляем правило...", "success");
    try {
      const response = await fetch(`${apiBaseUrl}/admin/system/events/exclusions/${encodeURIComponent(id)}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${localStorage.getItem("authToken")}` },
      });
      if (response.status === 401) return handleUnauthorized();
      if (!response.ok) throw new Error(await safeReadError(response));
      const payload = await response.json();
      state.systemEvents.exclusions = payload.exclusions || [];
      state.systemEvents.exclusionsLoaded = true;
      renderEventExclusionsTable();
      showAlert(elements.eventExclusionsStatus, "Правило удалено", "success");
    } catch (error) {
      console.error(error);
      showAlert(elements.eventExclusionsStatus, error?.message || "Не удалось удалить правило");
    }
  }

  async function loadIpBlocks(options = {}) {
    if (state.ipBlocks.loading) return;
    const { silent = false } = options;
    state.ipBlocks.loading = true;
    if (!silent) setIpBlocksStatus("Загружаем блокировки...", "success");
    try {
      const response = await fetch(`${apiBaseUrl}/admin/system/ip-blocks`, {
        headers: { Authorization: `Bearer ${localStorage.getItem("authToken")}` },
      });
      if (response.status === 401) return handleUnauthorized();
      if (!response.ok) throw new Error(await safeReadError(response));
      const payload = await response.json();
      state.ipBlocks.items = payload.blocks || [];
      state.ipBlocks.loaded = true;
      renderIpBlocks();
      if (!silent) setIpBlocksStatus("Список блокировок обновлён", "success");
    } catch (error) {
      console.error(error);
      setIpBlocksStatus(error?.message || "Не удалось загрузить блокировки", "error");
    } finally {
      state.ipBlocks.loading = false;
    }
  }

  async function createIpBlock(event) {
    event.preventDefault();
    const ip = (elements.ipBlocksAddress?.value || "").trim();
    const note = (elements.ipBlocksNote?.value || "").trim();
    if (!ip) {
      setIpBlocksStatus("Укажите IP-адрес", "error");
      return;
    }
    setIpBlocksStatus("Добавляем блокировку...", "success");
    try {
      const response = await fetch(`${apiBaseUrl}/admin/system/ip-blocks`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${localStorage.getItem("authToken")}`,
        },
        body: JSON.stringify({ ip, note }),
      });
      if (response.status === 401) return handleUnauthorized();
      if (!response.ok) throw new Error(await safeReadError(response));
      const payload = await response.json();
      state.ipBlocks.items = payload.blocks || [];
      state.ipBlocks.loaded = true;
      renderIpBlocks();
      elements.ipBlocksForm?.reset();
      setIpBlocksStatus("IP добавлен в блокировку", "success");
    } catch (error) {
      console.error(error);
      setIpBlocksStatus(error?.message || "Не удалось добавить IP", "error");
    }
  }

  async function deleteIpBlock(ip) {
    if (!ip) return;
    setIpBlocksStatus("Удаляем блокировку...", "success");
    try {
      const response = await fetch(`${apiBaseUrl}/admin/system/ip-blocks/${encodeURIComponent(ip)}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${localStorage.getItem("authToken")}` },
      });
      if (response.status === 401) return handleUnauthorized();
      if (!response.ok) throw new Error(await safeReadError(response));
      const payload = await response.json();
      state.ipBlocks.items = payload.blocks || [];
      state.ipBlocks.loaded = true;
      renderIpBlocks();
      setIpBlocksStatus("IP удалён из блокировки", "success");
    } catch (error) {
      console.error(error);
      setIpBlocksStatus(error?.message || "Не удалось удалить IP", "error");
    }
  }

  async function loadSystemEvents(options = {}) {
    const { resetPage = false, silent = false } = options;
    if (resetPage) state.systemEvents.page = 1;
    if (state.systemEvents.loading) return;
    state.systemEvents.loading = true;
    toggleHidden(elements.systemEventsError, true);
    toggleHidden(elements.systemEventsEmpty, true);
    if (elements.systemEventsLoading) {
      elements.systemEventsLoading.textContent = state.systemEvents.loadedOnce ? "Обновляем события..." : "Загрузка событий...";
      const hideLoader = silent && state.systemEvents.loadedOnce;
      toggleHidden(elements.systemEventsLoading, hideLoader);
    }
    const params = new URLSearchParams();
    params.set("limit", state.systemEvents.limit);
    params.set("page", state.systemEvents.page);
    if (state.systemEvents.level) params.set("level", state.systemEvents.level);
    if (state.systemEvents.hours) params.set("hours", state.systemEvents.hours);
    try {
      const response = await fetch(`${apiBaseUrl}/admin/system/events?${params.toString()}`, {
        headers: { Authorization: `Bearer ${localStorage.getItem("authToken")}` },
      });
      if (response.status === 401) return handleUnauthorized();
      if (!response.ok) throw new Error("Request failed");
      const payload = await response.json();
      const events = payload.events || [];
      const signature = computeEventsSignature(events);
      const isFirstLoad = !state.systemEvents.loadedOnce;
      const hasChanges = signature !== state.systemEvents.lastSignature;
      state.systemEvents.total = payload.total || 0;
      state.systemEvents.loadedOnce = true;
      state.systemEvents.lastSignature = signature;
      state.systemEvents.latestEvents = events;
      if (isFirstLoad || hasChanges || !silent) {
        renderSystemEvents(events);
      }
      updateSystemEventsPagination();
      updateEventsTimestamp(isFirstLoad || hasChanges);
    } catch (error) {
      console.error(error);
      showAlert(
        elements.systemEventsError,
        "Не удалось загрузить события. Проверьте подключение или логи сервера.",
      );
    } finally {
      state.systemEvents.loading = false;
      if (elements.systemEventsLoading) toggleHidden(elements.systemEventsLoading, true);
    }
  }

  function startSystemEventsAutoRefresh() {
    if (state.systemEvents.refreshInterval) return;
    state.systemEvents.refreshInterval = window.setInterval(() => {
      void loadSystemEvents({ silent: true });
    }, 5000);
  }

  function stopSystemEventsAutoRefresh() {
    if (state.systemEvents.refreshInterval) {
      window.clearInterval(state.systemEvents.refreshInterval);
      state.systemEvents.refreshInterval = null;
    }
  }

  if (elements.logoutButton) {
    elements.logoutButton.addEventListener("click", () => {
      localStorage.removeItem("authToken");
      localStorage.removeItem("userId");
      window.location.replace("index.php");
    });
  }

  if (elements.systemEventsLevel) {
    elements.systemEventsLevel.addEventListener("change", () => {
      state.systemEvents.level = elements.systemEventsLevel.value;
      void loadSystemEvents({ resetPage: true });
    });
  }

  if (elements.systemEventsPeriod) {
    elements.systemEventsPeriod.addEventListener("change", () => {
      state.systemEvents.hours = elements.systemEventsPeriod.value;
      void loadSystemEvents({ resetPage: true });
    });
  }

  if (elements.systemEventsLimit) {
    elements.systemEventsLimit.addEventListener("change", () => {
      const value = Number(elements.systemEventsLimit.value) || 20;
      state.systemEvents.limit = value;
      void loadSystemEvents({ resetPage: true });
    });
  }

  if (elements.systemEventsShowEmpty) {
    state.systemEvents.showEmpty = Boolean(elements.systemEventsShowEmpty.checked);
    elements.systemEventsShowEmpty.addEventListener("change", () => {
      state.systemEvents.showEmpty = Boolean(elements.systemEventsShowEmpty.checked);
      renderSystemEvents(state.systemEvents.latestEvents || []);
    });
  }

  if (elements.systemEventsRefresh) {
    elements.systemEventsRefresh.addEventListener("click", () => {
      void loadSystemEvents({ resetPage: true });
    });
  }

  if (elements.systemEventsPrev) {
    elements.systemEventsPrev.addEventListener("click", () => {
      if (state.systemEvents.page > 1) {
        state.systemEvents.page -= 1;
        void loadSystemEvents();
      }
    });
  }

  if (elements.systemEventsNext) {
    elements.systemEventsNext.addEventListener("click", () => {
      const totalPages = Math.max(1, Math.ceil(state.systemEvents.total / state.systemEvents.limit));
      if (state.systemEvents.page < totalPages) {
        state.systemEvents.page += 1;
        void loadSystemEvents();
      }
    });
  }

  if (elements.systemIpBlocks) {
    elements.systemIpBlocks.addEventListener("click", () => {
      showAlert(elements.ipBlocksStatus, "");
      openDrawer("ip-blocks");
      void loadIpBlocks({ silent: state.ipBlocks.loaded });
    });
  }

  if (elements.systemEventsExclusions) {
    elements.systemEventsExclusions.addEventListener("click", () => {
      populateExclusionCategoriesSelect();
      showAlert(elements.eventExclusionsStatus, "");
      openDrawer("event-exclusions");
      void loadEventExclusions({ silent: state.systemEvents.exclusionsLoaded });
    });
  }

  if (elements.ipBlocksForm) {
    elements.ipBlocksForm.addEventListener("submit", (event) => {
      void createIpBlock(event);
    });
  }

  if (elements.ipBlocksBody) {
    elements.ipBlocksBody.addEventListener("click", (event) => {
      const target = event.target.closest("[data-action=\"delete-ip-block\"]");
      if (!target || !target.dataset.ip) return;
      void deleteIpBlock(target.dataset.ip);
    });
  }

  if (elements.eventExclusionsForm) {
    elements.eventExclusionsForm.addEventListener("submit", (event) => {
      void submitEventExclusion(event);
    });
  }

  if (elements.eventExclusionsBody) {
    elements.eventExclusionsBody.addEventListener("click", (event) => {
      const target = event.target.closest("[data-action=\"delete-exclusion\"]");
      if (!target || !target.dataset.id) return;
      void deleteEventExclusion(target.dataset.id);
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

  populateExclusionCategoriesSelect();
  startSystemEventsAutoRefresh();
  void loadSystemEvents({ resetPage: true });
})();
