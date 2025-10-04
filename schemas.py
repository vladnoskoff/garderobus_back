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

class ClothesResponse(ClothesCreate):
    id: int
    user_id: int
    created_at: datetime

    class Config:
        from_attributes = True

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
