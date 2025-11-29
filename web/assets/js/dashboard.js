(function () {
  const config = window.APP_CONFIG || {};
  const apiBaseUrl = (config.apiBaseUrl || window.location.origin || "http://garderobus.tech").replace(/\/$/, "");
  const pageType = document.body?.dataset.page || "users";

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
    activityNow: document.getElementById("metrics-active-now"),
    activityDay: document.getElementById("metrics-active-day"),
    activityPlatforms: document.getElementById("metrics-platforms"),
    activityError: document.getElementById("metrics-error"),
    exportCsvButton: document.getElementById("export-csv-button"),
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
    drawerCodeEditorSection: document.getElementById("drawer-code-editor"),
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
    systemStatusGrid: document.getElementById("system-status-grid"),
    systemStatusLoading: document.getElementById("system-status-loading"),
    systemStatusError: document.getElementById("system-status-error"),
    systemStatusFeedback: document.getElementById("system-status-feedback"),
    systemUptime: document.getElementById("system-uptime"),
    systemUptimeSeconds: document.getElementById("system-uptime-seconds"),
    systemAppName: document.getElementById("system-app-name"),
    systemAppVersion: document.getElementById("system-app-version"),
    systemEnvironment: document.getElementById("system-environment"),
    systemRestartState: document.getElementById("system-restart-state"),
    systemLastRestart: document.getElementById("system-last-restart"),
    systemAdminRestartState: document.getElementById("system-admin-restart-state"),
    systemAdminLastRestart: document.getElementById("system-admin-last-restart"),
    systemFilesCount: document.getElementById("system-files-count"),
    systemFilesList: document.getElementById("system-files-list"),
    systemServiceStatuses: document.getElementById("system-service-statuses"),
    systemRefreshButton: document.getElementById("system-refresh-button"),
    openCodeEditorButton: document.getElementById("open-code-editor-button"),
    maintenanceStatusPill: document.getElementById("maintenance-status-pill"),
    systemActionsToggle: document.getElementById("system-actions-toggle"),
    systemActionsList: document.getElementById("system-actions-list"),
    systemEventsWrapper: document.getElementById("system-events-wrapper"),
    systemEventsGroups: document.getElementById("system-events-groups"),
    systemEventsLoading: document.getElementById("system-events-loading"),
    systemEventsEmpty: document.getElementById("system-events-empty"),
    systemEventsError: document.getElementById("system-events-error"),
    systemEventsLevel: document.getElementById("system-events-level"),
    systemEventsPeriod: document.getElementById("system-events-period"),
    systemEventsLimit: document.getElementById("system-events-limit"),
    systemEventsRefresh: document.getElementById("system-events-refresh"),
    systemEventsUpdatedAt: document.getElementById("system-events-updated-at"),
    systemEventsShowEmpty: document.getElementById("system-events-show-empty"),
    systemEventsPrev: document.getElementById("system-events-prev"),
    systemEventsNext: document.getElementById("system-events-next"),
    systemEventsPageInfo: document.getElementById("system-events-page-info"),
    systemTabActions: document.getElementById("system-tab-actions"),
    codeEditorSelect: document.getElementById("code-editor-file-select"),
    codeEditorEmpty: document.getElementById("code-editor-empty"),
    codeEditorRefresh: document.getElementById("code-editor-refresh"),
    codeEditorContent: document.getElementById("code-editor-content"),
    codeEditorMessage: document.getElementById("code-editor-message"),
    codeEditorCancel: document.getElementById("code-editor-cancel"),
    codeEditorSave: document.getElementById("code-editor-save"),
    codeEditorStatus: document.getElementById("code-editor-status"),
    codeEditorLoading: document.getElementById("code-editor-loading"),
    queueButton: document.getElementById("queue-button"),
    queueCount: document.getElementById("queue-count"),
    queueDrawerSection: document.getElementById("drawer-queue"),
    queueList: document.getElementById("queue-list"),
    queueEmpty: document.getElementById("queue-empty"),
    queueError: document.getElementById("queue-error"),
    queueLoading: document.getElementById("queue-loading"),
    queueRefresh: document.getElementById("queue-refresh"),
    queueTotalPill: document.getElementById("queue-total-pill"),
    queueStateBadges: document.getElementById("queue-state-badges"),
    queueUpdatedAt: document.getElementById("queue-updated-at"),
    databaseSummaryBody: document.getElementById("database-summary-body"),
    databaseSummaryWrapper: document.getElementById("database-summary-wrapper"),
    databaseSummaryLoading: document.getElementById("database-summary-loading"),
    databaseSummaryError: document.getElementById("database-summary-error"),
    databaseSummaryEmpty: document.getElementById("database-summary-empty"),
    databaseRefreshButton: document.getElementById("database-refresh-button"),
    databaseTableSelect: document.getElementById("database-table-select"),
    databaseTableRefresh: document.getElementById("database-table-refresh"),
    databaseRowsWrapper: document.getElementById("database-rows-wrapper"),
    databaseRowsHead: document.getElementById("database-rows-head"),
    databaseRowsBody: document.getElementById("database-rows-body"),
    databaseRowsLoading: document.getElementById("database-rows-loading"),
    databaseRowsEmpty: document.getElementById("database-rows-empty"),
    databaseRowsError: document.getElementById("database-rows-error"),
    databaseRowsTotal: document.getElementById("database-rows-total"),
    databaseBackupButton: document.getElementById("database-backup-button"),
    databaseRestoreFile: document.getElementById("database-restore-file"),
    databaseRestoreButton: document.getElementById("database-restore-button"),
    databaseBackupStatus: document.getElementById("database-backup-status"),
  };

  const state = {
    drawerMode: null,
    activeDetailUserId: null,
    detailAbortController: null,
    systemStatus: null,
    managedFiles: [],
    activeCodeFile: null,
    systemRefreshInterval: null,
    systemLoadedOnce: false,
    systemActionInProgress: false,
    users: [],
    activityInterval: null,
    activityLoadedOnce: false,
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
    },
    queueSnapshot: null,
    queueLoadedOnce: false,
    queueLoading: false,
    databaseTables: [],
    databaseSelectedTable: "",
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
    const sections = [
      elements.drawerCreateSection,
      elements.drawerDetailSection,
      elements.drawerCodeEditorSection,
      elements.queueDrawerSection,
    ];
    sections.forEach((item) => {
      if (item) {
        toggleHidden(item, item !== section);
      }
    });
  }

  function openDrawer(mode) {
    state.drawerMode = mode;
    if (elements.drawerTitle) {
      let title = "Карточка пользователя";
      if (mode === "create") {
        title = "Создание пользователя";
      } else if (mode === "code") {
        title = "Редактор кода";
      } else if (mode === "queue") {
        title = "Очередь задач";
      }
      elements.drawerTitle.textContent = title;
    }
    setDrawerVisibility(true);
    if (mode === "create") {
      showDrawerSection(elements.drawerCreateSection);
      toggleHidden(elements.createError, true);
      toggleHidden(elements.createSuccess, true);
    } else if (mode === "code") {
      showDrawerSection(elements.drawerCodeEditorSection);
      if (elements.codeEditorStatus) {
        toggleHidden(elements.codeEditorStatus, true);
      }
    } else if (mode === "queue") {
      showDrawerSection(elements.queueDrawerSection);
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
    state.activeCodeFile = null;
    if (elements.codeEditorContent) {
      elements.codeEditorContent.value = "";
      elements.codeEditorContent.disabled = false;
    }
    if (elements.codeEditorMessage) {
      elements.codeEditorMessage.value = "";
    }
    if (elements.codeEditorStatus) {
      elements.codeEditorStatus.classList.remove("success");
      toggleHidden(elements.codeEditorStatus, true);
    }
    if (elements.codeEditorLoading) {
      toggleHidden(elements.codeEditorLoading, true);
    }
    if (elements.codeEditorEmpty) {
      toggleHidden(elements.codeEditorEmpty, true);
    }
    if (elements.codeEditorSave) {
      elements.codeEditorSave.disabled = false;
    }
    if (elements.codeEditorRefresh) {
      elements.codeEditorRefresh.disabled = false;
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

  function showAlert(element, message, type = "error") {
    if (!element) {
      return;
    }
    if (!message) {
      element.textContent = "";
      element.classList.remove("success");
      element.classList.add("hidden");
      return;
    }
    element.textContent = message;
    element.classList.remove("hidden");
    if (type === "success") {
      element.classList.add("success");
    } else {
      element.classList.remove("success");
    }
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

  function setText(element, value) {
    if (element) {
      element.textContent = value;
    }
  }

  function setMaintenanceState(enabled) {
    if (!elements.maintenanceStatusPill) {
      return;
    }
    elements.maintenanceStatusPill.textContent = enabled
      ? "Maintenance: включен"
      : "Maintenance: выключен";
    elements.maintenanceStatusPill.classList.toggle("danger", enabled);
    elements.maintenanceStatusPill.classList.toggle("success", !enabled);
  }

  function setSystemActionBusy(isBusy, label = "Выполнение...") {
    state.systemActionInProgress = isBusy;
    if (elements.systemActionsToggle) {
      if (isBusy) {
        if (!elements.systemActionsToggle.dataset.originalHtml) {
          elements.systemActionsToggle.dataset.originalHtml =
            elements.systemActionsToggle.innerHTML;
        }
        elements.systemActionsToggle.innerHTML = `<span class="spinner"></span>${label}`;
      } else if (elements.systemActionsToggle.dataset.originalHtml) {
        elements.systemActionsToggle.innerHTML =
          elements.systemActionsToggle.dataset.originalHtml;
        delete elements.systemActionsToggle.dataset.originalHtml;
      }
      elements.systemActionsToggle.disabled = isBusy;
      elements.systemActionsToggle.classList.toggle("loading", isBusy);
      elements.systemActionsToggle.dataset.loadingLabel = label;
    }
    if (elements.systemActionsList) {
      elements.systemActionsList
        .querySelectorAll("button")
        .forEach((button) => {
          button.disabled = isBusy;
        });
    }
  }

  function setQueueButtonBusy(isBusy) {
    if (!elements.queueButton) {
      return;
    }
    elements.queueButton.disabled = isBusy;
    elements.queueButton.classList.toggle("loading", isBusy);
  }

  function formatQueueState(state) {
    const map = {
      active: "В работе",
      reserved: "В очереди",
      scheduled: "Запланировано",
    };
    return map[state] || state;
  }

  function updateQueueButtonCount(total) {
    if (!elements.queueCount) {
      return;
    }
    elements.queueCount.textContent = typeof total === "number" ? total : "—";
    elements.queueCount.classList.toggle("danger", Number(total) > 0);
  }

  function renderQueueStateBadges(byState) {
    if (!elements.queueStateBadges) {
      return;
    }
    elements.queueStateBadges.innerHTML = "";
    const entries = Object.entries(byState || {});
    if (!entries.length) {
      const badge = document.createElement("span");
      badge.className = "badge";
      badge.textContent = "Нет данных";
      elements.queueStateBadges.appendChild(badge);
      return;
    }
    entries
      .sort((a, b) => a[0].localeCompare(b[0]))
      .forEach(([state, count]) => {
        const badge = document.createElement("span");
        badge.className = "badge";
        badge.textContent = `${formatQueueState(state)}: ${count}`;
        elements.queueStateBadges.appendChild(badge);
      });
  }

  function renderQueueList(tasks) {
    if (!elements.queueList) {
      return;
    }
    elements.queueList.innerHTML = "";

    const items = Array.isArray(tasks) ? [...tasks] : [];
    const stateOrder = { active: 0, reserved: 1, scheduled: 2 };
    items.sort((a, b) => {
      const aOrder = stateOrder[a.state] ?? 99;
      const bOrder = stateOrder[b.state] ?? 99;
      if (aOrder !== bOrder) return aOrder - bOrder;
      return (a.eta || "").localeCompare(b.eta || "");
    });

    if (!items.length) {
      toggleHidden(elements.queueEmpty, false);
      return;
    }
    toggleHidden(elements.queueEmpty, true);

    items.forEach((task) => {
      const details = document.createElement("details");
      details.className = "queue-item";

      const summary = document.createElement("summary");
      summary.className = "queue-item-header";

      const title = document.createElement("div");
      title.className = "queue-item-title";

      const name = document.createElement("strong");
      name.textContent = task.name || "Задача";
      title.appendChild(name);

      const idSpan = document.createElement("span");
      idSpan.className = "text-muted";
      idSpan.textContent = `ID: ${task.id}`;
      title.appendChild(idSpan);

      const meta = document.createElement("div");
      meta.className = "queue-item-meta";
      const stateMeta = document.createElement("span");
      stateMeta.textContent = formatQueueState(task.state || "") || "Статус";
      meta.appendChild(stateMeta);

      if (task.queue) {
        const queueMeta = document.createElement("span");
        queueMeta.textContent = `Очередь: ${task.queue}`;
        meta.appendChild(queueMeta);
      }

      if (task.worker) {
        const workerMeta = document.createElement("span");
        workerMeta.textContent = `Воркер: ${task.worker}`;
        meta.appendChild(workerMeta);
      }

      if (task.eta) {
        const etaMeta = document.createElement("span");
        etaMeta.textContent = `ETA: ${formatDate(task.eta, true)}`;
        meta.appendChild(etaMeta);
      }

      summary.appendChild(title);
      summary.appendChild(meta);
      details.appendChild(summary);

      const body = document.createElement("div");
      body.className = "queue-item-details";

      const argsLabel = document.createElement("div");
      argsLabel.className = "text-muted";
      argsLabel.textContent = "Аргументы";
      const argsPre = document.createElement("pre");
      argsPre.className = "queue-args";
      argsPre.textContent = task.args || "—";

      const kwargsLabel = document.createElement("div");
      kwargsLabel.className = "text-muted";
      kwargsLabel.style.marginTop = "8px";
      kwargsLabel.textContent = "Параметры";
      const kwargsPre = document.createElement("pre");
      kwargsPre.className = "queue-args";
      kwargsPre.textContent = task.kwargs || "—";

      body.appendChild(argsLabel);
      body.appendChild(argsPre);
      body.appendChild(kwargsLabel);
      body.appendChild(kwargsPre);

      details.appendChild(body);
      elements.queueList.appendChild(details);
    });
  }

  function renderQueueSnapshot(snapshot) {
    const total = snapshot?.total ?? 0;
    updateQueueButtonCount(total);

    if (elements.queueTotalPill) {
      elements.queueTotalPill.textContent = `Всего: ${total}`;
      elements.queueTotalPill.classList.toggle("success", total === 0);
      elements.queueTotalPill.classList.toggle("danger", total > 0);
    }

    renderQueueStateBadges(snapshot?.by_state || {});
    renderQueueList(snapshot?.tasks || []);

    if (elements.queueUpdatedAt) {
      elements.queueUpdatedAt.textContent = `Обновлено: ${new Date().toLocaleString("ru-RU")}`;
    }

    if (elements.queueLoading) {
      toggleHidden(elements.queueLoading, true);
    }
  }

  async function loadQueueSnapshot({ showLoader = true, silent = false } = {}) {
    if (!elements.queueDrawerSection) {
      return;
    }
    state.queueLoading = true;
    setQueueButtonBusy(showLoader && !silent);
    toggleHidden(elements.queueEmpty, true);
    showAlert(elements.queueError, "");
    if (elements.queueList) {
      elements.queueList.innerHTML = "";
    }
    if (elements.queueLoading) {
      elements.queueLoading.textContent = "Загрузка очереди...";
      toggleHidden(elements.queueLoading, !showLoader);
    }

    try {
      const response = await fetch(`${apiBaseUrl}/admin/system/queue`, {
        headers: {
          Authorization: `Bearer ${localStorage.getItem("authToken")}`,
        },
      });

      if (response.status === 401) {
        handleUnauthorized();
        return;
      }

      if (!response.ok) {
        throw new Error(`Queue request failed with status ${response.status}`);
      }

      const payload = await response.json();
      state.queueSnapshot = payload;
      state.queueLoadedOnce = true;
      renderQueueSnapshot(payload);
    } catch (error) {
      console.error(error);
      showAlert(elements.queueError, "Не удалось загрузить очередь. Попробуйте позже.");
    } finally {
      setQueueButtonBusy(false);
      state.queueLoading = false;
      if (elements.queueLoading) {
        toggleHidden(elements.queueLoading, true);
      }
    }
  }

  async function fetchDatabaseSummary() {
    const response = await fetch(`${apiBaseUrl}/admin/database/summary`, {
      headers: {
        Authorization: `Bearer ${localStorage.getItem("authToken")}`,
      },
    });

    if (response.status === 401) {
      handleUnauthorized();
      return null;
    }

    if (!response.ok) {
      const message = await safeReadError(response);
      throw new Error(`Database summary failed (${response.status}): ${message}`);
    }

    return response.json();
  }

  function renderDatabaseSummary(tables) {
    if (!elements.databaseSummaryBody) {
      return;
    }

    elements.databaseSummaryBody.innerHTML = "";
    tables.forEach((table) => {
      const row = document.createElement("tr");
      const nameCell = document.createElement("td");
      nameCell.textContent = table.name;

      const columnsCell = document.createElement("td");
      columnsCell.textContent = (table.columns || []).join(", ") || "—";

      const countCell = document.createElement("td");
      countCell.textContent = table.row_count ?? "0";

      row.appendChild(nameCell);
      row.appendChild(columnsCell);
      row.appendChild(countCell);
      elements.databaseSummaryBody.appendChild(row);
    });
  }

  function updateDatabaseTableSelect(tables) {
    if (!elements.databaseTableSelect) {
      return;
    }

    elements.databaseTableSelect.innerHTML = "";

    tables.forEach((table) => {
      const option = document.createElement("option");
      option.value = table.name;
      option.textContent = `${table.name} (${table.row_count ?? 0})`;
      elements.databaseTableSelect.appendChild(option);
    });

    if (!state.databaseSelectedTable && tables.length > 0) {
      state.databaseSelectedTable = tables[0].name;
    }

    if (state.databaseSelectedTable) {
      elements.databaseTableSelect.value = state.databaseSelectedTable;
    }
  }

  async function loadDatabaseSummary({ showLoader = false } = {}) {
    if (!elements.databaseSummaryLoading) {
      return;
    }

    showAlert(elements.databaseSummaryError, "");
    toggleHidden(elements.databaseSummaryEmpty, true);
    toggleHidden(elements.databaseSummaryWrapper, true);
    if (showLoader) {
      elements.databaseSummaryLoading.textContent = "Загрузка таблиц...";
      toggleHidden(elements.databaseSummaryLoading, false);
    }

    try {
      const payload = await fetchDatabaseSummary();
      if (!payload) {
        return;
      }

      const tables = Array.isArray(payload.tables) ? payload.tables : [];
      state.databaseTables = tables;
      renderDatabaseSummary(tables);
      updateDatabaseTableSelect(tables);

      toggleHidden(elements.databaseSummaryWrapper, tables.length === 0);
      toggleHidden(elements.databaseSummaryEmpty, tables.length !== 0);

      if (state.databaseSelectedTable && tables.length > 0) {
        await loadDatabaseTable({ showLoader: true });
      }
    } catch (error) {
      console.error(error);
      showAlert(
        elements.databaseSummaryError,
        error?.message || "Не удалось загрузить список таблиц.",
      );
    } finally {
      if (elements.databaseSummaryLoading) {
        toggleHidden(elements.databaseSummaryLoading, true);
      }
    }
  }

  function formatDatabaseCellValue(value) {
    if (value === null || value === undefined) {
      return "—";
    }
    if (typeof value === "object") {
      try {
        return JSON.stringify(value);
      } catch (error) {
        console.error("Failed to stringify value", error);
        return String(value);
      }
    }
    return String(value);
  }

  function renderDatabaseRows(tableData) {
    if (!elements.databaseRowsHead || !elements.databaseRowsBody) {
      return;
    }

    elements.databaseRowsHead.innerHTML = "";
    elements.databaseRowsBody.innerHTML = "";

    const columns = tableData.columns || [];
    columns.forEach((column) => {
      const th = document.createElement("th");
      th.textContent = column;
      elements.databaseRowsHead.appendChild(th);
    });

    tableData.rows.forEach((row) => {
      const tr = document.createElement("tr");
      columns.forEach((column) => {
        const td = document.createElement("td");
        const fullValue = formatDatabaseCellValue(row[column]);
        const shouldTruncate = fullValue.length > 180;
        const displayValue = shouldTruncate ? `${fullValue.slice(0, 180)}…` : fullValue;
        td.textContent = displayValue;
        if (shouldTruncate) {
          td.title = fullValue;
        }
        tr.appendChild(td);
      });
      elements.databaseRowsBody.appendChild(tr);
    });
  }

  async function loadDatabaseTable({ showLoader = false } = {}) {
    if (!elements.databaseRowsLoading) {
      return;
    }

    if (!state.databaseSelectedTable) {
      elements.databaseRowsLoading.textContent = "Выберите таблицу для просмотра.";
      toggleHidden(elements.databaseRowsLoading, false);
      toggleHidden(elements.databaseRowsWrapper, true);
      toggleHidden(elements.databaseRowsEmpty, true);
      showAlert(elements.databaseRowsError, "");
      return;
    }

    showAlert(elements.databaseRowsError, "");
    toggleHidden(elements.databaseRowsEmpty, true);
    toggleHidden(elements.databaseRowsWrapper, true);
    if (showLoader) {
      elements.databaseRowsLoading.textContent = "Загрузка данных таблицы...";
      toggleHidden(elements.databaseRowsLoading, false);
    }

    try {
      const params = new URLSearchParams({ table: state.databaseSelectedTable, limit: "200" });
      const response = await fetch(`${apiBaseUrl}/admin/database/table?${params.toString()}`, {
        headers: {
          Authorization: `Bearer ${localStorage.getItem("authToken")}`,
        },
      });

      if (response.status === 401) {
        handleUnauthorized();
        return;
      }

      if (!response.ok) {
        const message = await safeReadError(response);
        throw new Error(`Table fetch failed (${response.status}): ${message}`);
      }

      const payload = await response.json();
      renderDatabaseRows(payload);

      toggleHidden(elements.databaseRowsWrapper, false);
      toggleHidden(elements.databaseRowsEmpty, payload.rows.length !== 0);
      if (elements.databaseRowsTotal) {
        elements.databaseRowsTotal.textContent = `Всего записей: ${payload.total ?? 0}`;
      }
    } catch (error) {
      console.error(error);
      showAlert(
        elements.databaseRowsError,
        error?.message || "Не удалось загрузить данные таблицы.",
      );
    } finally {
      if (elements.databaseRowsLoading) {
        toggleHidden(elements.databaseRowsLoading, true);
      }
    }
  }

  async function downloadDatabaseBackup() {
    if (elements.databaseBackupButton) {
      elements.databaseBackupButton.disabled = true;
    }
    showAlert(elements.databaseBackupStatus, "");

    try {
      const response = await fetch(`${apiBaseUrl}/admin/database/backup`, {
        headers: {
          Authorization: `Bearer ${localStorage.getItem("authToken")}`,
        },
      });

      if (response.status === 401) {
        handleUnauthorized();
        return;
      }

      if (!response.ok) {
        const message = await safeReadError(response);
        throw new Error(
          message ? `Не удалось создать бэкап: ${message}` : `Backup failed with status ${response.status}`,
        );
      }

      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = "database-backup.json";
      document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
      URL.revokeObjectURL(url);

      showAlert(elements.databaseBackupStatus, "Бэкап успешно скачан.", "success");
    } catch (error) {
      console.error(error);
      showAlert(
        elements.databaseBackupStatus,
        error?.message || "Не удалось создать бэкап базы данных.",
      );
    } finally {
      if (elements.databaseBackupButton) {
        elements.databaseBackupButton.disabled = false;
      }
    }
  }

  async function restoreDatabaseBackup() {
    if (!elements.databaseRestoreFile || !elements.databaseRestoreButton) {
      return;
    }

    if (!elements.databaseRestoreFile.files || elements.databaseRestoreFile.files.length === 0) {
      showAlert(elements.databaseBackupStatus, "Выберите JSON-файл с бэкапом для восстановления.");
      return;
    }

    const formData = new FormData();
    formData.append("file", elements.databaseRestoreFile.files[0]);

    elements.databaseRestoreButton.disabled = true;
    showAlert(elements.databaseBackupStatus, "");

    try {
      const response = await fetch(`${apiBaseUrl}/admin/database/restore`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${localStorage.getItem("authToken")}`,
        },
        body: formData,
      });

      if (response.status === 401) {
        handleUnauthorized();
        return;
      }

      if (!response.ok) {
        const rawMessage = await safeReadError(response);
        const message = rawMessage || `Восстановление завершилось с ошибкой ${response.status}`;
        throw new Error(message);
      }

      showAlert(elements.databaseBackupStatus, "База данных успешно восстановлена.", "success");
      await loadDatabaseSummary({ showLoader: false });
      await loadDatabaseTable({ showLoader: true });
    } catch (error) {
      console.error(error);
      showAlert(elements.databaseBackupStatus, error.message || "Не удалось восстановить базу данных.");
    } finally {
      elements.databaseRestoreButton.disabled = false;
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

  function formatEventLevel(level) {
    const normalized = (level || "info").toLowerCase();
    const map = {
      info: "Инфо",
      warning: "Внимание",
      error: "Ошибка",
    };
    return map[normalized] || normalized;
  }

  function formatEventMessage(event) {
    if (!event) {
      return "—";
    }

    return event.message || "—";
  }

  const EVENT_CATEGORY_ORDER = [
    "application",
    "api",
    "database",
    "xray",
    "workers",
    "other",
  ];

  const EVENT_CATEGORY_LABELS = {
    application: "Приложение",
    api: "API",
    database: "База данных",
    xray: "VPN / Xray",
    workers: "Очереди и воркеры",
    other: "Прочее",
  };

  const EVENT_CATEGORY_HINTS = {
    application: "Бизнес-логика, фоновые операции и внутренние сервисы.",
    api: "HTTP-запросы, REST-эндпоинты и ошибки FastAPI/Uvicorn.",
    database: "Подключения к БД, запросы и миграции.",
    xray: "VPN/Xray-тоннель и прокси-доступ к внешним API.",
    workers: "Очереди Celery и фоновые задания.",
    other: "Логи без явной категории.",
  };

  function normalizeEventCategory(category) {
    const normalized = String(category || "").toLowerCase();
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

    if (hasAny(["xray", "vpn", "socks"])) {
      return "xray";
    }
    if (hasAny(["db", "database", "postgres", "psql", "sqlalchemy", "mysql", "sqlite"])) {
      return "database";
    }
    if (hasAny(["uvicorn", "fastapi", "api", "http", "request", "endpoint"])) {
      return "api";
    }
    if (hasAny(["celery", "worker", "queue", "task"])) {
      return "workers";
    }
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
    const levelClass =
      event.level === "error"
        ? "error"
        : event.level === "warning"
          ? "warning"
          : "info";
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
      const messageSecondary = document.createElement("div");
      messageSecondary.className = "event-message-secondary text-muted";
      messageSecondary.textContent = categoryLabel;
      messageCell.appendChild(messageSecondary);
    }

    const detailParts = buildEventDetails(event);
    if (detailParts.length) {
      const meta = document.createElement("div");
      meta.className = "event-meta-list";
      detailParts.forEach((part) => {
        const item = document.createElement("div");
        item.className = "event-meta-item";

        const label = document.createElement("span");
        label.className = "event-meta-label";
        label.textContent = part.label;

        const value = document.createElement("span");
        value.className = "event-meta-value";
        value.textContent = part.value;

        item.appendChild(label);
        item.appendChild(value);
        meta.appendChild(item);
      });
      messageCell.appendChild(meta);
    }
    row.appendChild(messageCell);

    const sourceCell = document.createElement("td");
    const parts = [event.service, event.logger].filter(Boolean);
    const source = parts.join(" · ") || "—";
    const sourceChip = document.createElement("span");
    sourceChip.className = "event-message-chip";
    const sourceLabel = document.createElement("strong");
    sourceLabel.textContent = "Источник";
    sourceChip.appendChild(sourceLabel);
    sourceChip.appendChild(document.createTextNode(` ${source}`));
    sourceCell.appendChild(sourceChip);
    row.appendChild(sourceCell);

    return row;
  }

  function buildEventDetails(event) {
    if (!event) {
      return [];
    }

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

    if (context.request_id) {
      details.push({ label: "Request ID", value: context.request_id });
    }

    return details.filter(Boolean);
  }

  function renderSystemEvents(events) {
    if (!elements.systemEventsGroups) {
      return;
    }

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
      if (!bucket.length && !showEmpty) {
        return;
      }

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
    if (!events || !events.length) {
      return "";
    }

    return events
      .slice(0, 20)
      .map((event) => {
        const requestId = event.context?.request_id || event.request_id || "";
        return [event.timestamp || "", event.level || "", event.message || "", requestId].join("|");
      })
      .join(";");
  }

  function updateSystemEventsPagination() {
    if (!elements.systemEventsPageInfo) {
      return;
    }
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

  function updateEventsTimestamp(hasChanges = false) {
    if (!elements.systemEventsUpdatedAt) {
      return;
    }
    const timestamp = formatDate(new Date(), true);
    const suffix = hasChanges ? " · новые записи" : "";
    elements.systemEventsUpdatedAt.textContent = `Обновлено ${timestamp}${suffix}`;
    elements.systemEventsUpdatedAt.classList.toggle("highlight", hasChanges);
    if (hasChanges) {
      window.setTimeout(() => {
        elements.systemEventsUpdatedAt?.classList.remove("highlight");
      }, 1500);
    }
  }

  async function loadSystemEvents(options = {}) {
    const { resetPage = false, silent = false } = options;
    if (resetPage) {
      state.systemEvents.page = 1;
    }

    if (state.systemEvents.loading) {
      return;
    }

    state.systemEvents.loading = true;

    toggleHidden(elements.systemEventsError, true);
    toggleHidden(elements.systemEventsEmpty, true);
    if (elements.systemEventsLoading) {
      elements.systemEventsLoading.textContent = state.systemEvents.loadedOnce
        ? "Обновляем события..."
        : "Загрузка событий...";
      const hideLoader = silent && state.systemEvents.loadedOnce;
      toggleHidden(elements.systemEventsLoading, hideLoader);
    }

    const params = new URLSearchParams();
    params.set("limit", state.systemEvents.limit);
    params.set("page", state.systemEvents.page);
    if (state.systemEvents.level) {
      params.set("level", state.systemEvents.level);
    }
    if (state.systemEvents.hours) {
      params.set("hours", state.systemEvents.hours);
    }

    try {
      const response = await fetch(`${apiBaseUrl}/admin/system/events?${params.toString()}`, {
        headers: { Authorization: `Bearer ${localStorage.getItem("authToken")}` },
      });
      if (response.status === 401) {
        handleUnauthorized();
        return;
      }
      if (!response.ok) {
        throw new Error("Request failed");
      }
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
      if (elements.systemEventsLoading) {
        toggleHidden(elements.systemEventsLoading, true);
      }
    }
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
    const badge = document.createElement("button");
    badge.type = "button";
    badge.className =
      "status-badge " + (count > 0 ? "warning queue-badge-trigger" : "success");
    badge.textContent = count > 0 ? `${count} в очереди` : "Очередь пуста";

    if (count > 0 && elements.queueDrawerSection) {
      badge.title = "Посмотреть очередь задач";
      badge.addEventListener("click", () => {
        openDrawer("queue");
        void loadQueueSnapshot({ showLoader: true });
      });
    }

    return badge;
  }

  function renderManagedFiles(files) {
    if (!elements.systemFilesList) {
      return;
    }
    elements.systemFilesList.innerHTML = "";
    if (!files || !files.length) {
      const empty = document.createElement("span");
      empty.className = "text-muted";
      empty.textContent = "Нет файлов";
      elements.systemFilesList.appendChild(empty);
      return;
    }
    files.forEach((file) => {
      const badge = document.createElement("span");
      badge.className = "badge";
      badge.textContent = file;
      elements.systemFilesList.appendChild(badge);
    });
  }

  function buildFileUrl(path) {
    return path
      .split("/")
      .map((segment) => encodeURIComponent(segment))
      .join("/");
  }

  function setCodeEditorEnabled(enabled) {
    const disabled = !enabled;
    if (elements.codeEditorContent) {
      elements.codeEditorContent.disabled = disabled;
    }
    if (elements.codeEditorMessage) {
      elements.codeEditorMessage.disabled = disabled;
    }
    if (elements.codeEditorSave) {
      elements.codeEditorSave.disabled = disabled;
    }
    if (elements.codeEditorRefresh) {
      elements.codeEditorRefresh.disabled = disabled;
    }
  }

  function updateCodeEditorFileList(files) {
    if (!elements.codeEditorSelect) {
      return;
    }
    elements.codeEditorSelect.innerHTML = "";
    if (!files || !files.length) {
      elements.codeEditorSelect.disabled = true;
      setCodeEditorEnabled(false);
      if (elements.codeEditorContent) {
        elements.codeEditorContent.value = "";
      }
      toggleHidden(elements.codeEditorEmpty, false);
      return;
    }
    toggleHidden(elements.codeEditorEmpty, true);
    elements.codeEditorSelect.disabled = false;
    files.forEach((file) => {
      const option = document.createElement("option");
      option.value = file;
      option.textContent = file;
      elements.codeEditorSelect.appendChild(option);
    });
    setCodeEditorEnabled(true);
  }

  function getServiceStatusMeta(status) {
    const normalized = (status || "").toLowerCase();
    if (normalized === "warning") {
      return { label: "Warning", badge: "warning", dot: "warning" };
    }
    if (normalized === "fail" || normalized === "error") {
      return { label: "Fail", badge: "error", dot: "fail" };
    }
    return { label: "OK", badge: "success", dot: "ok" };
  }

  function renderServiceStatuses(services) {
    if (!elements.systemServiceStatuses) {
      return;
    }
    elements.systemServiceStatuses.innerHTML = "";
    const items = Array.isArray(services) ? services : [];
    if (!items.length) {
      const empty = document.createElement("span");
      empty.className = "text-muted";
      empty.textContent = "Нет данных о сервисах";
      elements.systemServiceStatuses.appendChild(empty);
      return;
    }

    items.forEach((service) => {
      const meta = getServiceStatusMeta(service.status);
      const wrapper = document.createElement("div");
      wrapper.className = "service-status-item";

      const topRow = document.createElement("div");
      topRow.className = "service-status-top";
      const info = document.createElement("div");
      info.className = "service-status-info";

      const dot = document.createElement("span");
      dot.className = `status-dot ${meta.dot}`;

      const name = document.createElement("strong");
      name.textContent = service.name || "Сервис";

      info.appendChild(dot);
      info.appendChild(name);

      const badge = document.createElement("span");
      badge.className = `status-badge ${meta.badge}`;
      badge.textContent = meta.label;

      topRow.appendChild(info);
      topRow.appendChild(badge);

      const message = document.createElement("span");
      message.className = "text-muted";
      message.textContent = service.message || "Работает стабильно";

      wrapper.appendChild(topRow);
      wrapper.appendChild(message);
      elements.systemServiceStatuses.appendChild(wrapper);
    });
  }

  function updateSystemStatus(status) {
    if (!status) {
      return;
    }
    state.systemLoadedOnce = true;
    state.systemStatus = status;
    const files = Array.isArray(status.managed_files) ? status.managed_files : [];
    state.managedFiles = files;
    if (elements.systemStatusGrid) {
      toggleHidden(elements.systemStatusGrid, false);
    }
    setText(elements.systemUptime, status.uptime_human || "—");
    setText(
      elements.systemUptimeSeconds,
      Math.round(Number(status.uptime_seconds ?? 0))
    );
    setText(elements.systemAppName, status.app_name || "—");
    setText(elements.systemAppVersion, status.app_version || "—");
    setText(elements.systemEnvironment, status.environment || "—");
    setText(
      elements.systemRestartState,
      status.restart_supported ? "Доступно" : "Недоступно"
    );
    setText(
      elements.systemLastRestart,
      status.last_restart_requested_at
        ? formatDate(status.last_restart_requested_at, true)
        : "—"
    );
    setText(
      elements.systemAdminRestartState,
      status.admin_restart_supported ? "Доступно" : "Недоступно"
    );
    setText(
      elements.systemAdminLastRestart,
      status.last_admin_restart_requested_at
        ? formatDate(status.last_admin_restart_requested_at, true)
        : "—"
    );
    setMaintenanceState(Boolean(status.maintenance_enabled));
    setText(elements.systemFilesCount, files.length);
    renderManagedFiles(files);
    renderServiceStatuses(status.services || status.service_statuses);
    if (state.drawerMode === "code") {
      updateCodeEditorFileList(files);
    }
    updateSystemActionsAvailability(status);
  }

  function updateSystemActionsAvailability(status = {}) {
    if (!elements.systemActionsList) {
      return;
    }
    const disableButton = (action, reason = "") => {
      const button = elements.systemActionsList.querySelector(
        `[data-action="${action}"]`
      );
      if (button) {
        button.disabled = true;
        button.title = reason;
        button.classList.add("muted");
      }
    };

    elements.systemActionsList.querySelectorAll("[data-action]").forEach((btn) => {
      btn.disabled = false;
      btn.title = "";
      btn.classList.remove("muted");
    });

    if (!status.restart_supported) {
      disableButton("restart-api", "Перезапуск недоступен для окружения");
    }
    if (!status.worker_restart_supported) {
      disableButton("restart-workers", "Нет команды перезапуска воркеров");
    }
    if (!status.admin_restart_supported) {
      disableButton("restart-admin", "Перезапуск админ-сервиса не настроен");
    }
    if (!status.maintenance_supported) {
      disableButton("enable-maintenance", "Maintenance не настроен");
      disableButton("disable-maintenance", "Maintenance не настроен");
    } else if (status.maintenance_enabled) {
      disableButton("enable-maintenance", "Уже включен");
    } else {
      disableButton("disable-maintenance", "Уже выключен");
    }
    if (!status.test_webhook_configured) {
      disableButton("send-test-webhook", "Webhook не настроен");
    }

    if (state.systemActionInProgress) {
      setSystemActionBusy(true, elements.systemActionsToggle?.dataset.loadingLabel);
    }
  }

  const SYSTEM_ACTIONS = {
    "restart-api": {
      url: "/admin/system/restart",
      confirm:
        "Перезапустить API сейчас? Активные соединения будут прерваны.",
      loadingLabel: "Перезапуск...",
      successMessage: "Перезапуск API инициирован.",
    },
    "restart-admin": {
      url: "/admin/system/admin/restart",
      confirm:
        "Перезапустить админ-сервис сейчас? Вы выйдете из панели при завершении процесса.",
      loadingLabel: "Перезапуск админ-сервиса...",
      successMessage: "Перезапуск админ-сервиса инициирован.",
    },
    "restart-workers": {
      url: "/admin/system/workers/restart",
      confirm:
        "Перезапустить фоновых воркеров? Текущие задачи могут быть перезапущены.",
      loadingLabel: "Перезапуск воркеров...",
      successMessage: "Перезапуск воркеров инициирован.",
    },
    "enable-maintenance": {
      url: "/admin/system/maintenance",
      confirm:
        "Включить maintenance режим? Пользовательский доступ будет ограничен.",
      loadingLabel: "Включение maintenance...",
      successMessage: "Maintenance режим включен.",
      body: { enabled: true },
    },
    "disable-maintenance": {
      url: "/admin/system/maintenance",
      confirm: "Выключить maintenance режим и вернуть доступ пользователям?",
      loadingLabel: "Выключение maintenance...",
      successMessage: "Maintenance режим выключен.",
      body: { enabled: false },
    },
    "send-test-webhook": {
      url: "/admin/system/test-webhook",
      confirm: "Отправить тестовый webhook/ping?",
      loadingLabel: "Отправка webhook...",
      successMessage: "Тестовый webhook отправлен.",
    },
  };

  function closeSystemActionsMenu() {
    if (elements.systemActionsList) {
      elements.systemActionsList.classList.add("hidden");
    }
    if (elements.systemActionsToggle) {
      elements.systemActionsToggle.setAttribute("aria-expanded", "false");
    }
  }

  function toggleSystemActionsMenu() {
    if (!elements.systemActionsList) {
      return;
    }
    const isOpen = !elements.systemActionsList.classList.contains("hidden");
    if (isOpen) {
      closeSystemActionsMenu();
    } else {
      elements.systemActionsList.classList.remove("hidden");
      if (elements.systemActionsToggle) {
        elements.systemActionsToggle.setAttribute("aria-expanded", "true");
      }
    }
  }

  async function performSystemAction(actionKey) {
    const action = SYSTEM_ACTIONS[actionKey];
    if (!action || state.systemActionInProgress) {
      return;
    }
    if (action.confirm && !window.confirm(action.confirm)) {
      closeSystemActionsMenu();
      return;
    }
    showAlert(elements.systemStatusError, "");
    showAlert(elements.systemStatusFeedback, "");
    setSystemActionBusy(true, action.loadingLabel || "Выполнение...");
    closeSystemActionsMenu();
    try {
      const response = await fetch(`${apiBaseUrl}${action.url}`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${localStorage.getItem("authToken")}`,
          "Content-Type": "application/json",
        },
        body: action.body ? JSON.stringify(action.body) : undefined,
      });
      if (response.status === 401) {
        handleUnauthorized();
        return;
      }
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        const errorMessage = payload?.detail || payload?.error || "Произошла ошибка";
        throw new Error(errorMessage);
      }
      showAlert(
        elements.systemStatusFeedback,
        payload?.detail || action.successMessage || "Успешно выполнено.",
        "success"
      );
      void refreshSystemMetrics({ showLoader: false, silent: true });
    } catch (error) {
      console.error(error);
      showAlert(
        elements.systemStatusError,
        error?.message || "Не удалось выполнить действие. Попробуйте позже."
      );
    } finally {
      setSystemActionBusy(false);
    }
  }

  async function fetchSystemMetrics(options = {}) {
    const { showLoader = true, silent = false } = options;
    if (showLoader && elements.systemStatusLoading) {
      elements.systemStatusLoading.textContent = "Загрузка состояния сервиса...";
      toggleHidden(elements.systemStatusLoading, false);
    }
    if (!silent) {
      showAlert(elements.systemStatusError, "");
      showAlert(elements.systemStatusFeedback, "");
    }
    try {
      const response = await fetch(`${apiBaseUrl}/admin/system/status`, {
        headers: {
          Authorization: `Bearer ${localStorage.getItem("authToken")}`,
        },
      });
      if (response.status === 401) {
        handleUnauthorized();
        return null;
      }
      if (!response.ok) {
        throw new Error("Request failed");
      }
      const data = await response.json();
      return data;
    } catch (error) {
      console.error(error);
      if (!silent) {
        showAlert(
          elements.systemStatusError,
          "Не удалось загрузить состояние сервиса."
        );
      }
      return null;
    } finally {
      if (elements.systemStatusLoading) {
        toggleHidden(elements.systemStatusLoading, true);
      }
    }
  }

  async function refreshSystemMetrics(options = {}) {
    const data = await fetchSystemMetrics(options);
    if (data) {
      updateSystemStatus(data);
    }
    return data;
  }

  function startSystemAutoRefresh() {
    if (!state.systemLoadedOnce) {
      void refreshSystemMetrics({ showLoader: true });
    }
    if (state.systemRefreshInterval) {
      return;
    }
    state.systemRefreshInterval = window.setInterval(() => {
      void refreshSystemMetrics({ showLoader: false, silent: true });
    }, 30000);
  }

  function stopSystemAutoRefresh() {
    if (state.systemRefreshInterval) {
      window.clearInterval(state.systemRefreshInterval);
      state.systemRefreshInterval = null;
    }
  }

  function startSystemEventsAutoRefresh() {
    if (state.systemEvents.refreshInterval) {
      return;
    }

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

  async function loadCodeFile(path) {
    if (!path) {
      setCodeEditorEnabled(false);
      return null;
    }
    showAlert(elements.codeEditorStatus, "");
    if (elements.codeEditorLoading) {
      elements.codeEditorLoading.textContent = "Загрузка файла...";
      toggleHidden(elements.codeEditorLoading, false);
    }
    try {
      const encoded = buildFileUrl(path);
      const response = await fetch(`${apiBaseUrl}/admin/system/files/${encoded}`, {
        headers: {
          Authorization: `Bearer ${localStorage.getItem("authToken")}`,
        },
      });
      if (response.status === 401) {
        handleUnauthorized();
        return null;
      }
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        const reason = payload?.detail || payload?.error || "Не удалось загрузить файл.";
        throw new Error(reason);
      }
      const data = payload;
      state.activeCodeFile = data.path || path;
      if (elements.codeEditorSelect) {
        elements.codeEditorSelect.value = state.activeCodeFile;
      }
      if (elements.codeEditorContent) {
        elements.codeEditorContent.value = data.content ?? "";
      }
      return data;
    } catch (error) {
      console.error(error);
      showAlert(
        elements.codeEditorStatus,
        error?.message || "Не удалось загрузить файл. Попробуйте позже."
      );
      return null;
    } finally {
      if (elements.codeEditorLoading) {
        toggleHidden(elements.codeEditorLoading, true);
      }
    }
  }

  async function prepareCodeEditor() {
    showAlert(elements.codeEditorStatus, "");
    try {
      if (!state.systemStatus) {
        await refreshSystemMetrics({ showLoader: false, silent: true });
      }
    } catch (error) {
      // уведомление уже показано
    }
    updateCodeEditorFileList(state.managedFiles || []);
    if (state.managedFiles && state.managedFiles.length) {
      const initialFile = state.activeCodeFile || state.managedFiles[0];
      if (elements.codeEditorSelect) {
        elements.codeEditorSelect.value = initialFile;
      }
      await loadCodeFile(initialFile);
    } else if (elements.codeEditorContent) {
      elements.codeEditorContent.value = "";
    }
  }

  async function saveCodeFile() {
    if (!state.activeCodeFile || !elements.codeEditorContent) {
      return;
    }
    const payload = {
      content: elements.codeEditorContent.value,
    };
    if (elements.codeEditorMessage) {
      const message = elements.codeEditorMessage.value.trim();
      if (message) {
        payload.message = message;
      }
    }
    showAlert(elements.codeEditorStatus, "");
    if (elements.codeEditorSave) {
      elements.codeEditorSave.disabled = true;
      elements.codeEditorSave.textContent = "Сохранение...";
    }
    try {
      const encoded = buildFileUrl(state.activeCodeFile);
      const response = await fetch(`${apiBaseUrl}/admin/system/files/${encoded}`, {
        method: "PUT",
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
      const responseBody = await response.json().catch(() => ({}));
      if (!response.ok) {
        const reason = responseBody?.detail || responseBody?.error || "Не удалось сохранить файл.";
        throw new Error(reason);
      }
      showAlert(elements.codeEditorStatus, "Файл успешно сохранён.", "success");
      void refreshSystemMetrics({ showLoader: false, silent: true });
    } catch (error) {
      console.error(error);
      showAlert(
        elements.codeEditorStatus,
        error?.message || "Не удалось сохранить изменения. Проверьте журнал сервера."
      );
    } finally {
      if (elements.codeEditorSave) {
        elements.codeEditorSave.disabled = false;
        elements.codeEditorSave.textContent = "Сохранить изменения";
      }
    }
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

  function renderPlatformBreakdown(breakdown) {
    if (!elements.activityPlatforms) {
      return;
    }

    elements.activityPlatforms.innerHTML = "";
    const entries = Object.entries(breakdown || {});

    if (entries.length === 0) {
      const emptyItem = document.createElement("li");
      emptyItem.className = "platform-item";
      emptyItem.textContent = "Нет активных сессий";
      elements.activityPlatforms.appendChild(emptyItem);
      return;
    }

    entries
      .sort((a, b) => b[1] - a[1])
      .forEach(([platform, count]) => {
        const item = document.createElement("li");
        item.className = "platform-item";

        const name = document.createElement("span");
        name.className = "platform-name";
        name.textContent = platform || "unknown";

        const value = document.createElement("span");
        value.className = "platform-count";
        value.textContent = String(count ?? 0);

        item.appendChild(name);
        item.appendChild(value);
        elements.activityPlatforms?.appendChild(item);
      });
  }

  function renderActivityMetrics(metrics) {
    const activityNow = metrics?.active_now ?? 0;
    const activityDay = metrics?.active_24h ?? 0;

    setText(elements.activityNow, activityNow);
    setText(elements.activityDay, activityDay);
    renderPlatformBreakdown(metrics?.platform_breakdown);

    toggleHidden(elements.activityError, true);
    state.activityLoadedOnce = true;
  }

  async function refreshActivityMetrics(options) {
    const silent = options?.silent ?? false;
    if (!elements.activityNow || pageType !== "users") {
      return;
    }

    if (!silent && elements.activityError) {
      toggleHidden(elements.activityError, true);
    }

    try {
      const response = await fetch(`${apiBaseUrl}/admin/activity/metrics`, {
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
      renderActivityMetrics(data);
    } catch (error) {
      console.error(error);
      if (elements.activityError) {
        elements.activityError.textContent = "Не удалось загрузить метрики активности.";
        toggleHidden(elements.activityError, false);
      }
      if (!state.activityLoadedOnce) {
        renderPlatformBreakdown({});
      }
    }
  }

  function stopActivityPolling() {
    if (state.activityInterval) {
      window.clearInterval(state.activityInterval);
      state.activityInterval = null;
    }
  }

  function startActivityPolling() {
    if (pageType !== "users") {
      stopActivityPolling();
      return;
    }

    stopActivityPolling();
    void refreshActivityMetrics({ silent: false });
    state.activityInterval = window.setInterval(() => {
      void refreshActivityMetrics({ silent: true });
    }, 30000);
  }

  function formatCsvValue(value) {
    if (value === null || value === undefined) {
      return "";
    }
    const stringValue = String(value);
    if (/[",\n]/.test(stringValue)) {
      return `"${stringValue.replace(/"/g, '""')}"`;
    }
    return stringValue;
  }

  function formatDateForCsv(value) {
    if (!value) {
      return "";
    }
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      return "";
    }
    return date.toISOString();
  }

  function buildTopItemsCsv(user) {
    const items = Array.isArray(user.top_worn_items) ? user.top_worn_items : [];
    if (items.length === 0) {
      return "";
    }
    return items
      .map((item) => `${item.name || "Без названия"} (${item.usage_count || 0})`)
      .join("; ");
  }

  function downloadUsersCsv() {
    const users = Array.isArray(state.users) ? state.users : [];
    if (users.length === 0) {
      window.alert("Нет данных для экспорта. Сначала загрузите пользователей.");
      return;
    }

    const headers = [
      "ID",
      "Имя",
      "Email",
      "Телефон",
      "Вещи",
      "Фотографии",
      "Манекены",
      "Примерки 30 дней",
      "Всего примерок",
      "Новые вещи 30 дней",
      "Очередь",
      "Локации",
      "Последняя примерка",
      "Последний манекен",
      "Популярные вещи",
    ];

    const rows = users
      .slice()
      .sort((a, b) => a.id - b.id)
      .map((user) => [
        formatCsvValue(user.id),
        formatCsvValue(user.name || ""),
        formatCsvValue(user.email || ""),
        formatCsvValue(user.phone || ""),
        formatCsvValue(user.total_clothes ?? 0),
        formatCsvValue(user.total_clothes_images ?? 0),
        formatCsvValue(user.total_mannequins ?? 0),
        formatCsvValue(user.wear_events_last_30_days ?? 0),
        formatCsvValue(user.total_wear_events ?? 0),
        formatCsvValue(user.new_clothes_last_30_days ?? 0),
        formatCsvValue(user.pending_metadata_items ?? 0),
        formatCsvValue(user.locations_count ?? 0),
        formatCsvValue(formatDateForCsv(user.last_wear_at)),
        formatCsvValue(formatDateForCsv(user.last_mannequin_at)),
        formatCsvValue(buildTopItemsCsv(user)),
      ]);

    const csvContent = [headers, ...rows]
      .map((row) => row.join(","))
      .join("\n");

    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = `users-${new Date().toISOString()}.csv`;
    link.click();
    URL.revokeObjectURL(link.href);
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
      state.users = users;
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
      if (pageType === "users") {
        void refreshActivityMetrics({ silent: false });
      }
    });
  }

  if (elements.exportCsvButton) {
    elements.exportCsvButton.addEventListener("click", () => {
      downloadUsersCsv();
    });
  }

  if (elements.systemRefreshButton) {
    elements.systemRefreshButton.addEventListener("click", () => {
      void refreshSystemMetrics({ showLoader: true });
      void loadSystemEvents({ resetPage: true });
      void loadQueueSnapshot({ showLoader: false, silent: true });
    });
  }

  if (elements.queueButton) {
    elements.queueButton.addEventListener("click", () => {
      openDrawer("queue");
      void loadQueueSnapshot({ showLoader: true });
    });
  }

  if (elements.queueRefresh) {
    elements.queueRefresh.addEventListener("click", () => {
      void loadQueueSnapshot({ showLoader: true });
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

  if (elements.openCodeEditorButton) {
    elements.openCodeEditorButton.addEventListener("click", () => {
      openDrawer("code");
      void prepareCodeEditor();
    });
  }

  if (elements.systemActionsToggle) {
    elements.systemActionsToggle.addEventListener("click", () => {
      toggleSystemActionsMenu();
    });
  }

  if (elements.systemActionsList) {
    elements.systemActionsList.addEventListener("click", (event) => {
      const target = event.target;
      if (target?.dataset?.action) {
        event.stopPropagation();
        void performSystemAction(target.dataset.action);
      }
    });
  }

  document.addEventListener("click", (event) => {
    if (!elements.systemActionsList || !elements.systemActionsToggle) {
      return;
    }
    const isToggle = elements.systemActionsToggle.contains(event.target);
    const isMenu = elements.systemActionsList.contains(event.target);
    if (!isToggle && !isMenu) {
      closeSystemActionsMenu();
    }
  });

  if (elements.codeEditorSelect) {
    elements.codeEditorSelect.addEventListener("change", (event) => {
      const value = event.target.value;
      if (value) {
        void loadCodeFile(value);
      }
    });
  }

  if (elements.codeEditorRefresh) {
    elements.codeEditorRefresh.addEventListener("click", () => {
      if (state.activeCodeFile) {
        void loadCodeFile(state.activeCodeFile);
      } else if (elements.codeEditorSelect && elements.codeEditorSelect.value) {
        void loadCodeFile(elements.codeEditorSelect.value);
      }
    });
  }

  if (elements.codeEditorSave) {
    elements.codeEditorSave.addEventListener("click", () => {
      void saveCodeFile();
    });
  }

  if (elements.codeEditorCancel) {
    elements.codeEditorCancel.addEventListener("click", () => {
      closeDrawer();
    });
  }

  if (elements.codeEditorContent) {
    elements.codeEditorContent.addEventListener("input", () => {
      showAlert(elements.codeEditorStatus, "");
    });
  }

  if (elements.databaseRefreshButton) {
    elements.databaseRefreshButton.addEventListener("click", () => {
      void loadDatabaseSummary({ showLoader: true });
    });
  }

  if (elements.databaseTableSelect) {
    elements.databaseTableSelect.addEventListener("change", (event) => {
      state.databaseSelectedTable = event.target.value;
      void loadDatabaseTable({ showLoader: true });
    });
  }

  if (elements.databaseTableRefresh) {
    elements.databaseTableRefresh.addEventListener("click", () => {
      void loadDatabaseTable({ showLoader: true });
    });
  }

  if (elements.databaseBackupButton) {
    elements.databaseBackupButton.addEventListener("click", () => {
      void downloadDatabaseBackup();
    });
  }

  if (elements.databaseRestoreButton) {
    elements.databaseRestoreButton.addEventListener("click", () => {
      void restoreDatabaseBackup();
    });
  }



  if (pageType === "system") {
    startSystemAutoRefresh();
    startSystemEventsAutoRefresh();
    void refreshSystemMetrics({ showLoader: true, silent: true });
    void loadSystemEvents({ resetPage: true });
    void loadQueueSnapshot({ showLoader: false, silent: true });
  } else {
    stopSystemAutoRefresh();
    stopSystemEventsAutoRefresh();
  }

  if (pageType === "database") {
    void loadDatabaseSummary({ showLoader: true });
  }

  if (pageType === "users" || pageType === "stats") {
    if (elements.createUserButton) {
      elements.createUserButton.addEventListener("click", () => {
        openDrawer("create");
      });
    }
    void loadUsers();
  }

  if (pageType === "users") {
    startActivityPolling();
  } else {
    stopActivityPolling();
  }

  if (pageType !== "users" && elements.createUserButton) {
    toggleHidden(elements.createUserButton, true);
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

})();
