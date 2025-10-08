from fastapi import FastAPI, HTTPException, Depends, Body, APIRouter
from fastapi.staticfiles import StaticFiles

import models
from database import engine
from routes import (
    users,
    clothes,
    outfits,
    weather,
    ai_recommendation,
    wardrobe_analytics,
    esp_display,
    testgpt,
    locations,
)
from fastapi.middleware.cors import CORSMiddleware

import settings

models.Base.metadata.create_all(bind=engine)

app = FastAPI()

# Разрешаем CORS для всех источников
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount(
    "/clothes_images",
    StaticFiles(directory=str(settings.CLOTHES_IMAGE_DIR)),
    name="clothes_images",
)
app.mount(
    "/mannequins",
    StaticFiles(directory=str(settings.MANNEQUIN_IMAGE_DIR)),
    name="mannequins",
)

app.include_router(users.router)
app.include_router(clothes.router)
app.include_router(outfits.router)
app.include_router(weather.router)
app.include_router(ai_recommendation.router)
app.include_router(wardrobe_analytics.router)
app.include_router(esp_display.router)
app.include_router(testgpt.router)
app.include_router(locations.router)

@app.get("/")
def read_root():
    return {"message": "Smart Closet API is running!"}
