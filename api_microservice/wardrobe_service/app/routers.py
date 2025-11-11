"""Endpoints for managing wardrobe items and outfits."""

from typing import List

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import Column, DateTime, Integer, String, func, select
from sqlalchemy.orm import Session, declarative_base

from .config import get_settings
from .media import save_media
from .schemas import OutfitSuggestion, WardrobeItemCreate, WardrobeItemRead

Base = declarative_base()


class WardrobeItem(Base):
    __tablename__ = "wardrobe_items"

    id = Column(Integer, primary_key=True)
    name = Column(String(255), nullable=False)
    category = Column(String(100), nullable=False)
    color = Column(String(50))
    image_url = Column(String(512))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


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


@router.post("/items", response_model=WardrobeItemRead, status_code=status.HTTP_201_CREATED)
def create_item(payload: WardrobeItemCreate, db: Session = Depends(get_db)) -> WardrobeItemRead:
    item = WardrobeItem(**payload.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return WardrobeItemRead.model_validate(item)


@router.get("/items", response_model=List[WardrobeItemRead])
def list_items(db: Session = Depends(get_db)) -> List[WardrobeItemRead]:
    items = db.scalars(select(WardrobeItem)).all()
    return [WardrobeItemRead.model_validate(item) for item in items]


@router.post("/items/{item_id}/image", response_model=WardrobeItemRead)
def upload_item_image(item_id: int, file: UploadFile = File(...), db: Session = Depends(get_db)) -> WardrobeItemRead:
    item = db.get(WardrobeItem, item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    url = save_media(file.file, file.filename)
    item.image_url = url
    db.commit()
    db.refresh(item)
    return WardrobeItemRead.model_validate(item)


@router.get("/outfits/suggestions", response_model=OutfitSuggestion)
def get_outfit_suggestion(db: Session = Depends(get_db)) -> OutfitSuggestion:
    items = db.scalars(select(WardrobeItem).limit(3)).all()
    if not items:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No items available for suggestion")

    return OutfitSuggestion(
        outfit_id=1,
        description="Simple recommendation placeholder",
        items=[WardrobeItemRead.model_validate(item) for item in items],
    )
