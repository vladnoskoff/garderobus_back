from typing import Any, Dict, List, Optional
from datetime import datetime

from pydantic import AliasChoices, BaseModel, Field, root_validator


class TaskSubmissionResponse(BaseModel):
    task_id: str
    status_url: Optional[str] = None


class TaskErrorPayload(BaseModel):
    status_code: int
    detail: str


class TaskStatusResponse(BaseModel):
    task_id: str
    status: str
    result: Optional[Dict[str, Any]] = None
    error: Optional[TaskErrorPayload] = None
    retries: int = 0


class UserCreate(BaseModel):
    name: str
    email: str
    password: str
    phone: Optional[str] = None
    style_preference: Optional[str] = None
    gender: Optional[str] = None
    theme_preference: Optional[str] = None
    pin_code: Optional[str] = Field(
        default=None, validation_alias=AliasChoices("pin_code", "pinCode")
    )
    language_preference: Optional[str] = None

    @root_validator(pre=True)
    def _alias_pin_code(cls, values: Dict[str, Any]) -> Dict[str, Any]:
        """Support both snake_case and camelCase pin fields."""
        if "pin_code" not in values and "pinCode" in values:
            values["pin_code"] = values["pinCode"]
        return values


class UserLogin(BaseModel):
    email: str
    password: str


class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    phone: Optional[str] = None
    style_preference: Optional[str] = None
    location: Optional[str] = None
    gender: Optional[str] = None
    theme_preference: Optional[str] = None
    has_pin: bool = False
    language_preference: Optional[str] = "ru"

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    password: Optional[str] = None
    location: Optional[str] = None
    gender: Optional[str] = None
    theme_preference: Optional[str] = None
    pin_code: Optional[str] = Field(
        default=None, validation_alias=AliasChoices("pin_code", "pinCode")
    )
    language_preference: Optional[str] = None

    @root_validator(pre=True)
    def _alias_pin_code(cls, values: Dict[str, Any]) -> Dict[str, Any]:
        if "pin_code" not in values and "pinCode" in values:
            values["pin_code"] = values["pinCode"]
        return values


class PinVerificationRequest(BaseModel):
    pin_code: str


class ClothesCreate(BaseModel):
    name: str
    category: str
    season: str
    color: str
    material: Optional[str] = None
    image_url: Optional[str] = None
    prompt_description: Optional[str] = None
    care_instructions: Optional[str] = None
    temperature_min: Optional[int] = None
    temperature_max: Optional[int] = None
    ai_metadata: Optional[dict] = None
    location_id: Optional[int] = None
    image_gallery: List[str] = Field(default_factory=list)


class ClothesResponse(ClothesCreate):
    id: int
    user_id: int
    created_at: datetime

    class Config:
        from_attributes = True


class ClothesUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    season: Optional[str] = None
    color: Optional[str] = None
    material: Optional[str] = None
    prompt_description: Optional[str] = None
    care_instructions: Optional[str] = None
    temperature_min: Optional[int] = None
    temperature_max: Optional[int] = None
    ai_metadata: Optional[dict] = None
    location_id: Optional[int] = None


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


class StoredMannequinResponse(BaseModel):
    id: int
    user_id: int
    image_url: str
    location_id: Optional[int] = None
    created_at: datetime
    items: List[MannequinItem] = Field(default_factory=list)
    weather: Optional[WeatherSnapshot] = None

    class Config:
        from_attributes = True


class WardrobeLocationBase(BaseModel):
    name: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class WardrobeLocationCreate(WardrobeLocationBase):
    pass


class AdminUserUsageItem(BaseModel):
    clothing_id: int
    name: str
    usage_count: int


class AdminUserSummary(BaseModel):
    id: int
    name: str
    email: str
    phone: Optional[str] = None
    total_clothes: int
    total_clothes_images: int
    total_mannequins: int
    total_outfits: int
    total_wear_events: int
    wear_events_last_30_days: int
    new_clothes_last_30_days: int
    last_wear_at: Optional[datetime] = None
    last_mannequin_at: Optional[datetime] = None
    top_worn_items: List[AdminUserUsageItem] = Field(default_factory=list)
    locations_count: int = 0
    pending_metadata_items: int = 0


class AdminUserLocationDetail(BaseModel):
    id: Optional[int]
    name: str
    created_at: Optional[datetime] = None
    total_clothes: int
    new_clothes_last_30_days: int
    total_clothes_images: int
    total_wear_events: int
    mannequins_generated: int
    pending_metadata_items: int
    is_virtual: bool = False


class AdminUserDetail(AdminUserSummary):
    theme_preference: str
    language_preference: str
    gender: Optional[str] = None
    has_pin: bool = False
    locations: List[AdminUserLocationDetail] = Field(default_factory=list)



class AdminManagedFileList(BaseModel):
    files: List[str] = Field(default_factory=list)


class AdminSystemStatus(BaseModel):
    uptime_seconds: float = Field(..., ge=0)
    uptime_human: str
    restart_supported: bool
    worker_restart_supported: bool = False
    last_restart_requested_at: Optional[datetime] = None
    managed_files: List[str] = Field(default_factory=list)
    app_name: str
    app_version: str
    environment: str
    maintenance_enabled: bool = False
    maintenance_supported: bool = False
    test_webhook_configured: bool = False


class AdminCodeFile(BaseModel):
    path: str
    content: str


class AdminCodeUpdateRequest(BaseModel):
    content: str
    message: Optional[str] = None


class AdminRestartResponse(BaseModel):
    success: bool = True
    detail: str
    pid: Optional[int] = None


class AdminActionResponse(BaseModel):
    success: bool = True
    detail: str
    error: Optional[str] = None


class AdminMaintenanceRequest(BaseModel):
    enabled: bool


class AdminSystemEvent(BaseModel):
    timestamp: datetime
    level: str
    message: str
    logger: Optional[str] = None
    service: Optional[str] = None
    context: dict[str, Any] = Field(default_factory=dict)


class AdminSystemEventList(BaseModel):
    events: List[AdminSystemEvent] = Field(default_factory=list)
    total: int = 0
    page: int = 1
    limit: int = 50


class AdminActivityMetrics(BaseModel):
    active_now: int = 0
    active_24h: int = 0
    platform_breakdown: dict[str, int] = Field(default_factory=dict)


class WardrobeLocationUpdate(BaseModel):
    name: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class WardrobeLocationResponse(WardrobeLocationBase):
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
