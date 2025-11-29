from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from api import models
from api import schemas
from api.database import get_db
from .admin import _get_current_user

router = APIRouter(prefix="/admin/notifications", tags=["Notifications"])


@router.get("/channels", response_model=List[schemas.NotificationChannelResponse])
def list_channels(
    _: models.User = Depends(_get_current_user), db: Session = Depends(get_db)
) -> List[models.NotificationChannel]:
    return db.query(models.NotificationChannel).order_by(models.NotificationChannel.id).all()


@router.post(
    "/channels",
    response_model=schemas.NotificationChannelResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_channel(
    payload: schemas.NotificationChannelCreate,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
) -> models.NotificationChannel:
    channel = models.NotificationChannel(**payload.model_dump())
    db.add(channel)
    db.commit()
    db.refresh(channel)
    return channel


@router.put("/channels/{channel_id}", response_model=schemas.NotificationChannelResponse)
def update_channel(
    channel_id: int,
    payload: schemas.NotificationChannelUpdate,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
) -> models.NotificationChannel:
    channel = db.query(models.NotificationChannel).get(channel_id)
    if channel is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Канал не найден")

    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(channel, key, value)

    db.commit()
    db.refresh(channel)
    return channel


@router.delete("/channels/{channel_id}")
def delete_channel(
    channel_id: int,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    channel = db.query(models.NotificationChannel).get(channel_id)
    if channel is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Канал не найден")

    db.delete(channel)
    db.commit()
    return {"detail": "Удалено"}


@router.post("/channels/{channel_id}/test", response_model=schemas.NotificationChannelResponse)
def test_channel(
    channel_id: int,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
) -> models.NotificationChannel:
    channel = db.query(models.NotificationChannel).get(channel_id)
    if channel is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Канал не найден")

    channel.status = "connected"
    channel.last_tested_at = datetime.utcnow()
    db.commit()
    db.refresh(channel)
    return channel


@router.get("/templates", response_model=List[schemas.NotificationTemplateResponse])
def list_templates(
    _: models.User = Depends(_get_current_user), db: Session = Depends(get_db)
) -> List[models.NotificationTemplate]:
    return (
        db.query(models.NotificationTemplate)
        .order_by(models.NotificationTemplate.created_at.desc())
        .all()
    )


@router.post(
    "/templates",
    response_model=schemas.NotificationTemplateResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_template(
    payload: schemas.NotificationTemplateCreate,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
) -> models.NotificationTemplate:
    template = models.NotificationTemplate(**payload.model_dump())
    db.add(template)
    db.commit()
    db.refresh(template)
    return template


@router.put("/templates/{template_id}", response_model=schemas.NotificationTemplateResponse)
def update_template(
    template_id: int,
    payload: schemas.NotificationTemplateUpdate,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
) -> models.NotificationTemplate:
    template = db.query(models.NotificationTemplate).get(template_id)
    if template is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Шаблон не найден")

    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(template, key, value)

    db.commit()
    db.refresh(template)
    return template


@router.delete("/templates/{template_id}")
def delete_template(
    template_id: int,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    template = db.query(models.NotificationTemplate).get(template_id)
    if template is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Шаблон не найден")

    db.delete(template)
    db.commit()
    return {"detail": "Удалено"}


@router.get("/rules", response_model=List[schemas.NotificationRuleResponse])
def list_rules(
    _: models.User = Depends(_get_current_user), db: Session = Depends(get_db)
) -> List[models.NotificationRule]:
    return (
        db.query(models.NotificationRule)
        .order_by(models.NotificationRule.priority.desc(), models.NotificationRule.id)
        .all()
    )


@router.post(
    "/rules",
    response_model=schemas.NotificationRuleResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_rule(
    payload: schemas.NotificationRuleCreate,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
) -> models.NotificationRule:
    rule = models.NotificationRule(**payload.model_dump())
    db.add(rule)
    db.commit()
    db.refresh(rule)
    return rule


@router.put("/rules/{rule_id}", response_model=schemas.NotificationRuleResponse)
def update_rule(
    rule_id: int,
    payload: schemas.NotificationRuleUpdate,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
) -> models.NotificationRule:
    rule = db.query(models.NotificationRule).get(rule_id)
    if rule is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Правило не найдено")

    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(rule, key, value)

    db.commit()
    db.refresh(rule)
    return rule


@router.delete("/rules/{rule_id}")
def delete_rule(
    rule_id: int,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    rule = db.query(models.NotificationRule).get(rule_id)
    if rule is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Правило не найдено")

    db.delete(rule)
    db.commit()
    return {"detail": "Удалено"}
