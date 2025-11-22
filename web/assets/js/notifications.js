(function () {
  const config = window.APP_CONFIG || {};
  const apiBaseUrl =
    config.apiBaseUrl || "https://aapanel-api.noksovsteam.ru";
  const token = localStorage.getItem("authToken");

  if (!token) {
    window.location.replace("index.php");
    return;
  }

  const elements = {
    refresh: document.getElementById("refresh-button"),
    logout: document.getElementById("logout-button"),
    createChannel: document.getElementById("create-channel-button"),
    createTemplate: document.getElementById("create-template-button"),
    createRule: document.getElementById("create-rule-button"),
    channelsError: document.getElementById("channels-error"),
    channelsLoading: document.getElementById("channels-loading"),
    channelsEmpty: document.getElementById("channels-empty"),
    channelsWrapper: document.getElementById("channels-table-wrapper"),
    channelsBody: document.getElementById("channels-table-body"),
    templatesError: document.getElementById("templates-error"),
    templatesLoading: document.getElementById("templates-loading"),
    templatesEmpty: document.getElementById("templates-empty"),
    templatesWrapper: document.getElementById("templates-table-wrapper"),
    templatesBody: document.getElementById("templates-table-body"),
    rulesError: document.getElementById("rules-error"),
    rulesLoading: document.getElementById("rules-loading"),
    rulesEmpty: document.getElementById("rules-empty"),
    rulesWrapper: document.getElementById("rules-table-wrapper"),
    rulesBody: document.getElementById("rules-table-body"),
    rulesFilter: document.getElementById("rules-filter"),
    drawerOverlay: document.getElementById("drawer-overlay"),
    drawer: document.getElementById("drawer"),
    drawerTitle: document.getElementById("drawer-title"),
    drawerClose: document.getElementById("drawer-close"),
    drawerChannel: document.getElementById("drawer-channel"),
    drawerTemplate: document.getElementById("drawer-template"),
    drawerRule: document.getElementById("drawer-rule"),
    channelForm: document.getElementById("channel-form"),
    channelCancel: document.getElementById("channel-cancel"),
    channelStatus: document.getElementById("channel-status"),
    templateForm: document.getElementById("template-form"),
    templateCancel: document.getElementById("template-cancel"),
    templateStatus: document.getElementById("template-status"),
    templatePreview: document.getElementById("template-preview"),
    ruleForm: document.getElementById("rule-form"),
    ruleCancel: document.getElementById("rule-cancel"),
    ruleStatus: document.getElementById("rule-status"),
    ruleChannels: document.getElementById("rule-channels"),
    ruleTemplates: document.getElementById("rule-templates"),
  };

  const state = {
    channels: [],
    templates: [],
    rules: [],
    editing: {
      channelId: null,
      templateId: null,
      ruleId: null,
    },
  };

  function toggleHidden(el, hidden) {
    if (!el) return;
    el.classList[hidden ? "add" : "remove"]("hidden");
  }

  function setAlert(el, message, type = "error") {
    if (!el) return;
    el.textContent = message;
    el.classList.remove("hidden", "success");
    if (type === "success") {
      el.classList.add("success");
    } else {
      el.classList.remove("success");
    }
  }

  function clearAlert(el) {
    if (!el) return;
    el.textContent = "";
    el.classList.add("hidden");
    el.classList.remove("success");
  }

  function authorizedFetch(url, options = {}) {
    const headers = Object.assign({}, options.headers || {}, {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    });
    return fetch(url, { ...options, headers });
  }

  function setDrawerVisibility(open) {
    if (!elements.drawerOverlay || !elements.drawer) return;
    if (open) {
      elements.drawerOverlay.classList.remove("hidden");
      requestAnimationFrame(() => {
        elements.drawerOverlay.classList.add("active");
        elements.drawer.classList.add("active");
      });
    } else {
      elements.drawerOverlay.classList.remove("active");
      elements.drawer.classList.remove("active");
      window.setTimeout(() => {
        if (!elements.drawerOverlay.classList.contains("active")) {
          elements.drawerOverlay.classList.add("hidden");
        }
      }, 200);
    }
  }

  function showDrawer(section) {
    if (!elements.drawer) return;
    [elements.drawerChannel, elements.drawerTemplate, elements.drawerRule].forEach(
      (item) => item && toggleHidden(item, item !== section)
    );
  }

  function openDrawer(mode) {
    if (!elements.drawerTitle) return;
    if (mode === "channel") {
      elements.drawerTitle.textContent = state.editing.channelId
        ? "Редактирование канала"
        : "Новый канал";
      showDrawer(elements.drawerChannel);
    } else if (mode === "template") {
      elements.drawerTitle.textContent = state.editing.templateId
        ? "Редактирование шаблона"
        : "Новый шаблон";
      showDrawer(elements.drawerTemplate);
    } else {
      elements.drawerTitle.textContent = state.editing.ruleId
        ? "Редактирование правила"
        : "Новое правило";
      showDrawer(elements.drawerRule);
    }
    setDrawerVisibility(true);
  }

  function closeDrawer() {
    state.editing.channelId = null;
    state.editing.templateId = null;
    state.editing.ruleId = null;
    clearAlert(elements.channelStatus);
    clearAlert(elements.templateStatus);
    clearAlert(elements.ruleStatus);
    if (elements.channelForm) elements.channelForm.reset();
    if (elements.templateForm) elements.templateForm.reset();
    if (elements.ruleForm) elements.ruleForm.reset();
    if (elements.templatePreview) elements.templatePreview.textContent = "";
    setDrawerVisibility(false);
  }

  function formatDate(value) {
    if (!value) return "—";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "—";
    return date.toLocaleString();
  }

  function renderChannels() {
    const rows = state.channels;
    toggleHidden(elements.channelsLoading, true);
    toggleHidden(elements.channelsEmpty, rows.length > 0);
    toggleHidden(elements.channelsWrapper, rows.length === 0);

    if (!elements.channelsBody) return;
    elements.channelsBody.innerHTML = "";

    rows.forEach((channel) => {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td>${channel.name}</td>
        <td>${channel.channel_type}</td>
        <td><span class="status-pill ${channel.status === "connected" ? "success" : "danger"}">${
        channel.status || "—"
      }</span></td>
        <td>${channel.is_active ? "Да" : "Нет"}</td>
        <td>${formatDate(channel.last_tested_at)}</td>
        <td class="table-actions">
          <button class="secondary" data-action="test" data-id="${channel.id}">Тест</button>
          <button class="secondary" data-action="edit" data-id="${channel.id}">Редактировать</button>
          <button class="danger" data-action="delete" data-id="${channel.id}">Удалить</button>
        </td>
      `;
      elements.channelsBody.appendChild(tr);
    });
  }

  function renderTemplates() {
    const rows = state.templates;
    toggleHidden(elements.templatesLoading, true);
    toggleHidden(elements.templatesEmpty, rows.length > 0);
    toggleHidden(elements.templatesWrapper, rows.length === 0);

    if (!elements.templatesBody) return;
    elements.templatesBody.innerHTML = "";
    rows.forEach((tpl) => {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td>${tpl.name}</td>
        <td>${tpl.channel_type || "Любой"}</td>
        <td>${formatDate(tpl.created_at)}</td>
        <td class="table-actions">
          <button class="secondary" data-action="edit-template" data-id="${tpl.id}">Редактировать</button>
          <button class="danger" data-action="delete-template" data-id="${tpl.id}">Удалить</button>
        </td>
      `;
      elements.templatesBody.appendChild(tr);
    });
  }

  function renderRules() {
    const filter = (elements.rulesFilter?.value || "").toLowerCase();
    const rows = state.rules.filter((rule) =>
      !filter || rule.event.toLowerCase().includes(filter)
    );
    toggleHidden(elements.rulesLoading, true);
    toggleHidden(elements.rulesEmpty, rows.length > 0);
    toggleHidden(elements.rulesWrapper, rows.length === 0);

    if (!elements.rulesBody) return;
    elements.rulesBody.innerHTML = "";
    rows.forEach((rule) => {
      const channelTitles = rule.channel_ids
        .map((id) => state.channels.find((c) => c.id === id)?.name || `#${id}`)
        .join(", ");
      const templateTitle =
        state.templates.find((tpl) => tpl.id === rule.template_id)?.name || "—";
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td>${rule.event}</td>
        <td>${rule.priority}</td>
        <td>${channelTitles || "—"}</td>
        <td>${templateTitle}</td>
        <td class="table-actions">
          <button class="secondary" data-action="edit-rule" data-id="${rule.id}">Редактировать</button>
          <button class="danger" data-action="delete-rule" data-id="${rule.id}">Удалить</button>
        </td>
      `;
      elements.rulesBody.appendChild(tr);
    });
  }

  function fillRuleSelectors() {
    if (!elements.ruleChannels || !elements.ruleTemplates) return;
    elements.ruleChannels.innerHTML = "";
    state.channels.forEach((channel) => {
      const option = document.createElement("option");
      option.value = channel.id;
      option.textContent = `${channel.name} (${channel.channel_type})`;
      elements.ruleChannels.appendChild(option);
    });

    elements.ruleTemplates.innerHTML = "";
    const emptyOption = document.createElement("option");
    emptyOption.value = "";
    emptyOption.textContent = "По умолчанию";
    elements.ruleTemplates.appendChild(emptyOption);
    state.templates.forEach((tpl) => {
      const option = document.createElement("option");
      option.value = tpl.id;
      option.textContent = tpl.name;
      elements.ruleTemplates.appendChild(option);
    });
  }

  async function loadChannels() {
    toggleHidden(elements.channelsLoading, false);
    clearAlert(elements.channelsError);
    try {
      const response = await authorizedFetch(`${apiBaseUrl}/admin/notifications/channels`);
      if (response.status === 401) {
        localStorage.removeItem("authToken");
        window.location.replace("index.php");
        return;
      }
      if (!response.ok) throw new Error("Failed to load channels");
      state.channels = await response.json();
      renderChannels();
      fillRuleSelectors();
    } catch (error) {
      console.error(error);
      setAlert(elements.channelsError, "Не удалось загрузить каналы");
      toggleHidden(elements.channelsLoading, true);
    }
  }

  async function loadTemplates() {
    toggleHidden(elements.templatesLoading, false);
    clearAlert(elements.templatesError);
    try {
      const response = await authorizedFetch(`${apiBaseUrl}/admin/notifications/templates`);
      if (!response.ok) throw new Error("Failed to load templates");
      state.templates = await response.json();
      renderTemplates();
      fillRuleSelectors();
    } catch (error) {
      console.error(error);
      setAlert(elements.templatesError, "Не удалось загрузить шаблоны");
      toggleHidden(elements.templatesLoading, true);
    }
  }

  async function loadRules() {
    toggleHidden(elements.rulesLoading, false);
    clearAlert(elements.rulesError);
    try {
      const response = await authorizedFetch(`${apiBaseUrl}/admin/notifications/rules`);
      if (!response.ok) throw new Error("Failed to load rules");
      state.rules = await response.json();
      renderRules();
    } catch (error) {
      console.error(error);
      setAlert(elements.rulesError, "Не удалось загрузить правила");
      toggleHidden(elements.rulesLoading, true);
    }
  }

  async function refreshAll() {
    await Promise.all([loadChannels(), loadTemplates(), loadRules()]);
  }

  function parseJsonField(value) {
    if (!value) return undefined;
    try {
      return JSON.parse(value);
    } catch (error) {
      console.error("Invalid JSON", error);
      return null;
    }
  }

  function setFormValue(form, selector, value) {
    if (!form) return;
    const field = form.querySelector(selector);
    if (!field) return;
    if (field.type === "checkbox") {
      field.checked = Boolean(value);
      return;
    }
    field.value = value ?? "";
  }

  function handleTemplatePreview() {
    if (!elements.templateForm || !elements.templatePreview) return;
    const formData = new FormData(elements.templateForm);
    const content = formData.get("content") || "";
    const sampleData = { user: "Demo User", issue: "проверка уведомлений" };
    let preview = content.toString();
    Object.entries(sampleData).forEach(([key, value]) => {
      preview = preview.replace(new RegExp(`{{\\s*${key}\\s*}}`, "gi"), value);
    });
    elements.templatePreview.textContent = preview;
  }

  async function submitChannel(event) {
    event.preventDefault();
    clearAlert(elements.channelStatus);
    if (!elements.channelForm) return;

    const formData = new FormData(elements.channelForm);
    const payload = {
      name: formData.get("name") || "",
      channel_type: formData.get("channel_type") || "",
      is_active: formData.get("is_active") === "on",
    };

    const configValue = parseJsonField(formData.get("config"));
    if (configValue === null) {
      setAlert(elements.channelStatus, "Невалидный JSON в конфигурации");
      return;
    }
    if (typeof configValue !== "undefined") {
      payload.config = configValue;
    }

    const method = state.editing.channelId ? "PUT" : "POST";
    const url = state.editing.channelId
      ? `${apiBaseUrl}/admin/notifications/channels/${state.editing.channelId}`
      : `${apiBaseUrl}/admin/notifications/channels`;

    try {
      const response = await authorizedFetch(url, {
        method,
        body: JSON.stringify(payload),
      });
      if (!response.ok) throw new Error("Save failed");
      await refreshAll();
      setAlert(elements.channelStatus, "Канал сохранен", "success");
    } catch (error) {
      console.error(error);
      setAlert(elements.channelStatus, "Не удалось сохранить канал");
    }
  }

  async function submitTemplate(event) {
    event.preventDefault();
    clearAlert(elements.templateStatus);
    if (!elements.templateForm) return;

    const formData = new FormData(elements.templateForm);
    const payload = {
      name: formData.get("name") || "",
      content: formData.get("content") || "",
      channel_type: formData.get("channel_type") || "",
    };

    const variablesValue = parseJsonField(formData.get("variables"));
    if (variablesValue === null) {
      setAlert(elements.templateStatus, "Невалидный JSON в переменных");
      return;
    }
    if (typeof variablesValue !== "undefined") {
      payload.variables = variablesValue;
    }

    const method = state.editing.templateId ? "PUT" : "POST";
    const url = state.editing.templateId
      ? `${apiBaseUrl}/admin/notifications/templates/${state.editing.templateId}`
      : `${apiBaseUrl}/admin/notifications/templates`;

    try {
      const response = await authorizedFetch(url, {
        method,
        body: JSON.stringify(payload),
      });
      if (!response.ok) throw new Error("Save failed");
      await refreshAll();
      setAlert(elements.templateStatus, "Шаблон сохранен", "success");
    } catch (error) {
      console.error(error);
      setAlert(elements.templateStatus, "Не удалось сохранить шаблон");
    }
  }

  async function submitRule(event) {
    event.preventDefault();
    clearAlert(elements.ruleStatus);
    if (!elements.ruleForm) return;

    const formData = new FormData(elements.ruleForm);
    const channelIds = (formData.getAll("channel_ids") || []).map((id) => Number(id));
    const payload = {
      event: formData.get("event") || "",
      priority: Number(formData.get("priority") || 0),
      channel_ids: channelIds,
      template_id: formData.get("template_id") ? Number(formData.get("template_id")) : null,
    };

    const filtersValue = parseJsonField(formData.get("filters"));
    if (filtersValue === null) {
      setAlert(elements.ruleStatus, "Невалидный JSON в фильтрах");
      return;
    }
    if (typeof filtersValue !== "undefined") {
      payload.filters = filtersValue;
    }

    const method = state.editing.ruleId ? "PUT" : "POST";
    const url = state.editing.ruleId
      ? `${apiBaseUrl}/admin/notifications/rules/${state.editing.ruleId}`
      : `${apiBaseUrl}/admin/notifications/rules`;

    try {
      const response = await authorizedFetch(url, {
        method,
        body: JSON.stringify(payload),
      });
      if (!response.ok) throw new Error("Save failed");
      await refreshAll();
      setAlert(elements.ruleStatus, "Правило сохранено", "success");
    } catch (error) {
      console.error(error);
      setAlert(elements.ruleStatus, "Не удалось сохранить правило");
    }
  }

  async function handleChannelAction(event) {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    const action = target.dataset.action;
    const id = Number(target.dataset.id);
    if (!action || Number.isNaN(id)) return;

    if (action === "edit") {
      const channel = state.channels.find((item) => item.id === id);
      if (!channel || !elements.channelForm) return;
      state.editing.channelId = id;
      setFormValue(elements.channelForm, 'input[name="name"]', channel.name);
      setFormValue(
        elements.channelForm,
        'select[name="channel_type"]',
        channel.channel_type
      );
      setFormValue(
        elements.channelForm,
        'textarea[name="config"]',
        JSON.stringify(channel.config || {}, null, 2)
      );
      setFormValue(elements.channelForm, 'input[name="is_active"]', channel.is_active);
      openDrawer("channel");
    }

    if (action === "delete") {
      if (!confirm("Удалить канал?")) return;
      try {
        await authorizedFetch(`${apiBaseUrl}/admin/notifications/channels/${id}`, {
          method: "DELETE",
        });
        await refreshAll();
      } catch (error) {
        console.error(error);
        setAlert(elements.channelsError, "Не удалось удалить канал");
      }
    }

    if (action === "test") {
      target.disabled = true;
      target.textContent = "Тест...";
      try {
        const response = await authorizedFetch(
          `${apiBaseUrl}/admin/notifications/channels/${id}/test`,
          { method: "POST" }
        );
        if (!response.ok) throw new Error("Test failed");
        const updated = await response.json();
        const index = state.channels.findIndex((item) => item.id === id);
        if (index !== -1) state.channels[index] = updated;
        renderChannels();
      } catch (error) {
        console.error(error);
        setAlert(elements.channelsError, "Тест не выполнен");
      } finally {
        target.disabled = false;
        target.textContent = "Тест";
      }
    }
  }

  async function handleTemplateAction(event) {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    const action = target.dataset.action;
    const id = Number(target.dataset.id);
    if (!action || Number.isNaN(id)) return;

    if (action === "edit-template") {
      const template = state.templates.find((item) => item.id === id);
      if (!template || !elements.templateForm) return;
      state.editing.templateId = id;
      setFormValue(elements.templateForm, 'input[name="name"]', template.name);
      setFormValue(
        elements.templateForm,
        'select[name="channel_type"]',
        template.channel_type || ""
      );
      setFormValue(elements.templateForm, 'textarea[name="content"]', template.content);
      setFormValue(
        elements.templateForm,
        'textarea[name="variables"]',
        template.variables ? JSON.stringify(template.variables, null, 2) : ""
      );
      handleTemplatePreview();
      openDrawer("template");
    }

    if (action === "delete-template") {
      if (!confirm("Удалить шаблон?")) return;
      try {
        await authorizedFetch(`${apiBaseUrl}/admin/notifications/templates/${id}`, {
          method: "DELETE",
        });
        await refreshAll();
      } catch (error) {
        console.error(error);
        setAlert(elements.templatesError, "Не удалось удалить шаблон");
      }
    }
  }

  async function handleRuleAction(event) {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    const action = target.dataset.action;
    const id = Number(target.dataset.id);
    if (!action || Number.isNaN(id)) return;

    if (action === "edit-rule") {
      const rule = state.rules.find((item) => item.id === id);
      if (!rule || !elements.ruleForm) return;
      state.editing.ruleId = id;
      setFormValue(elements.ruleForm, 'input[name="event"]', rule.event);
      setFormValue(elements.ruleForm, 'input[name="priority"]', rule.priority);
      Array.from(elements.ruleChannels.options).forEach((option) => {
        option.selected = rule.channel_ids.includes(Number(option.value));
      });
      if (elements.ruleTemplates) {
        elements.ruleTemplates.value = rule.template_id || "";
      }
      setFormValue(
        elements.ruleForm,
        'textarea[name="filters"]',
        rule.filters ? JSON.stringify(rule.filters, null, 2) : ""
      );
      openDrawer("rule");
    }

    if (action === "delete-rule") {
      if (!confirm("Удалить правило?")) return;
      try {
        await authorizedFetch(`${apiBaseUrl}/admin/notifications/rules/${id}`, {
          method: "DELETE",
        });
        await refreshAll();
      } catch (error) {
        console.error(error);
        setAlert(elements.rulesError, "Не удалось удалить правило");
      }
    }
  }

  function registerEvents() {
    elements.logout?.addEventListener("click", () => {
      localStorage.removeItem("authToken");
      localStorage.removeItem("userId");
      window.location.replace("index.php");
    });

    elements.refresh?.addEventListener("click", refreshAll);
    elements.drawerClose?.addEventListener("click", closeDrawer);
    elements.drawerOverlay?.addEventListener("click", (event) => {
      if (event.target === elements.drawerOverlay) {
        closeDrawer();
      }
    });

    elements.createChannel?.addEventListener("click", () => {
      state.editing.channelId = null;
      openDrawer("channel");
    });
    elements.createTemplate?.addEventListener("click", () => {
      state.editing.templateId = null;
      openDrawer("template");
    });
    elements.createRule?.addEventListener("click", () => {
      state.editing.ruleId = null;
      openDrawer("rule");
    });

    elements.channelCancel?.addEventListener("click", closeDrawer);
    elements.templateCancel?.addEventListener("click", closeDrawer);
    elements.ruleCancel?.addEventListener("click", closeDrawer);

    elements.channelForm?.addEventListener("submit", submitChannel);
    elements.templateForm?.addEventListener("submit", submitTemplate);
    elements.ruleForm?.addEventListener("submit", submitRule);

    elements.templateForm?.addEventListener("input", handleTemplatePreview);
    elements.rulesFilter?.addEventListener("input", renderRules);

    elements.channelsBody?.addEventListener("click", handleChannelAction);
    elements.templatesBody?.addEventListener("click", handleTemplateAction);
    elements.rulesBody?.addEventListener("click", handleRuleAction);
  }

  registerEvents();
  refreshAll();
})();
