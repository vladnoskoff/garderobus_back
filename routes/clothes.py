from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from datetime import datetime
import models
from database import get_db
import shutil
import os
import base64
import requests
import settings
import schemas
from openai import OpenAI

client = OpenAI(api_key=settings.OPENAI_API_KEYY)
router = APIRouter(prefix="/clothes", tags=["Clothes"])

UPLOAD_DIR = "/www/wwwroot/api/chkaf/clothes_images"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.get("/user/{user_id}", response_model=list[schemas.ClothesResponse])
def get_user_clothes(user_id: int, db: Session = Depends(get_db)):
    return db.query(models.Clothes).filter(models.Clothes.user_id == user_id).all()
    
async def describe_image_from_url(image_url: str) -> str:
    prompt_text = "Опиши в одном абзаце этот предмет одежды: укажи тип, материал, цвет, особенности дизайна и, если есть, логотип или надпись."
    
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {
                "role": "system",
                "content": "Ты модный стилист, который профессионально описывает одежду по фото."
            },
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt_text},
                    {"type": "image_url", "image_url": {"url": image_url}}
                ]
            }
        ],
        max_tokens=500
    )

    return response.choices[0].message.content.strip()

@router.post("/", response_model=schemas.ClothesResponse)
async def add_clothes(
    user_id: int = Form(...),
    name: str = Form(...),
    category: str = Form(...),
    season: str = Form(...),
    color: str = Form(...),
    material: str = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Упрощённое добавление одежды без GPT: описание формируется по названию и категории.
    """
    try:
        # Сохраняем файл
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        filename = f"{timestamp}_{file.filename}"
        file_path = os.path.join(UPLOAD_DIR, filename)

        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        image_url = f"http://aapanel-api.noksovsteam.ru/chkaf/clothes_images/{filename}"

        # Упрощённое описание
        prompt_description = f"Название: {name}, Категория: {category}"
        # Генерируем описание на основе изображения
        #prompt_description = await describe_image_from_url(image_url)

        # Сохраняем в БД
        new_clothes = models.Clothes(
            user_id=user_id,
            name=name,
            category=category,
            season=season,
            color=color,
            material=material,
            image_url=image_url,
            prompt_description=prompt_description
        )
        db.add(new_clothes)
        db.commit()
        db.refresh(new_clothes)
        return new_clothes

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка при добавлении одежды: {str(e)}")

@router.get("/", response_model=list[schemas.ClothesResponse])
def get_all_clothes(db: Session = Depends(get_db)):
    return db.query(models.Clothes).all()

@router.get("/{clothes_id}", response_model=schemas.ClothesResponse)
def get_clothes(clothes_id: int, db: Session = Depends(get_db)):
    clothes = db.query(models.Clothes).filter(models.Clothes.id == clothes_id).first()
    if not clothes:
        raise HTTPException(status_code=404, detail="Одежда не найдена")
    return clothes

@router.delete("/{clothes_id}")
def delete_clothes(clothes_id: int, db: Session = Depends(get_db)):
    clothes = db.query(models.Clothes).filter(models.Clothes.id == clothes_id).first()
    if not clothes:
        raise HTTPException(status_code=404, detail="Одежда не найдена")
    db.delete(clothes)
    db.commit()
    return {"message": "Одежда удалена"}