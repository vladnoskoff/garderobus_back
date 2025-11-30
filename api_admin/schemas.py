from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field


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
    admin_restart_supported: bool = False
    worker_restart_supported: bool = False
    last_restart_requested_at: Optional[datetime] = None
    last_admin_restart_requested_at: Optional[datetime] = None
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
    category: str = "application"
    context: dict[str, Any] = Field(default_factory=dict)


class AdminSystemEventList(BaseModel):
    events: List[AdminSystemEvent] = Field(default_factory=list)
    total: int = 0
    page: int = 1
    limit: int = 50


class AdminSystemEventExclusion(BaseModel):
    id: str
    category: str
    path: str
    method: Optional[str] = None


class AdminSystemEventExclusionRequest(BaseModel):
    category: str
    path: str
    method: Optional[str] = None


class AdminSystemEventExclusionList(BaseModel):
    exclusions: List[AdminSystemEventExclusion] = Field(default_factory=list)


class AdminActivityMetrics(BaseModel):
    active_now: int = 0
    active_24h: int = 0
    platform_breakdown: dict[str, int] = Field(default_factory=dict)
