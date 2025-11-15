"""Endpoints for managing wardrobe items and outfits."""

from typing import List, Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy import JSON, Column, DateTime, ForeignKey, Integer, String, func, select
from sqlalchemy.orm import Session, declarative_base

from .config import get_settings
from .media import save_media
from .schemas import (
    OutfitSuggestion,
    WardrobeItemCreate,
    WardrobeItemRead,
    WardrobeItemUpdate,
)

Base = declarative_base()


class WardrobeItem(Base):
    __tablename__ = "wardrobe_items"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, index=True, nullable=False)
    name = Column(String(255), nullable=False)
    category = Column(String(100), nullable=False)
    season = Column(String(50), nullable=False)
    color = Column(String(50))
    image_url = Column(String(512))
    material = Column(String(100))
    prompt_description = Column(String(1024))
    care_instructions = Column(String(1024))
    temperature_min = Column(Integer)
    temperature_max = Column(Integer)
    ai_metadata = Column(JSON)
    location_id = Column(Integer, ForeignKey("wardrobe_locations.id", ondelete="SET NULL"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class WardrobeLocation(Base):
    __tablename__ = "wardrobe_locations"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, nullable=False)
    name = Column(String(255), nullable=False)


router = APIRouter(prefix="/wardrobe", tags=["wardrobe"])


def get_db() -> Session:
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker

    settings = get_settings()
    engine = create_engine(settings.database_url, future=True)
    SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)
    Base.metadata.create_all(engine)
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _to_schema(item: WardrobeItem) -> WardrobeItemRead:
    schema = WardrobeItemRead.model_validate(item)
    if schema.image_url:
        schema.image_gallery = [schema.image_url]
    return schema


@router.post("/items", response_model=WardrobeItemRead, status_code=status.HTTP_201_CREATED)
def create_item(payload: WardrobeItemCreate, db: Session = Depends(get_db)) -> WardrobeItemRead:
    item = WardrobeItem(**payload.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return _to_schema(item)


@router.get("/items", response_model=List[WardrobeItemRead])
def list_items(
    user_id: Optional[int] = None,
    db: Session = Depends(get_db),
) -> List[WardrobeItemRead]:
    query = select(WardrobeItem)
    if user_id is not None:
        query = query.where(WardrobeItem.user_id == user_id)
    items = db.scalars(query).all()
    return [_to_schema(item) for item in items]


@router.get("/user/{user_id}", response_model=List[WardrobeItemRead])
def get_user_items(
    user_id: int,
    db: Session = Depends(get_db),
    location_id: Optional[int] = Query(default=None, description="Wardrobe location identifier"),
) -> List[WardrobeItemRead]:
    query = select(WardrobeItem).where(WardrobeItem.user_id == user_id)
    if location_id is not None:
        query = query.where(WardrobeItem.location_id == location_id)
    items = db.scalars(query).all()
    return [_to_schema(item) for item in items]


@router.get("/items/{item_id}", response_model=WardrobeItemRead)
def get_item(item_id: int, db: Session = Depends(get_db)) -> WardrobeItemRead:
    item = db.get(WardrobeItem, item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return _to_schema(item)


@router.put("/items/{item_id}", response_model=WardrobeItemRead)
def update_item(
    item_id: int,
    payload: WardrobeItemUpdate,
    db: Session = Depends(get_db),
) -> WardrobeItemRead:
    item = db.get(WardrobeItem, item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(item, field, value)

    db.commit()
    db.refresh(item)
    return _to_schema(item)


@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(item_id: int, db: Session = Depends(get_db)) -> None:
    item = db.get(WardrobeItem, item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    db.delete(item)
    db.commit()


@router.post("/items/{item_id}/image", response_model=WardrobeItemRead)
def upload_item_image(item_id: int, file: UploadFile = File(...), db: Session = Depends(get_db)) -> WardrobeItemRead:
    item = db.get(WardrobeItem, item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    url = save_media(file.file, file.filename)
    item.image_url = url
    db.commit()
    db.refresh(item)
    return _to_schema(item)


@router.get("/outfits/suggestions", response_model=OutfitSuggestion)
def get_outfit_suggestion(db: Session = Depends(get_db)) -> OutfitSuggestion:
    items = db.scalars(select(WardrobeItem).limit(3)).all()
    if not items:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No items available for suggestion")

    return OutfitSuggestion(
        outfit_id=1,
        description="Simple recommendation placeholder",
        items=[_to_schema(item) for item in items],
    )
