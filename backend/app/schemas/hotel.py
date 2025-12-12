from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


# Базовая схема отеля
class HotelBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    address: str = Field(..., min_length=1, max_length=500)
    city: str = Field(..., min_length=1, max_length=100)
    country: str = Field(..., min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    email: Optional[str] = Field(None, max_length=255)
    star_rating: Optional[float] = Field(None, ge=1, le=5)
    description: Optional[str] = None


# Схема для создания отеля
class HotelCreate(HotelBase):
    admin_id: Optional[int] = None


# Схема для обновления отеля
class HotelUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    address: Optional[str] = Field(None, min_length=1, max_length=500)
    city: Optional[str] = Field(None, min_length=1, max_length=100)
    country: Optional[str] = Field(None, min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    email: Optional[str] = Field(None, max_length=255)
    star_rating: Optional[float] = Field(None, ge=1, le=5)
    description: Optional[str] = None
    admin_id: Optional[int] = None
    is_active: Optional[bool] = None


# Схема ответа
class HotelResponse(HotelBase):
    hotel_id: int
    admin_id: Optional[int]
    is_active: bool
    created_at: datetime
    average_rating: Optional[float] = None
    reviews_count: Optional[int] = 0
    total_rooms: Optional[int] = 0
    
    class Config:
        from_attributes = True


# Схема списка отелей
class HotelList(BaseModel):
    hotels: list[HotelResponse]
    total: int
