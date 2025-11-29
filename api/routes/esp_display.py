from fastapi import APIRouter, HTTPException
from api import settings
from services.http_client import (
    CircuitOpenError,
    HTTPRequestError,
    RateLimitExceededError,
    http_client,
)

router = APIRouter(prefix="/esp", tags=["ESP Display"])

ESP_DISPLAY_IP = settings.ESP_DISPLAY_IP

@router.get("/show-outfit/{user_id}")
def send_outfit_to_display(user_id: int):
    """Отправка изображения наряда на экран ESP32"""
    try:
        response = http_client.get(
            f"http://localhost:8000/ai/visual-recommendation/{user_id}",
            service_name="recommendation",
        )
        response.raise_for_status()
        image_url = response.json()["image_url"]

        esp_response = http_client.post(
            f"{ESP_DISPLAY_IP}/display",
            json={"image_url": image_url},
            service_name="esp-display",
        )
        esp_response.raise_for_status()
    except RateLimitExceededError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc
    except (CircuitOpenError, HTTPRequestError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Ошибка интеграции с ESP32") from exc

    return {"message": "Изображение отправлено на дисплей"}
