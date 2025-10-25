from __future__ import annotations

import os
from locust import HttpUser, between, task

BASE_URL = os.getenv("BASE_URL", "http://localhost:8080")


class GarderobusUser(HttpUser):
    wait_time = between(1, 3)
    host = BASE_URL

    @task(3)
    def read_weather(self) -> None:
        self.client.get("/weather/user/1")

    @task(1)
    def healthcheck(self) -> None:
        self.client.get("/healthz")
