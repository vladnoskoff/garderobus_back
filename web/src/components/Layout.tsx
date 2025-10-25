import { NavLink, useNavigate } from "react-router-dom";

import { useAuth } from "../hooks/useAuth";

interface LayoutProps {
  children: React.ReactNode;
}

export default function Layout({ children }: LayoutProps) {
  const { logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="flex-column gap-sm">
          <h1>Garderobus Admin</h1>
          <span className="text-muted">Панель управления гардеробом</span>
        </div>
        <nav>
          <NavLink end to="/">
            Пользователи
          </NavLink>
        </nav>
        <button className="link" onClick={handleLogout}>
          Выйти
        </button>
      </aside>
      <main className="content">{children}</main>
    </div>
  );
}
