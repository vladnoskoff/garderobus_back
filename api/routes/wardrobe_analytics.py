from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy.sql import func
from datetime import datetime, timedelta
import models
from database import get_db

router = APIRouter(prefix="/analytics", tags=["Wardrobe Analytics"])

@router.get("/most_worn/{user_id}")
def most_worn_clothes(user_id: int, db: Session = Depends(get_db)):
    """Возвращает список самых часто используемых вещей"""
    result = db.query(
        models.Clothes.id, models.Clothes.name, func.count(models.WearHistory.id).label("count")
    ).join(models.WearHistory).filter(models.WearHistory.user_id == user_id).group_by(models.Clothes.id).order_by(func.count(models.WearHistory.id).desc()).limit(5).all()

    return [{"id": r[0], "name": r[1], "count": r[2]} for r in result]

@router.get("/least_worn/{user_id}")
def least_worn_clothes(user_id: int, db: Session = Depends(get_db)):
    """Возвращает список вещей, которые не использовались больше 30 дней"""
    threshold_date = datetime.utcnow() - timedelta(days=30)

    result = db.query(models.Clothes.id, models.Clothes.name).filter(
        models.Clothes.user_id == user_id,
        ~models.Clothes.id.in_(
            db.query(models.WearHistory.clothing_id)
            .filter(models.WearHistory.user_id == user_id, models.WearHistory.worn_at > threshold_date)
        )
    ).all()

    return [{"id": r[0], "name": r[1]} for r in result]
