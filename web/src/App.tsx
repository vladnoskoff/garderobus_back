import { Navigate, Route, Routes, useLocation } from "react-router-dom";

import Layout from "./components/Layout";
import { useAuth } from "./hooks/useAuth";
import DashboardPage from "./pages/DashboardPage";
import LoginPage from "./pages/LoginPage";

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { token } = useAuth();
  const location = useLocation();

  if (!token) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <>{children}</>;
}

function AuthenticatedLayout() {
  return (
    <Layout>
      <Routes>
        <Route index element={<DashboardPage />} />
      </Routes>
    </Layout>
  );
}

export default function App() {
  const { token } = useAuth();

  return (
    <Routes>
      <Route
        path="/login"
        element={token ? <Navigate to="/" replace /> : <LoginPage />}
      />
      <Route
        path="/*"
        element={
          <ProtectedRoute>
            <AuthenticatedLayout />
          </ProtectedRoute>
        }
      />
    </Routes>
  );
}
