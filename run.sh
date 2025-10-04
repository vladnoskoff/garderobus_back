#!/bin/bash

# Активируем виртуальное окружение (если используем)
# source venv/bin/activate  # Для Linux/Mac
# source venv/Scripts/activate  # Для Windows

# Загружаем переменные окружения из .env файла
export $(grep -v '^#' .env | xargs)

# Запускаем FastAPI сервер
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
