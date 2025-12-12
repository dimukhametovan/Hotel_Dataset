from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class RoomTypeBase(BaseModel):
    type_name: str
    description: Optional[str] = None
    max_guests: int

class RoomTypeResponse(RoomTypeBase):
    room_type_id: int
    
    class Config:
        from_attributes = True

class AmenityBase(BaseModel):
    amenity_name: str
    description: Optional[str] = None

class AmenityResponse(AmenityBase):
    amenity_id: int
    
    class Config:
        from_attributes = True

class RoomBase(BaseModel):
    hotel_id: int
    room_type_id: int
    room_number: str
    floor: Optional[int] = None
    price_per_night: float = Field(gt=0)
    is_available: bool = True
    description: Optional[str] = None

class RoomCreateRequest(RoomBase):
    amenity_ids: Optional[List[int]] = []

class RoomUpdateRequest(BaseModel):
    room_type_id: Optional[int] = None
    room_number: Optional[str] = None
    floor: Optional[int] = None
    price_per_night: Optional[float] = Field(None, gt=0)
    is_available: Optional[bool] = None
    description: Optional[str] = None
    amenity_ids: Optional[List[int]] = None

class RoomResponse(RoomBase):
    room_id: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
