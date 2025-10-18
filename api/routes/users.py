from fastapi import APIRouter, Depends, HTTPException
from typing import Optional
from sqlalchemy.orm import Session
import bcrypt
import jwt
import datetime
import models, schemas
from database import get_db

router = APIRouter(prefix="/users", tags=["Users"])

SECRET_KEY = "supersecretkey"
ALGORITHM = "HS256"

_MAX_BCRYPT_BYTES = 72
_MIN_PASSWORD_LENGTH = 6
_MAX_PASSWORD_LENGTH = 20
_PASSWORD_TOO_LONG_DETAIL = "Пароль слишком длинный. Максимальная длина — 72 байта."
_MIN_PIN_LENGTH = 4
_MAX_PIN_LENGTH = 8
_SUPPORTED_LANGUAGES = {"ru", "en"}


def _ensure_password_fits_backend(password: str) -> None:
    """Ensure the password length is compatible with business rules and bcrypt backend."""
    if not (_MIN_PASSWORD_LENGTH <= len(password) <= _MAX_PASSWORD_LENGTH):
        raise HTTPException(
            status_code=400,
            detail=f"Пароль должен содержать от {_MIN_PASSWORD_LENGTH} до {_MAX_PASSWORD_LENGTH} символов.",
        )
    if len(password.encode("utf-8")) > _MAX_BCRYPT_BYTES:
        raise HTTPException(
            status_code=400,
            detail=_PASSWORD_TOO_LONG_DETAIL,
        )


def _hash_password(password: str) -> str:
    try:
        hashed = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=_PASSWORD_TOO_LONG_DETAIL) from exc
    return hashed.decode("utf-8")


def _verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=_PASSWORD_TOO_LONG_DETAIL) from exc


def _normalize_pin(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None

    cleaned = value.strip()
    if not cleaned:
        return None

    if not cleaned.isdigit():
        raise HTTPException(status_code=400, detail="PIN-код должен содержать только цифры.")

    if not (_MIN_PIN_LENGTH <= len(cleaned) <= _MAX_PIN_LENGTH):
        raise HTTPException(
            status_code=400,
            detail=f"PIN-код должен содержать от {_MIN_PIN_LENGTH} до {_MAX_PIN_LENGTH} цифр.",
        )

    return cleaned


def _hash_pin(pin: str) -> str:
    try:
        hashed = bcrypt.hashpw(pin.encode("utf-8"), bcrypt.gensalt())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Не удалось сохранить PIN-код") from exc
    return hashed.decode("utf-8")


def _verify_pin(pin: str, pin_hash: str) -> bool:
    try:
        return bcrypt.checkpw(pin.encode("utf-8"), pin_hash.encode("utf-8"))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Не удалось проверить PIN-код") from exc


def _normalize_gender(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    normalized = value.strip().lower()
    if not normalized:
        return None

    male_markers = {"male", "m", "man", "м", "муж", "мужчина"}
    female_markers = {"female", "f", "woman", "ж", "жен", "женщина"}

    if normalized in male_markers:
        return "male"
    if normalized in female_markers:
        return "female"
    return normalized


def _normalize_theme(value: Optional[str]) -> str:
    if value is None:
        return "light"

    normalized = value.strip().lower()
    if not normalized:
        return "light"

    dark_markers = {
        "dark",
        "dark_mode",
        "dark theme",
        "темная",
        "тёмная",
        "ночная",
        "темная тема",
        "тёмная тема",
        "night",
    }

    return "dark" if normalized in dark_markers else "light"


def _normalize_language(value: Optional[str]) -> str:
    if value is None:
        return "ru"

    normalized = value.strip().lower()
    if not normalized:
        return "ru"

    if normalized in _SUPPORTED_LANGUAGES:
        return normalized

    raise HTTPException(
        status_code=400,
        detail=f"Неподдерживаемый код языка: {value}. Допустимые значения: {', '.join(sorted(_SUPPORTED_LANGUAGES))}",
    )


def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.datetime.utcnow() + datetime.timedelta(days=1)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)  # Здесь используем jwt.encode
    return encoded_jwt

@router.post("/register", response_model=schemas.UserResponse)
def register(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email уже зарегистрирован")

    _ensure_password_fits_backend(user.password)
    hashed_password = _hash_password(user.password)
    normalized_pin = _normalize_pin(user.pin_code)
    pin_hash = _hash_pin(normalized_pin) if normalized_pin else None
    new_user = models.User(
        name=user.name,
        email=user.email,
        password_hash=hashed_password,
        gender=_normalize_gender(user.gender),
        theme_preference=_normalize_theme(user.theme_preference),
        language_preference=_normalize_language(user.language_preference),
        pin_hash=pin_hash,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@router.post("/login")
def login(user: schemas.UserLogin, db: Session = Depends(get_db)):
    _ensure_password_fits_backend(user.password)

    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    auth_error = HTTPException(status_code=401, detail="Неверный email или пароль")

    if not db_user:
        raise auth_error

    password_matches = _verify_password(user.password, db_user.password_hash)

    if not password_matches:
        raise auth_error

    token = create_access_token({"sub": db_user.email})
    return {
        "access_token": token,
        "token_type": "bearer",
        "user_id": db_user.id,
        "has_pin": bool(db_user.pin_hash),
    }

@router.delete("/{user_id}")
def delete_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    db.delete(user)
    db.commit()
    return {"message": "Пользователь удалён"}

@router.get("/{user_id}", response_model=schemas.UserResponse)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    return user

@router.put("/{user_id}", response_model=schemas.UserResponse)
def update_user(user_id: int, updates: schemas.UserUpdate, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    if updates.name is not None:
        user.name = updates.name
    if updates.email is not None:
        user.email = updates.email
    if updates.password is not None:
        _ensure_password_fits_backend(updates.password)
        user.password_hash = _hash_password(updates.password)
    if updates.location is not None:
        user.location = updates.location
    if updates.gender is not None:
        user.gender = _normalize_gender(updates.gender)
    if updates.theme_preference is not None:
        user.theme_preference = _normalize_theme(updates.theme_preference)
    if updates.language_preference is not None:
        user.language_preference = _normalize_language(updates.language_preference)
    if updates.pin_code is not None:
        normalized_pin = _normalize_pin(updates.pin_code)
        user.pin_hash = _hash_pin(normalized_pin) if normalized_pin else None

    db.commit()
    db.refresh(user)
    return user

@router.put("/{user_id}/style")
def update_style(user_id: int, style: str, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    user.style_preference = style
    db.commit()
    return {"message": "Стиль обновлен", "style": style}
    
@router.put("/{user_id}/update_keys")
def update_keys(user_id: int, keys: schemas.ApiKeysUpdate, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    if keys.openai_api_key is not None:
        user.openai_api_key = keys.openai_api_key
    if keys.weather_api_key is not None:
        user.weather_api_key = keys.weather_api_key

    db.commit()
    db.refresh(user)
    return {"message": "API-ключи успешно обновлены"}


@router.post("/{user_id}/verify_pin")
def verify_pin(user_id: int, payload: schemas.PinVerificationRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    if not user.pin_hash:
        raise HTTPException(status_code=400, detail="PIN-код не установлен")

    pin = _normalize_pin(payload.pin_code)
    if pin is None:
        raise HTTPException(status_code=400, detail="PIN-код должен содержать цифры")

    if not _verify_pin(pin, user.pin_hash):
        raise HTTPException(status_code=401, detail="Неверный PIN-код")

    return {"valid": True}
