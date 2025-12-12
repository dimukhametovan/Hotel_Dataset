from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import date, datetime
from enum import Enum

class BookingStatus(str, Enum):
    pending = "pending"
    confirmed = "confirmed"
    checked_in = "checked_in"
    completed = "completed"
    cancelled = "cancelled"

class BookingBase(BaseModel):
    room_id: int
    check_in: date
    check_out: date
    guests_count: int = Field(ge=1)
    special_requests: Optional[str] = None
    
    @validator('check_out')
    def check_out_after_check_in(cls, v, values):
        if 'check_in' in values and v <= values['check_in']:
            raise ValueError('Дата выезда должна быть позже даты заезда')
        return v

class BookingCreateRequest(BookingBase):
    pass

class BookingUpdateRequest(BaseModel):
    status: Optional[BookingStatus] = None
    special_requests: Optional[str] = None

class BookingResponse(BookingBase):
    booking_id: int
    user_id: int
    total_price: float
    status: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
