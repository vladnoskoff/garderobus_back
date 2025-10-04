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
from pyuploadcare import Uploadcare
import io



client = OpenAI(api_key=settings.OPENAI_API_KEYY)
router = APIRouter(prefix="/clothes", tags=["Clothes"])

UPLOAD_DIR = "/www/wwwroot/api/chkaf/clothes_images"
os.makedirs(UPLOAD_DIR, exist_ok=True)

uploadcare = Uploadcare(public_key=settings.UPLOADCARE_PUBLIC_KEY, secret_key=settings.UPLOADCARE_SECRET_KEY)


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
    try:
        # Читаем байты
        file_data = await file.read()

        # Загрузка через Uploadcare 6.1.0
        upload_result = uploadcare.upload_api.upload_bytes(file_data, file_name=file.filename)
        image_url = upload_result.cdn_url

        # Описание (упрощённое)
        prompt_description = f"Название: {name}, Категория: {category}"

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
        raise HTTPException(status_code=500, detail=f"Ошибка при загрузке в Uploadcare: {str(e)}")


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

    # Удаляем файл из Uploadcare
    try:
        if clothes.image_url and "ucarecdn.com" in clothes.image_url:
            uuid = clothes.image_url.split("/")[-2]  # https://ucarecdn.com/<uuid>/<filename>
            uploadcare.file(uuid).delete()
    except Exception as e:
        print(f"Ошибка удаления с Uploadcare: {e}")

    # Удаляем запись из БД
    db.delete(clothes)
    db.commit()
    return {"message": "Одежда и изображение удалены"}
