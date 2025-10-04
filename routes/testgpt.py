# routes/testgpt.py
import base64
import json
import logging
import os
from typing import List, Optional

from fastapi import APIRouter, File, Form, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ValidationError
from openai import OpenAI

# Если используешь SOCKS-прокси (как в твоём примере):
# pip install httpx httpx-socks
try:
    import httpx
    from httpx_socks import SyncProxyTransport
    USE_SOCKS = True
except Exception:
    httpx = None
    SyncProxyTransport = None
    USE_SOCKS = False

router = APIRouter(prefix="/ai", tags=["AI Test"])
log = logging.getLogger("ai_test")
logging.basicConfig(level=logging.INFO)

# ========= НАСТРОЙКИ =========
# 1) Впиши сюда ключ (или оставь пустым и используй переменную окружения OPENAI_API_KEY)
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "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")

# 2) Включить SOCKS-прокси? (если у тебя xray/локальный socks5)
SOCKS_PROXY_URL = os.getenv("SOCKS_PROXY", "socks5://127.0.0.1:10808")
ENABLE_SOCKS = USE_SOCKS and bool(SOCKS_PROXY_URL)
# ============================

if not OPENAI_API_KEY or not OPENAI_API_KEY.startswith("sk-"):
    raise RuntimeError("Укажи корректный OPENAI_API_KEY (строка, начинающаяся с 'sk-').")

# Настраиваем httpx-клиент с SOCKS-прокси при необходимости
if ENABLE_SOCKS:
    transport = SyncProxyTransport.from_url(SOCKS_PROXY_URL, rdns=True)
    httpx_client = httpx.Client(transport=transport, timeout=60.0)
    client = OpenAI(api_key=OPENAI_API_KEY, http_client=httpx_client)
else:
    client = OpenAI(api_key=OPENAI_API_KEY)

# ----- Pydantic модель ответа -----
class ClothesInsights(BaseModel):
    title: str
    category: str
    gender: Optional[str] = None
    colors: List[str]
    pattern: Optional[str] = None
    material: Optional[str] = None
    fit: Optional[str] = None
    season: List[str]
    temp_c_range: List[int]
    style: List[str]
    occasions: List[str]
    care: Optional[str] = None
    tags: List[str]
    catalog_description: str
    gen_prompt: str
    pairing_hints: List[str]

SYSTEM_INSTRUCTIONS = (
    "You are a fashion product analyst. Identify garment details strictly from the image. "
    "Return ONLY valid JSON that matches the provided JSON Schema."
)

JSON_SCHEMA = {
    "type": "object",
    "properties": {
        "title": {"type": "string"},
        "category": {"type": "string"},
        "gender": {"type": ["string", "null"]},
        "colors": {"type": "array", "items": {"type": "string"}},
        "pattern": {"type": ["string", "null"]},
        "material": {"type": ["string", "null"]},
        "fit": {"type": ["string", "null"]},
        "season": {"type": "array", "items": {"type": "string"}},
        "temp_c_range": {
            "type": "array",
            "items": {"type": "integer"},
            "minItems": 2,
            "maxItems": 2
        },
        "style": {"type": "array", "items": {"type": "string"}},
        "occasions": {"type": "array", "items": {"type": "string"}},
        "care": {"type": ["string", "null"]},
        "tags": {"type": "array", "items": {"type": "string"}},
        "catalog_description": {"type": "string"},
        "gen_prompt": {"type": "string"},
        "pairing_hints": {"type": "array", "items": {"type": "string"}}
    },
    # ВАЖНО: перечисляем ВСЕ ключи из properties
    "required": [
        "title",
        "category",
        "gender",
        "colors",
        "pattern",
        "material",
        "fit",
        "season",
        "temp_c_range",
        "style",
        "occasions",
        "care",
        "tags",
        "catalog_description",
        "gen_prompt",
        "pairing_hints"
    ],
    "additionalProperties": False
}
def _build_messages(image_url_or_b64: str, is_b64: bool):
    img_part = (
        {"type": "image_url", "image_url": {"url": image_url_or_b64}}
        if not is_b64 else
        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_url_or_b64}"}}
    )
    return [
        {"role": "system", "content": SYSTEM_INSTRUCTIONS},
        {
            "role": "user",
            "content": [
                {"type": "text", "text": (
                    "Проанализируй одежду и верни JSON по схеме. "
                    "Сформируй лаконичный 'catalog_description' и нейтральный 'gen_prompt' для манекена "
                    "(студийный свет, белый фон, без логотипов/текста). Добавь 3–5 'pairing_hints'."
                )},
                img_part
            ]
        }
    ]

def _call_vision(messages) -> str:
    resp = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=messages,
        response_format={
            "type": "json_schema",
            "json_schema": {"name": "ClothesInsights", "schema": JSON_SCHEMA, "strict": True}
        },
        temperature=0.2,
    )
    msg = resp.choices[0].message
    return msg.content if msg else ""

@router.get("/ping")
def ping():
    return {
        "status": "ok",
        "proxy": SOCKS_PROXY_URL if ENABLE_SOCKS else None,
        "message": "AI test route is working"
    }

# ==== 1) Строгий эндпоинт: типизированный ответ ====
@router.post("/analyze", response_model=ClothesInsights)
async def analyze_image(
    image_url: Optional[str] = Form(
        None,
        example="https://upload.wikimedia.org/wikipedia/commons/6/6e/Golde33443.jpg"
    ),
    file: Optional[bytes] = File(None),   # <-- bytes вместо UploadFile
):
    if not image_url and not file:
        raise HTTPException(status_code=400, detail="Provide image_url or file")

    # Готовим полезную нагрузку
    if image_url:
        payload, is_b64 = image_url, False
    else:
        if not file or len(file) == 0:
            raise HTTPException(status_code=400, detail="Empty file")
        payload, is_b64 = base64.b64encode(file).decode("utf-8"), True

    # Вызов модели
    try:
        raw = _call_vision(_build_messages(payload, is_b64))
    except Exception as e:
        log.exception("OpenAI call failed")
        raise HTTPException(status_code=502, detail=f"AI call failed: {e}")

    if not raw:
        raise HTTPException(status_code=502, detail="AI returned empty response")

    # Валидация по схеме
    try:
        return ClothesInsights.model_validate_json(raw)
    except ValidationError as ve:
        raise HTTPException(
            status_code=422,
            detail={
                "error": "Response schema validation failed",
                "pydantic_errors": ve.errors(),
                "raw": raw[:2000],
            },
        )

# ==== 2) Невалидируемый эндпоинт: отдаёт «как есть» ====
@router.post("/analyze_raw")
async def analyze_image_raw(
    image_url: Optional[str] = Form(
        None,
        example="https://upload.wikimedia.org/wikipedia/commons/6/6e/Golde33443.jpg"
    ),
    file: Optional[bytes] = File(None),   # <-- bytes вместо UploadFile
):
    if not image_url and not file:
        raise HTTPException(status_code=400, detail="Provide image_url or file")

    if image_url:
        payload, is_b64 = image_url, False
    else:
        if not file or len(file) == 0:
            raise HTTPException(status_code=400, detail="Empty file")
        payload, is_b64 = base64.b64encode(file).decode("utf-8"), True

    raw = _call_vision(_build_messages(payload, is_b64))
    if not raw:
        raise HTTPException(status_code=502, detail="AI returned empty response")

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return JSONResponse(content={"raw_text": raw})