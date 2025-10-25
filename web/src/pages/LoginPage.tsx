import { FormEvent, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";

import { login as loginRequest } from "../api/client";
import { useAuth } from "../hooks/useAuth";

interface LocationState {
  from?: { pathname: string };
}

export default function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { login } = useAuth();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const response = await loginRequest(email, password);
      login(response.access_token, response.user_id);
      const state = location.state as LocationState | null;
      const redirectTo = state?.from?.pathname ?? "/";
      navigate(redirectTo, { replace: true });
    } catch (err) {
      console.error(err);
      setError("Не удалось войти. Проверьте email и пароль.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: "linear-gradient(135deg, #ede9fe, #e0f2fe)",
        padding: "32px",
      }}
    >
      <div className="card" style={{ maxWidth: 420, width: "100%" }}>
        <div className="flex-column gap-md" style={{ marginBottom: 24 }}>
          <h2 style={{ margin: 0 }}>Вход в админ-панель</h2>
          <p className="text-muted" style={{ margin: 0 }}>
            Используйте учетную запись пользователя, чтобы управлять гардеробом и статистикой.
          </p>
        </div>
        <form className="flex-column gap-md" onSubmit={handleSubmit}>
          <label className="flex-column gap-sm">
            <span>Email</span>
            <input
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="admin@example.com"
              required
            />
          </label>
          <label className="flex-column gap-sm">
            <span>Пароль</span>
            <input
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder="Введите пароль"
              required
            />
          </label>
          {error ? <span style={{ color: "#dc2626" }}>{error}</span> : null}
          <button className="primary" type="submit" disabled={loading}>
            {loading ? "Вход..." : "Войти"}
          </button>
        </form>
      </div>
    </div>
  );
}
