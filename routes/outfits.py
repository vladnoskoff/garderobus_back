from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
import models
import random
from routes.weather import get_weather_by_coordinates  # Импорт функции погоды
import schemas

router = APIRouter(prefix="/outfits", tags=["Outfits"])

@router.get("/{user_id}")
def get_outfit(user_id: int, db: Session = Depends(get_db)):
    """
    Выдаёт комплект одежды по погоде (использует координаты и API-ключ пользователя).
    """
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user or not user.location or not user.weather_api_key:
        raise HTTPException(status_code=400, detail="Нет координат или API-ключа пользователя")

    try:
        lat, lon = map(float, user.location.split(","))
    except Exception:
        raise HTTPException(status_code=400, detail="Неверный формат координат")

    # Получаем погоду по координатам и пользовательскому API-ключу
    weather_data = get_weather_by_coordinates(lat=lat, lon=lon, db=db, api_key=user.weather_api_key)
    if not weather_data:
        raise HTTPException(status_code=500, detail="Не удалось получить погоду")

    temperature = weather_data["temperature"]
    weather_id = weather_data["id"]

    # # Определяем сезон
    def get_season(temp):
        if temp >= 20:
            return "Лето"
        elif 10 <= temp < 20:
            return "Весна"
        elif 0 <= temp < 10:
            return "Осень"
        else:
            return "Зима"
    # def get_season(temp):
    #     if temp >= 20:
    #         return ["Лето"]
    #     elif 0 <= temp < 20:
    #         return ["Весна", "Осень"]
    #     else:
    #         return ["Зима"]

    current_season = get_season(temperature)

    # Получаем подходящую одежду пользователя
    clothes = db.query(models.Clothes).filter(models.Clothes.user_id == user_id).all()
    seasonal = [c for c in clothes if c.season.strip().lower() == current_season.lower()]
    # clothes = db.query(models.Clothes).filter(models.Clothes.user_id == user_id).all()
    # seasonal = [c for c in clothes if c.season.strip().lower() in [s.lower() for s in current_seasons]]


    def find_category(possible_names):
        matched = []
        for name in possible_names:
            for c in seasonal:
                if name.lower() in c.category.strip().lower():
                    matched.append(c)
        return random.choice(matched) if matched else None

    selected = {
        "головной убор": find_category(["кепка", "шапка", "панама"]),
        "верх": find_category(["футболка", "кофта", "куртка", "свитер", "рубашка"]),
        "низ": find_category(["штаны", "джинсы", "шорты"]),
        "обувь": find_category(["кроссовки", "ботинки", "туфли", "сланцы"]),
    }

    clothing_ids = [c.id for c in selected.values() if c]

    # Сохраняем образ
    outfit = models.Outfit(
        user_id=user_id,
        weather_id=weather_id,
        clothing_ids=clothing_ids
    )
    db.add(outfit)
    db.commit()
    db.refresh(outfit)

    return {
        "outfit_id": outfit.id,
        "temperature": temperature,
        "season": current_season,
        "items": {
            part: {
                "name": item.name,
                "category": item.category,
                "image_url": item.image_url
            } if item else "Нет подходящей вещи"
            for part, item in selected.items()
        }
    }



# @router.get("/history/{user_id}", response_model=list[schemas.OutfitResponse])
# def get_outfit_history(user_id: int, db: Session = Depends(get_db)):
#     """
#     Получение истории нарядов пользователя.

#     - **user_id**: Идентификатор пользователя.

#     Получает историю нарядов пользователя на основе ранее сохраненных данных.
#     """
#     outfits = db.query(models.Outfit).filter(models.Outfit.user_id == user_id).order_by(models.Outfit.created_at.desc()).all()
#     if not outfits:
#         raise HTTPException(status_code=404, detail="История нарядов пуста")
#     return outfits
    
# @router.put("/rate/{outfit_id}")
# def rate_outfit(outfit_id: int, rating: int, db: Session = Depends(get_db)):
#     """
#     Оценка наряда.

#     - **outfit_id**: Идентификатор наряда.
#     - **rating**: Оценка от 1 до 5 для наряда.

#     Обновляет рейтинг наряда, если он существует.
#     """
#     if rating < 1 or rating > 5:
#         raise HTTPException(status_code=400, detail="Рейтинг должен быть от 1 до 5")

#     outfit = db.query(models.Outfit).filter(models.Outfit.id == outfit_id).first()
#     if not outfit:
#         raise HTTPException(status_code=404, detail="Наряд не найден")

#     outfit.rating = rating
#     db.commit()
#     return {"message": "Рейтинг обновлён", "rating": rating}
