# Microservice-Oriented API Layout

This directory contains a proposed microservice decomposition of the existing monolithic FastAPI application.
Each service is represented as a standalone FastAPI project with its own dependencies, runtime configuration,
and container definition. The goal is to illustrate how the current monolith can be split into independently
deployable services.

## Services Overview

| Service | Responsibility | Key Endpoints |
|---------|----------------|----------------|
| `gateway` | Acts as an API gateway / BFF that orchestrates calls to downstream services and exposes a consolidated API to clients. | `/api/v1/...` aggregated routes |
| `auth_service` | Handles user registration, authentication, and profile management. Issues tokens and manages credentials. | `/users/*`, `/auth/*` |
| `wardrobe_service` | Manages clothes, outfits, wardrobe locations, and media assets. | `/clothes/*`, `/outfits/*`, `/locations/*` |
| `ai_service` | Provides long-running recommendation jobs, mannequin generation, and other ML-backed features through a task queue. | `/jobs/*`, `/recommendations/*` |
| `weather_service` | Provides weather and climate data enriched for wardrobe recommendations. | `/weather/*` |

A shared message broker (`rabbitmq`) and relational database (`postgres`) are defined in the accompanying `docker-compose.yml`. Each
service manages its own schema and migrations; a lightweight `common` package provides reusable DTOs and utilities.

> **Note**: The code in this folder is intentionally lightweight and focuses on structure and integration points rather than
reimplementing the full production logic from the monolith. Real data access layers and integrations should be ported from the
current application incrementally.

## Directory Structure

```
api_microservice/
├── README.md
├── docker-compose.yml
├── common/
│   ├── __init__.py
│   └── messaging.py
├── auth_service/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/
│       ├── __init__.py
│       ├── config.py
│       ├── main.py
│       ├── models.py
│       ├── routers.py
│       └── schemas.py
├── wardrobe_service/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/
│       ├── __init__.py
│       ├── config.py
│       ├── main.py
│       ├── media.py
│       ├── routers.py
│       └── schemas.py
├── ai_service/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/
│       ├── __init__.py
│       ├── config.py
│       ├── main.py
│       ├── routers.py
│       ├── tasks.py
│       └── worker.py
├── weather_service/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app/
│       ├── __init__.py
│       ├── config.py
│       ├── http_client.py
│       ├── main.py
│       └── routers.py
└── gateway/
    ├── Dockerfile
    ├── requirements.txt
    └── app/
        ├── __init__.py
        ├── config.py
        ├── main.py
        └── orchestrator.py
```

Each service can be started independently (e.g., `uvicorn app.main:app --reload`) or composed through Docker.

## Running with Docker Compose

1. Ensure Docker and Docker Compose are installed.
2. Copy environment examples (`.env.example`) to `.env` files for each service as needed.
3. Run `docker compose up --build` from this directory.

The compose stack exposes the gateway on `http://localhost:8000` and individual services on their respective ports.

## Porting Strategy

1. **Auth Service**
   - Move SQLAlchemy models and Pydantic schemas for users into `auth_service/app/models.py` and `auth_service/app/schemas.py`.
   - Extract authentication logic (token issuance, password hashing) into `auth_service/app/routers.py`.
   - Replace direct database imports in other services with HTTP calls to the auth service.

2. **Wardrobe Service**
   - Transfer clothes/outfit/location models, CRUD operations, and media handling to the wardrobe service.
   - Configure object storage or CDN integration in `app/media.py` and expose signed URLs to clients.

3. **AI Service**
   - Move Celery tasks and AI helper functions into `ai_service/app/tasks.py`.
   - Use `worker.py` to run the Celery worker. The FastAPI app exposes endpoints to submit and query jobs.

4. **Weather Service**
   - Wrap existing weather integrations (`services/http_client.py`) into `weather_service/app/http_client.py`.
   - Provide cached endpoints that can be consumed by the wardrobe service or gateway.

5. **Gateway**
   - Implement façade endpoints that orchestrate calls to downstream services, handling authentication tokens and aggregating responses.
   - Gradually strip business logic from the monolith and delegate to the specialized services.

## Next Steps

- Implement per-service migrations (e.g., Alembic) and CI pipelines.
- Introduce service discovery and secure inter-service communication (mTLS, JWT propagation).
- Set up shared observability (logging, tracing, metrics) by adapting the existing `observability.py` module.
- Define contract tests and consumer-driven tests to keep API contracts stable during refactors.

