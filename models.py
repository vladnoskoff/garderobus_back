from sqlalchemy import Column, Integer, String, ForeignKey, JSON, TIMESTAMP, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)
    openai_api_key = Column(String, nullable=True)
    weather_api_key = Column(String, nullable=True)
    location = Column(String, nullable=True) 

class Clothes(Base):
    __tablename__ = "clothes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    name = Column(String, nullable=False)
    category = Column(String, nullable=False)
    season = Column(String, nullable=False)
    color = Column(String, nullable=False)
    material = Column(String, nullable=True)
    image_url = Column(String, nullable=True)
    created_at = Column(TIMESTAMP, default=func.now())
    prompt_description = Column(Text, nullable=True)

class Weather(Base):
    __tablename__ = "weather"

    id = Column(Integer, primary_key=True, index=True)
    temperature = Column(Integer, nullable=False)
    humidity = Column(Integer, nullable=False)
    condition = Column(String, nullable=False)
    wind_speed = Column(Integer, nullable=True)
    created_at = Column(TIMESTAMP, default=func.now())

class Outfit(Base):
    __tablename__ = "outfits"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    weather_id = Column(Integer, ForeignKey("weather.id", ondelete="CASCADE"))
    clothing_ids = Column(JSON, nullable=False)
    image_url = Column(String, nullable=True)
    created_at = Column(TIMESTAMP, default=func.now())
    rating = Column(Integer, nullable=True)

class WearHistory(Base):
    __tablename__ = "wear_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    clothing_id = Column(Integer, ForeignKey("clothes.id", ondelete="CASCADE"))
    worn_at = Column(TIMESTAMP, default=func.now())
