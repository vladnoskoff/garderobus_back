import datetime
import logging
import uuid
from typing import Optional

import bcrypt
import jwt
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

import models, schemas
import settings
from cache import cache
from database import get_db
from logging_config import mask_sensitive_data
from observability import get_rate_limiter, record_auth_failure, record_auth_lockout
from opentelemetry import trace

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/users", tags=["Users"])
limiter = get_rate_limiter()

_MAX_BCRYPT_BYTES = 72
_MIN_PASSWORD_LENGTH = 6
_MAX_PASSWORD_LENGTH = 20
_PASSWORD_TOO_LONG_DETAIL = "Пароль слишком длинный. Максимальная длина — 72 байта."
_MIN_PIN_LENGTH = 4
_MAX_PIN_LENGTH = 8
_SUPPORTED_LANGUAGES = {"ru", "en"}

_ACCESS_TOKEN_TTL = datetime.timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
_REFRESH_TOKEN_TTL = datetime.timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)


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


def _normalize_phone(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None

    cleaned = value.strip()
    if not cleaned or cleaned.lower() in {"null", "undefined"}:
        return None

    return cleaned


def _get_client_ip(request: Request) -> str:
    if request.client is None:
        return "unknown"
    return request.client.host


def _auth_key(prefix: str, value: str) -> str:
    return cache.make_key("auth", prefix, value)


def _is_blocked(ip_address: str, email: str) -> Optional[str]:
    ip_block = cache.get_json(_auth_key("blocked_ip", ip_address), resource="auth")
    if ip_block:
        return "ip"
    user_block = cache.get_json(_auth_key("blocked_user", email), resource="auth")
    if user_block:
        return "user"
    return None


def _block(identifier: str, dimension: str) -> None:
    cache.set_json(
        _auth_key(f"blocked_{dimension}", identifier),
        True,
        ttl=settings.AUTH_LOCKOUT_SECONDS,
        resource="auth",
    )
    record_auth_lockout(dimension)


def _clear_failures(ip_address: str, email: str) -> None:
    for dimension, value in {"ip_fail": ip_address, "user_fail": email}.items():
        cache.delete(_auth_key(dimension, value))


def _register_failure(ip_address: str, email: str) -> None:
    ip_attempts = cache.increment(
        _auth_key("ip_fail", ip_address), settings.AUTH_FAILED_ATTEMPT_WINDOW_SECONDS
    )
    user_attempts = cache.increment(
        _auth_key("user_fail", email), settings.AUTH_FAILED_ATTEMPT_WINDOW_SECONDS
    )

    if ip_attempts >= settings.AUTH_FAILED_ATTEMPT_LIMIT:
        _block(ip_address, "ip")
    if user_attempts >= settings.AUTH_FAILED_ATTEMPT_LIMIT:
        _block(email, "user")

    suspicious_attempts = cache.increment(
        _auth_key("ip_suspicious", ip_address), settings.AUTH_SUSPICIOUS_IP_WINDOW_SECONDS
    )
    if suspicious_attempts >= settings.AUTH_SUSPICIOUS_IP_LIMIT:
        _block(ip_address, "ip")


def _persist_refresh_jti(user_id: int, jti: str) -> None:
    cache.set_json(
        _auth_key("refresh", user_id),
        {"jti": jti},
        ttl=int(_REFRESH_TOKEN_TTL.total_seconds()),
        resource="auth",
    )


def _get_active_refresh_jti(user_id: int) -> Optional[str]:
    payload = cache.get_json(_auth_key("refresh", user_id), resource="auth")
    if not payload:
        return None
    return payload.get("jti")


def _create_token(data: dict, ttl: datetime.timedelta, token_type: str, jti: str | None = None) -> str:
    to_encode = data.copy()
    expire = datetime.datetime.utcnow() + ttl
    to_encode.update({"exp": expire, "iat": datetime.datetime.utcnow(), "type": token_type})
    if jti:
        to_encode["jti"] = jti
    encoded_jwt = jwt.encode(
        to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM
    )
    return encoded_jwt


def _create_access_token(user: models.User) -> tuple[str, int]:
    token = _create_token({"sub": user.id, "email": user.email}, _ACCESS_TOKEN_TTL, "access")
    return token, int(_ACCESS_TOKEN_TTL.total_seconds())


def _create_refresh_token(user: models.User, jti: str) -> tuple[str, int]:
    token = _create_token(
        {"sub": user.id, "email": user.email}, _REFRESH_TOKEN_TTL, "refresh", jti=jti
    )
    return token, int(_REFRESH_TOKEN_TTL.total_seconds())


def _issue_token_pair(user: models.User) -> schemas.TokenPair:
    refresh_jti = str(uuid.uuid4())
    refresh_token, refresh_expires_in = _create_refresh_token(user, refresh_jti)
    _persist_refresh_jti(user.id, refresh_jti)
    access_token, access_expires_in = _create_access_token(user)

    return schemas.TokenPair(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        access_expires_in=access_expires_in,
        refresh_expires_in=refresh_expires_in,
        user_id=user.id,
        has_pin=bool(user.pin_hash),
    )


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
        phone=_normalize_phone(user.phone),
        password_hash=hashed_password,
        openai_api_key=settings.OPENAI_API_KEY,
        weather_api_key=settings.OPENWEATHER_API_KEY,
        location=settings.DEFAULT_USER_LOCATION,
        gender=_normalize_gender(user.gender),
        theme_preference=_normalize_theme(user.theme_preference),
        language_preference=_normalize_language(user.language_preference),
        pin_hash=pin_hash,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    trace.get_current_span().set_attributes({"user.id": new_user.id, "user.email": new_user.email})
    logger.info("User registered", extra={"user_id": new_user.id, "email": new_user.email})
    return new_user

@router.post("/login", response_model=schemas.TokenPair)
@limiter.limit(settings.API_RATE_LIMIT)
def login(user: schemas.UserLogin, request: Request, db: Session = Depends(get_db)):
    _ensure_password_fits_backend(user.password)
    client_ip = _get_client_ip(request)
    sanitized_payload = mask_sensitive_data(user.model_dump())
    trace.get_current_span().set_attributes({"auth.email": user.email, "auth.client_ip": client_ip})

    if blocked := _is_blocked(client_ip, user.email):
        record_auth_failure("blocked")
        logger.warning(
            "Login blocked due to lockout",
            extra={"client_ip": client_ip, "email": user.email},
        )
        raise HTTPException(
            status_code=429,
            detail="Слишком много попыток входа. Попробуйте позже",
            headers={"Retry-After": str(settings.AUTH_LOCKOUT_SECONDS)},
        )

    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    auth_error = HTTPException(status_code=401, detail="Неверный email или пароль")

    if not db_user:
        _register_failure(client_ip, user.email)
        record_auth_failure("user_not_found")
        logger.warning(
            "Login failed: user not found",
            extra={"client_ip": client_ip, "payload": sanitized_payload},
        )
        raise auth_error

    password_matches = _verify_password(user.password, db_user.password_hash)

    if not password_matches:
        _register_failure(client_ip, user.email)
        record_auth_failure("invalid_credentials")
        logger.warning(
            "Login failed: wrong password",
            extra={"client_ip": client_ip, "payload": sanitized_payload},
        )
        raise auth_error

    _clear_failures(client_ip, user.email)
    trace.get_current_span().set_attributes({"user.id": db_user.id, "user.email": db_user.email})
    logger.info(
        "Login succeeded",
        extra={"user_id": db_user.id, "email": db_user.email, "client_ip": client_ip},
    )
    return _issue_token_pair(db_user)


@router.post("/refresh", response_model=schemas.TokenPair)
@limiter.limit(settings.API_RATE_LIMIT)
def refresh_tokens(
    payload: schemas.RefreshRequest, request: Request, db: Session = Depends(get_db)
):
    sanitized_payload = mask_sensitive_data(payload.model_dump())
    trace.get_current_span().set_attribute("auth.refresh_present", bool(payload.refresh_token))
    try:
        decoded = jwt.decode(
            payload.refresh_token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
    except jwt.ExpiredSignatureError as exc:
        record_auth_failure("refresh_expired")
        raise HTTPException(status_code=401, detail="Refresh токен истёк") from exc
    except jwt.PyJWTError as exc:
        record_auth_failure("refresh_invalid")
        raise HTTPException(status_code=401, detail="Недействительный refresh токен") from exc

    if decoded.get("type") != "refresh":
        raise HTTPException(status_code=400, detail="Ожидался refresh токен")

    user_id = decoded.get("sub")
    jti = decoded.get("jti")
    if user_id is None or jti is None:
        logger.warning("Refresh failed: missing subject", extra={"payload": sanitized_payload})
        raise HTTPException(status_code=400, detail="Refresh токен неполный")

    try:
        user_id_int = int(user_id)
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=400, detail="Некорректный идентификатор пользователя") from exc

    active_jti = _get_active_refresh_jti(user_id_int)
    if active_jti != jti:
        record_auth_failure("refresh_reuse")
        _block(_get_client_ip(request), "ip")
        logger.warning(
            "Refresh reuse detected",
            extra={"user_id": user_id, "payload": sanitized_payload},
        )
        raise HTTPException(status_code=401, detail="Refresh токен недействителен")

    user = db.query(models.User).filter(models.User.id == user_id_int).first()
    if not user:
        logger.warning("Refresh failed: user missing", extra={"user_id": user_id_int})
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    _clear_failures(_get_client_ip(request), user.email)
    trace.get_current_span().set_attributes({"user.id": user.id, "user.email": user.email})
    logger.info("Tokens refreshed", extra={"user_id": user.id, "email": user.email})
    return _issue_token_pair(user)

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
    if updates.phone is not None:
        user.phone = _normalize_phone(updates.phone)
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
