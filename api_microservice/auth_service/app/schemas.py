"""Pydantic schemas for the auth service."""

from typing import Optional

from pydantic import AliasChoices, BaseModel, EmailStr, Field, model_validator


class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    phone: Optional[str] = None
    style_preference: Optional[str] = None
    gender: Optional[str] = None
    theme_preference: Optional[str] = None
    pin_code: Optional[str] = Field(default=None, validation_alias=AliasChoices("pin_code", "pinCode"))
    language_preference: Optional[str] = None

    @model_validator(mode="before")
    @classmethod
    def _alias_pin_code(cls, values: object) -> object:
        if isinstance(values, dict) and "pin_code" not in values and "pinCode" in values:
            values = {**values, "pin_code": values["pinCode"]}
        return values


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: int
    name: str
    email: EmailStr
    phone: Optional[str] = None
    style_preference: Optional[str] = None
    location: Optional[str] = None
    gender: Optional[str] = None
    theme_preference: Optional[str] = None
    has_pin: bool = False
    language_preference: Optional[str] = Field(default="ru")

    model_config = {"from_attributes": True}


class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    password: Optional[str] = None
    location: Optional[str] = None
    gender: Optional[str] = None
    theme_preference: Optional[str] = None
    style_preference: Optional[str] = None
    pin_code: Optional[str] = Field(default=None, validation_alias=AliasChoices("pin_code", "pinCode"))
    language_preference: Optional[str] = None

    @model_validator(mode="before")
    @classmethod
    def _alias_pin_code(cls, values: object) -> object:
        if isinstance(values, dict) and "pin_code" not in values and "pinCode" in values:
            values = {**values, "pin_code": values["pinCode"]}
        return values


class PinVerificationRequest(BaseModel):
    pin_code: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
