from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime


class UserCreate(BaseModel):
    name: str
    email: str
    password: str
    style_preference: Optional[str] = None
    openai_api_key: Optional[str] = None
    weather_api_key: Optional[str] = None

class UserLogin(BaseModel):
    email: str
    password: str
    
class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    style_preference: Optional[str] = None
    openai_api_key: Optional[str] = None
    weather_api_key: Optional[str] = None
    location: Optional[str] = None

    class Config:
        from_attributes = True

class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    #phone: Optional[str] = None
    password: Optional[str] = None
    location: Optional[str] = None
    
class ApiKeysUpdate(BaseModel):
    openai_api_key: Optional[str]
    weather_api_key: Optional[str]
    
    
class ClothesCreate(BaseModel):
    name: str
    category: str
    season: str
    color: str
    material: Optional[str] = None
    image_url: Optional[str] = None
    care_instructions: Optional[str] = None
    temperature_min: Optional[int] = None
    temperature_max: Optional[int] = None
    ai_metadata: Optional[dict] = None

class ClothesResponse(ClothesCreate):
    id: int
    user_id: int
    created_at: datetime

    class Config:
        from_attributes = True


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


class ClothesAutoFill(BaseModel):
    name: str
    category: str
    season: str
    color: str
    material: Optional[str] = None
    prompt_description: str
    care_instructions: Optional[str] = None
    ai_metadata: ClothesInsights
    temperature_min: Optional[int] = None
    temperature_max: Optional[int] = None


class WeatherSnapshot(BaseModel):
    temperature: int
    humidity: int
    condition: str
    wind_speed: Optional[int] = None


class MannequinItem(BaseModel):
    id: int
    name: str
    category: str
    color: str
    material: Optional[str] = None
    season: str
    prompt_description: Optional[str] = None

    class Config:
        from_attributes = True


class MannequinResponse(BaseModel):
    image_url: str
    weather: WeatherSnapshot
    items: List[MannequinItem]

class WeatherCreate(BaseModel):
    temperature: int
    humidity: int
    condition: str
    wind_speed: Optional[int] = None

class WeatherResponse(WeatherCreate):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True

class OutfitCreate(BaseModel):
    user_id: int
    weather_id: int
    clothing_ids: List[int]

class OutfitResponse(OutfitCreate):
    id: int
    created_at: datetime
    rating: Optional[int] = None

    class Config:
        from_attributes = True

class WearHistoryResponse(BaseModel):
    id: int
    user_id: int
    clothing_id: int
    worn_at: datetime

    class Config:
        from_attributes = True