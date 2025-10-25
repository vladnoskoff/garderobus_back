import axios from "axios";

import { API_BASE_URL } from "../config";
import { AdminUserSummary, CreateUserPayload, LoginResponse } from "./types";

const client = axios.create({
  baseURL: API_BASE_URL,
});

export async function login(email: string, password: string): Promise<LoginResponse> {
  const response = await client.post<LoginResponse>("/admin/login", { email, password });
  return response.data;
}

function authHeaders(token: string) {
  return {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  };
}

export async function fetchUserSummaries(token: string): Promise<AdminUserSummary[]> {
  const response = await client.get<AdminUserSummary[]>("/admin/users/summary", authHeaders(token));
  return response.data;
}

export async function createUser(
  token: string,
  payload: CreateUserPayload
): Promise<void> {
  await client.post("/admin/users", payload, authHeaders(token));
}

export async function deleteUser(token: string, userId: number): Promise<void> {
  await client.delete(`/admin/users/${userId}`, authHeaders(token));
}
