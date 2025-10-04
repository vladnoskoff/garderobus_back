import requests
from fastapi import APIRouter, HTTPException
import settings

router = APIRouter(prefix="/esp", tags=["ESP Display"])

ESP_DISPLAY_IP = settings.ESP_DISPLAY_IP

@router.get("/show-outfit/{user_id}")
def send_outfit_to_display(user_id: int):
    """Отправка изображения наряда на экран ESP32"""
    response = requests.get(f"http://localhost:8000/ai/visual-recommendation/{user_id}")
    if response.status_code != 200:
        raise HTTPException(status_code=500, detail="Ошибка генерации изображения")

    image_url = response.json()["image_url"]

    # Отправляем изображение на ESP32
    esp_response = requests.post(f"{ESP_DISPLAY_IP}/display", json={"image_url": image_url})
    if esp_response.status_code != 200:
        raise HTTPException(status_code=500, detail="Ошибка отправки изображения на ESP32")

    return {"message": "Изображение отправлено на дисплей"}
