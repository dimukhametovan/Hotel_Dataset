from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from app.core.database import get_db
from app.models.room import Room, RoomType, Amenity, room_amenities
from app.models.booking import Booking
from app.models.user import User, UserRole
from app.api.dependencies import require_role, get_current_user
from datetime import date
from pydantic import BaseModel

# Temporary inline schemas until proper schemas are fixed
class AmenityInfo(BaseModel):
    amenity_id: int
    amenity_name: str
    description: Optional[str] = None
    
    class Config:
        from_attributes = True

class RoomResponse(BaseModel):
    room_id: int
    hotel_id: int
    roomtype_id: int
    room_number: str
    floor: Optional[int]
    price_per_night: Optional[float] = None
    is_available: bool
    description: Optional[str]
    amenities: List[AmenityInfo] = []
    
    class Config:
        from_attributes = True

class RoomCreateRequest(BaseModel):
    hotel_id: int
    roomtype_id: int
    room_number: str
    floor: Optional[int] = None
    price_per_night: float
    is_available: bool = True
    description: Optional[str] = None
    amenity_ids: Optional[List[int]] = []

class RoomUpdateRequest(BaseModel):
    roomtype_id: Optional[int] = None
    room_number: Optional[str] = None
    floor: Optional[int] = None
    price_per_night: Optional[float] = None
    is_available: Optional[bool] = None
    description: Optional[str] = None
    amenity_ids: Optional[List[int]] = None

router = APIRouter(prefix="/rooms")

@router.get("/{room_id}", response_model=RoomResponse)
async def get_room(
    room_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Получить информацию о комнате по ID с удобствами"""
    from sqlalchemy.orm import selectinload
    
    result = await db.execute(
        select(Room)
        .options(selectinload(Room.amenities))
        .where(Room.room_id == room_id)
    )
    room = result.scalar_one_or_none()
    
    if not room:
        raise HTTPException(status_code=404, detail="Комната не найдена")
    
    return room

@router.get("/hotel/{hotel_id}", response_model=List[RoomResponse])
async def get_hotel_rooms(
    hotel_id: int,
    roomtype_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db)
):
    """Получить все комнаты отеля с удобствами (фильтрация только по типу)"""
    from sqlalchemy.orm import selectinload
    
    query = select(Room).options(selectinload(Room.amenities)).where(Room.hotel_id == hotel_id)
    
    if roomtype_id:
        query = query.where(Room.roomtype_id == roomtype_id)
    
    result = await db.execute(query)
    rooms = result.scalars().all()
    
    return rooms

@router.post("/", response_model=RoomResponse)
async def create_room(
    room_data: RoomCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.hotel_admin, UserRole.system_admin))
):
    """Создать новую комнату (только для администраторов отеля)"""
    new_room = Room(**room_data.model_dump(exclude={'amenity_ids'}))
    db.add(new_room)
    await db.flush()
    
    # Добавляем удобства
    if room_data.amenity_ids:
        for amenity_id in room_data.amenity_ids:
            await db.execute(
                room_amenities.insert().values(
                    room_id=new_room.room_id,
                    amenity_id=amenity_id
                )
            )
    
    await db.commit()
    await db.refresh(new_room)
    
    return new_room

@router.put("/{room_id}", response_model=RoomResponse)
async def update_room(
    room_id: int,
    room_data: RoomUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.hotel_admin, UserRole.system_admin))
):
    """Обновить информацию о комнате"""
    result = await db.execute(
        select(Room).where(Room.room_id == room_id)
    )
    room = result.scalar_one_or_none()
    
    if not room:
        raise HTTPException(status_code=404, detail="Комната не найдена")
    
    update_data = room_data.model_dump(exclude_unset=True, exclude={'amenity_ids'})
    for field, value in update_data.items():
        setattr(room, field, value)
    
    # Обновляем удобства, если указаны
    if room_data.amenity_ids is not None:
        # Удаляем старые связи
        await db.execute(
            room_amenities.delete().where(room_amenities.c.room_id == room_id)
        )
        # Добавляем новые
        for amenity_id in room_data.amenity_ids:
            await db.execute(
                room_amenities.insert().values(
                    room_id=room_id,
                    amenity_id=amenity_id
                )
            )
    
    await db.commit()
    await db.refresh(room)
    
    return room

@router.delete("/{room_id}")
async def delete_room(
    room_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.hotel_admin, UserRole.system_admin))
):
    """Удалить комнату"""
    result = await db.execute(
        select(Room).where(Room.room_id == room_id)
    )
    room = result.scalar_one_or_none()
    
    if not room:
        raise HTTPException(status_code=404, detail="Комната не найдена")
    
    # Проверяем, есть ли активные бронирования
    bookings_result = await db.execute(
        select(func.count()).select_from(Booking).where(
            Booking.room_id == room_id,
            Booking.status.in_(['confirmed', 'checked_in'])
        )
    )
    active_bookings = bookings_result.scalar()
    
    if active_bookings > 0:
        raise HTTPException(
            status_code=400,
            detail="Невозможно удалить комнату с активными бронированиями"
        )
    
    await db.delete(room)
    await db.commit()
    
    return {"message": "Комната успешно удалена"}
