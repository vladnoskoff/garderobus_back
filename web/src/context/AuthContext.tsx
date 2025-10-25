import React, { createContext, useCallback, useEffect, useMemo, useState } from "react";

interface AuthState {
  token: string | null;
  userId: number | null;
}

interface AuthContextValue extends AuthState {
  login: (token: string, userId: number) => void;
  logout: () => void;
}

const STORAGE_KEY = "garderobus-admin-auth";

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export const AuthProvider: React.FC<React.PropsWithChildren> = ({ children }) => {
  const [state, setState] = useState<AuthState>({ token: null, userId: null });

  useEffect(() => {
    const saved = window.localStorage.getItem(STORAGE_KEY);
    if (!saved) {
      return;
    }
    try {
      const parsed = JSON.parse(saved) as AuthState;
      setState(parsed);
    } catch (error) {
      console.warn("Не удалось восстановить сессию", error);
      window.localStorage.removeItem(STORAGE_KEY);
    }
  }, []);

  const login = useCallback((token: string, userId: number) => {
    const nextState: AuthState = { token, userId };
    setState(nextState);
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(nextState));
  }, []);

  const logout = useCallback(() => {
    setState({ token: null, userId: null });
    window.localStorage.removeItem(STORAGE_KEY);
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({ token: state.token, userId: state.userId, login, logout }),
    [state, login, logout]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export function useAuthContext(): AuthContextValue {
  const context = React.useContext(AuthContext);
  if (!context) {
    throw new Error("useAuthContext должен использоваться внутри AuthProvider");
  }
  return context;
}
