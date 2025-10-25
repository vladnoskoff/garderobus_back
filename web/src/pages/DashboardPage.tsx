import dayjs from "dayjs";
import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

import { createUser, deleteUser, fetchUserSummaries } from "../api/client";
import { AdminUserSummary, CreateUserPayload } from "../api/types";
import { useAuth } from "../hooks/useAuth";

const INITIAL_FORM: CreateUserPayload = {
  name: "",
  email: "",
  password: "",
  phone: "",
  gender: "",
  theme_preference: "light",
  pin_code: "",
  language_preference: "ru",
};

export default function DashboardPage() {
  const { token } = useAuth();
  const [users, setUsers] = useState<AdminUserSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState<CreateUserPayload>({ ...INITIAL_FORM });
  const [creating, setCreating] = useState(false);

  const load = useCallback(async () => {
    if (!token) {
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const data = await fetchUserSummaries(token);
      setUsers(data);
    } catch (err) {
      console.error(err);
      setError("Не удалось загрузить пользователей. Попробуйте позже.");
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    void load();
  }, [load]);

  const totals = useMemo(() => {
    if (!users.length) {
      return {
        clothes: 0,
        photos: 0,
        mannequins: 0,
        outfits: 0,
        activeUsers: 0,
        wearEvents: 0,
      };
    }

    const aggregate = users.reduce(
      (acc, user) => {
        acc.clothes += user.total_clothes;
        acc.photos += user.total_clothes_images;
        acc.mannequins += user.total_mannequins;
        acc.outfits += user.total_outfits;
        acc.wearEvents += user.total_wear_events;
        if (user.wear_events_last_30_days > 0) {
          acc.activeUsers += 1;
        }
        return acc;
      },
      { clothes: 0, photos: 0, mannequins: 0, outfits: 0, activeUsers: 0, wearEvents: 0 }
    );

    return aggregate;
  }, [users]);

  const handleFormChange = (field: keyof CreateUserPayload, value: string) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleCreateUser = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!token) {
      return;
    }
    setCreating(true);
    setError(null);
    try {
      const payload: CreateUserPayload = {
        name: form.name.trim(),
        email: form.email.trim().toLowerCase(),
        password: form.password,
        theme_preference: form.theme_preference ?? "light",
        language_preference: form.language_preference ?? "ru",
      };

      if (form.phone && form.phone.trim()) {
        payload.phone = form.phone.trim();
      }
      if (form.gender && form.gender.trim()) {
        payload.gender = form.gender.trim();
      }
      if (form.pin_code && form.pin_code.trim()) {
        payload.pin_code = form.pin_code.trim();
      }

      await createUser(token, payload);
      setForm({ ...INITIAL_FORM });
      await load();
    } catch (err) {
      console.error(err);
      setError("Не удалось создать пользователя. Проверьте данные и повторите попытку.");
    } finally {
      setCreating(false);
    }
  };

  const handleDeleteUser = async (user: AdminUserSummary) => {
    if (!token) {
      return;
    }
    const confirmation = window.confirm(
      `Удалить пользователя ${user.name || user.email}? Это действие необратимо.`
    );
    if (!confirmation) {
      return;
    }
    try {
      await deleteUser(token, user.id);
      await load();
    } catch (err) {
      console.error(err);
      setError("Не удалось удалить пользователя. Попробуйте снова.");
    }
  };

  const renderTopItems = (user: AdminUserSummary) => {
    if (!user.top_worn_items.length) {
      return <span className="text-muted">Нет данных</span>;
    }
    return (
      <div className="tag-list">
        {user.top_worn_items.map((item) => (
          <span className="badge" key={item.clothing_id}>
            {item.name} · {item.usage_count}
          </span>
        ))}
      </div>
    );
  };

  return (
    <div className="flex-column gap-lg">
      <div className="flex-between">
        <div>
          <h2 className="page-title">Пользователи и статистика</h2>
          <p className="text-muted">Обзор активности гардероба по всем учетным записям.</p>
        </div>
        <button className="primary" onClick={() => void load()} disabled={loading}>
          Обновить
        </button>
      </div>

      <section className="grid">
        <div className="stat-card">
          <h3>Всего пользователей</h3>
          <strong>{users.length}</strong>
          <span>Активные (30 дней): {totals.activeUsers}</span>
        </div>
        <div className="stat-card">
          <h3>Вещей в гардеробах</h3>
          <strong>{totals.clothes}</strong>
          <span>Новые за 30 дней: {users.reduce((acc, item) => acc + item.new_clothes_last_30_days, 0)}</span>
        </div>
        <div className="stat-card">
          <h3>Фотографии</h3>
          <strong>{totals.photos}</strong>
          <span>Манекены: {totals.mannequins}</span>
        </div>
        <div className="stat-card">
          <h3>Образы и использование</h3>
          <strong>{totals.outfits}</strong>
          <span>Примерок за все время: {totals.wearEvents}</span>
        </div>
      </section>

      <section className="card">
        <h3 style={{ marginTop: 0 }}>Создание пользователя</h3>
        <p className="text-muted" style={{ marginTop: 8 }}>
          Добавьте нового участника, чтобы он мог пользоваться приложением и админ-панелью.
        </p>
        <form className="grid" style={{ marginTop: 20, gap: 16 }} onSubmit={handleCreateUser}>
          <label className="flex-column gap-sm">
            <span>Имя</span>
            <input
              type="text"
              value={form.name}
              onChange={(event) => handleFormChange("name", event.target.value)}
              placeholder="Иван Иванов"
              required
            />
          </label>
          <label className="flex-column gap-sm">
            <span>Email</span>
            <input
              type="email"
              value={form.email}
              onChange={(event) => handleFormChange("email", event.target.value)}
              placeholder="user@example.com"
              required
            />
          </label>
          <label className="flex-column gap-sm">
            <span>Пароль</span>
            <input
              type="password"
              value={form.password}
              onChange={(event) => handleFormChange("password", event.target.value)}
              placeholder="Минимум 6 символов"
              required
            />
          </label>
          <label className="flex-column gap-sm">
            <span>Телефон</span>
            <input
              type="text"
              value={form.phone ?? ""}
              onChange={(event) => handleFormChange("phone", event.target.value)}
              placeholder="+7 900 000-00-00"
            />
          </label>
          <label className="flex-column gap-sm">
            <span>Пол</span>
            <input
              type="text"
              value={form.gender ?? ""}
              onChange={(event) => handleFormChange("gender", event.target.value)}
              placeholder="female / male"
            />
          </label>
          <label className="flex-column gap-sm">
            <span>PIN-код (необязательно)</span>
            <input
              type="text"
              value={form.pin_code ?? ""}
              onChange={(event) => handleFormChange("pin_code", event.target.value)}
              placeholder="4-8 цифр"
            />
          </label>
          <label className="flex-column gap-sm">
            <span>Тема оформления</span>
            <select
              value={form.theme_preference ?? "light"}
              onChange={(event) => handleFormChange("theme_preference", event.target.value)}
              style={{ padding: "10px 12px", borderRadius: 10, border: "1px solid #d1d5db" }}
            >
              <option value="light">Светлая</option>
              <option value="dark">Темная</option>
            </select>
          </label>
          <label className="flex-column gap-sm">
            <span>Язык интерфейса</span>
            <select
              value={form.language_preference ?? "ru"}
              onChange={(event) => handleFormChange("language_preference", event.target.value)}
              style={{ padding: "10px 12px", borderRadius: 10, border: "1px solid #d1d5db" }}
            >
              <option value="ru">Русский</option>
              <option value="en">English</option>
            </select>
          </label>
          <div className="flex" style={{ alignItems: "flex-end" }}>
            <button className="primary" type="submit" disabled={creating}>
              {creating ? "Создание..." : "Добавить"}
            </button>
          </div>
        </form>
      </section>

      <section className="card">
        <div className="flex-between" style={{ marginBottom: 20 }}>
          <h3 style={{ margin: 0 }}>Статистика пользователей</h3>
          <span className="text-muted">Отсортировано по идентификатору</span>
        </div>
        {error ? <div style={{ color: "#dc2626" }}>{error}</div> : null}
        {loading ? (
          <p className="text-muted">Загрузка...</p>
        ) : users.length === 0 ? (
          <p className="text-muted">Пользователи пока не добавлены.</p>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table className="table">
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
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {users.map((user) => (
                  <tr key={user.id}>
                    <td>
                      <div className="flex-column gap-sm">
                        <strong>{user.name || "Без имени"}</strong>
                        <span className="text-muted">{user.email}</span>
                        {user.phone ? <span className="text-muted">{user.phone}</span> : null}
                      </div>
                    </td>
                    <td>{user.total_clothes}</td>
                    <td>{user.total_clothes_images}</td>
                    <td>{user.total_mannequins}</td>
                    <td>{user.wear_events_last_30_days}</td>
                    <td>{user.total_wear_events}</td>
                    <td>{user.new_clothes_last_30_days}</td>
                    <td>
                      <div className="flex-column gap-sm">
                        <span>
                          {user.last_wear_at
                            ? dayjs(user.last_wear_at).format("DD.MM.YYYY HH:mm")
                            : "—"}
                        </span>
                        <span className="text-muted">
                          Манекен: {user.last_mannequin_at ? dayjs(user.last_mannequin_at).format("DD.MM.YYYY") : "—"}
                        </span>
                      </div>
                    </td>
                    <td>{renderTopItems(user)}</td>
                    <td>
                      <button className="danger" onClick={() => void handleDeleteUser(user)}>
                        Удалить
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
