from typing import Any, Dict, List, Literal, Optional
from datetime import datetime

from pydantic import (
    AliasChoices,
    BaseModel,
    EmailStr,
    Field,
    field_validator,
    model_validator,
)


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
    name: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=20)
    phone: Optional[str] = Field(default=None, pattern=r"^[+\d][\d\-\s]{6,20}$")
    style_preference: Optional[str] = Field(default=None, max_length=64)
    gender: Optional[Literal["male", "female", "other"]] = None
    theme_preference: Optional[Literal["light", "dark"]] = None
    pin_code: Optional[str] = Field(
        default=None,
        min_length=4,
        max_length=8,
        pattern=r"^\d{4,8}$",
        validation_alias=AliasChoices("pin_code", "pinCode"),
    )
    language_preference: Optional[Literal["ru", "en"]] = None

    @model_validator(mode="before")
    def _alias_pin_code(cls, values: Dict[str, Any]) -> Dict[str, Any]:
        """Support both snake_case and camelCase pin fields."""
        if "pin_code" not in values and "pinCode" in values:
            values["pin_code"] = values["pinCode"]
        return values

    @field_validator("name")
    def _strip_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("name must not be empty")
        return cleaned

    @field_validator("password")
    def _password_without_spaces(cls, value: str) -> str:
        if " " in value:
            raise ValueError("password must not contain spaces")
        return value

    @field_validator("language_preference", "theme_preference", mode="before")
    def _lowercase_values(cls, value: Optional[str]) -> Optional[str]:
        return value.lower() if isinstance(value, str) else value


class UserLogin(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=20)


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    access_expires_in: int
    refresh_expires_in: int
    user_id: int
    has_pin: bool = False


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
    name: Optional[str] = Field(default=None, min_length=2, max_length=100)
    email: Optional[EmailStr] = None
    phone: Optional[str] = Field(default=None, pattern=r"^[+\d][\d\-\s]{6,20}$")
    password: Optional[str] = Field(default=None, min_length=6, max_length=20)
    location: Optional[str] = Field(default=None, max_length=255)
    gender: Optional[Literal["male", "female", "other"]] = None
    theme_preference: Optional[Literal["light", "dark"]] = None
    pin_code: Optional[str] = Field(
        default=None,
        min_length=4,
        max_length=8,
        pattern=r"^\d{4,8}$",
        validation_alias=AliasChoices("pin_code", "pinCode"),
    )
    language_preference: Optional[Literal["ru", "en"]] = None

    @model_validator(mode="before")
    def _alias_pin_code(cls, values: Dict[str, Any]) -> Dict[str, Any]:
        if "pin_code" not in values and "pinCode" in values:
            values["pin_code"] = values["pinCode"]
        return values

    @field_validator("name")
    def _strip_name(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("name must not be empty")
        return cleaned

    @field_validator("language_preference", "theme_preference", mode="before")
    def _lowercase_values(cls, value: Optional[str]) -> Optional[str]:
        return value.lower() if isinstance(value, str) else value


class PinVerificationRequest(BaseModel):
    pin_code: str = Field(..., min_length=4, max_length=8, pattern=r"^\d{4,8}$")


class ClothesCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=120)
    category: str = Field(..., min_length=2, max_length=64)
    season: str = Field(..., min_length=2, max_length=32)
    color: str = Field(..., min_length=3, max_length=32)
    material: Optional[str] = Field(default=None, max_length=64)
    image_url: Optional[str] = None
    prompt_description: Optional[str] = Field(default=None, max_length=500)
    care_instructions: Optional[str] = Field(default=None, max_length=256)
    temperature_min: Optional[int] = Field(default=None, ge=-100, le=100)
    temperature_max: Optional[int] = Field(default=None, ge=-100, le=100)
    ai_metadata: Optional[dict] = None
    location_id: Optional[int] = None
    image_gallery: List[str] = Field(default_factory=list)

    @field_validator("image_gallery")
    def _deduplicate_gallery(cls, value: List[str]) -> List[str]:
        return list(dict.fromkeys(value))


class ClothesResponse(ClothesCreate):
    id: int
    user_id: int
    created_at: datetime

    class Config:
        from_attributes = True


class ClothesUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=2, max_length=120)
    category: Optional[str] = Field(default=None, min_length=2, max_length=64)
    season: Optional[str] = Field(default=None, min_length=2, max_length=32)
    color: Optional[str] = Field(default=None, min_length=3, max_length=32)
    material: Optional[str] = Field(default=None, max_length=64)
    prompt_description: Optional[str] = Field(default=None, max_length=500)
    care_instructions: Optional[str] = Field(default=None, max_length=256)
    temperature_min: Optional[int] = Field(default=None, ge=-100, le=100)
    temperature_max: Optional[int] = Field(default=None, ge=-100, le=100)
    ai_metadata: Optional[dict] = None
    location_id: Optional[int] = None


class ClothesInsights(BaseModel):
    title: str = Field(..., min_length=2, max_length=200)
    category: str = Field(..., min_length=2, max_length=64)
    gender: Optional[Literal["male", "female", "unisex"]] = None
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
    catalog_description: str = Field(..., min_length=10, max_length=2000)
    gen_prompt: str = Field(..., min_length=10, max_length=4000)
    pairing_hints: List[str]

    @field_validator("colors", "season", "style", "occasions", "tags", "pairing_hints")
    def _non_empty_lists(cls, value: List[str]) -> List[str]:
        if not value:
            raise ValueError("list must contain at least one item")
        return value

    @field_validator("temp_c_range")
    def _temperature_range(cls, value: List[int]) -> List[int]:
        if len(value) != 2:
            raise ValueError("temp_c_range must contain exactly two bounds")
        return value


class ClothesAutoFill(BaseModel):
    name: str = Field(..., min_length=2, max_length=120)
    category: str = Field(..., min_length=2, max_length=64)
    season: str = Field(..., min_length=2, max_length=32)
    color: str = Field(..., min_length=3, max_length=32)
    material: Optional[str] = Field(default=None, max_length=64)
    prompt_description: str = Field(..., min_length=10, max_length=500)
    care_instructions: Optional[str] = Field(default=None, max_length=256)
    ai_metadata: ClothesInsights
    temperature_min: Optional[int] = Field(default=None, ge=-100, le=100)
    temperature_max: Optional[int] = Field(default=None, ge=-100, le=100)


class WeatherSnapshot(BaseModel):
    temperature: int = Field(..., ge=-100, le=100)
    humidity: int = Field(..., ge=0, le=100)
    condition: str = Field(..., min_length=2, max_length=128)
    wind_speed: Optional[int] = Field(default=None, ge=0, le=300)


class MannequinItem(BaseModel):
    id: int
    name: str = Field(..., min_length=2, max_length=120)
    category: str = Field(..., min_length=2, max_length=64)
    color: str = Field(..., min_length=3, max_length=32)
    material: Optional[str] = Field(default=None, max_length=64)
    season: str = Field(..., min_length=2, max_length=32)
    prompt_description: Optional[str] = Field(default=None, max_length=500)

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


class AdminQueueTask(BaseModel):
    id: str
    name: str
    state: Literal["active", "reserved", "scheduled"]
    worker: Optional[str] = None
    queue: Optional[str] = None
    eta: Optional[datetime] = None
    args: str = ""
    kwargs: str = ""


class AdminQueueSnapshot(BaseModel):
    total: int = 0
    by_state: Dict[str, int] = Field(default_factory=dict)
    tasks: List[AdminQueueTask] = Field(default_factory=list)
    broker_available: bool = True
    error: Optional[str] = None


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


class NotificationChannelBase(BaseModel):
    name: str
    channel_type: str
    config: Dict[str, Any] = Field(default_factory=dict)
    is_active: bool = True


class NotificationChannelCreate(NotificationChannelBase):
    pass


class NotificationChannelUpdate(BaseModel):
    name: Optional[str] = None
    channel_type: Optional[str] = None
    config: Optional[Dict[str, Any]] = None
    is_active: Optional[bool] = None
    status: Optional[str] = None


class NotificationChannelResponse(NotificationChannelBase):
    id: int
    status: str = "disconnected"
    last_tested_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class NotificationTemplateBase(BaseModel):
    name: str
    content: str
    channel_type: Optional[str] = None
    variables: Optional[Dict[str, Any]] = None


class NotificationTemplateCreate(NotificationTemplateBase):
    pass


class NotificationTemplateUpdate(BaseModel):
    name: Optional[str] = None
    content: Optional[str] = None
    channel_type: Optional[str] = None
    variables: Optional[Dict[str, Any]] = None


class NotificationTemplateResponse(NotificationTemplateBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


class NotificationRuleBase(BaseModel):
    event: str
    priority: int = 0
    channel_ids: List[int] = Field(default_factory=list)
    template_id: Optional[int] = None
    filters: Optional[Dict[str, Any]] = None


class NotificationRuleCreate(NotificationRuleBase):
    pass


class NotificationRuleUpdate(BaseModel):
    event: Optional[str] = None
    priority: Optional[int] = None
    channel_ids: Optional[List[int]] = None
    template_id: Optional[int] = None
    filters: Optional[Dict[str, Any]] = None


class NotificationRuleResponse(NotificationRuleBase):
    id: int

    class Config:
        from_attributes = True
