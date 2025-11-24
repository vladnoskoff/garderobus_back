PYTHON ?= python3
API_DIR ?= api
ENV_FILE ?= $(API_DIR)/.env
IMAGE ?= garderobus-api

.PHONY: install install-dev run run-prod docker-build docker-run lint format format-check typecheck test check openapi-fixtures

install:
$(PYTHON) -m pip install --upgrade pip
$(PYTHON) -m pip install -r $(API_DIR)/requirements.txt

install-dev: install
$(PYTHON) -m pip install -r $(API_DIR)/requirements-dev.txt

run:
cd $(API_DIR) && uvicorn main:app --host 0.0.0.0 --port 8000 --reload

run-prod:
cd $(API_DIR) && uvicorn main:app --host 0.0.0.0 --port 8000

docker-build:
docker build -t $(IMAGE) $(API_DIR)

docker-run:
docker run --env-file $(ENV_FILE) -p 8000:8000 $(IMAGE)

lint:
cd $(API_DIR) && ruff check .

format:
cd $(API_DIR) && black .

format-check:
cd $(API_DIR) && black --check .

typecheck:
cd $(API_DIR) && mypy .

test:
cd $(API_DIR) && pytest

check: lint format-check typecheck test

openapi-fixtures:
cd $(API_DIR) && DATABASE_URL=sqlite:///./openapi.db DATABASE_USE_REPLICAS=false CACHE_ENABLED=false TRACING_ENABLED=false OPENAI_API_KEY=fake-key OPENWEATHER_API_KEY=fake-key $(PYTHON) docs/generate_openapi.py
