from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
from app.core.database import get_db
from app.models.room import RoomType
from app.models.user import User, UserRole
from app.api.dependencies import get_current_user, require_role
from pydantic import BaseModel

# Schemas
class RoomTypeResponse(BaseModel):
    roomtype_id: int
    type_name: str
    description: Optional[str]
    max_occupancy: Optional[int]
    price_per_night: Optional[float]
    
    class Config:
        from_attributes = True

class RoomTypeCreate(BaseModel):
    type_name: str
    description: Optional[str] = None
    max_occupancy: Optional[int] = 2
    price_per_night: Optional[float] = None

class RoomTypeUpdate(BaseModel):
    type_name: Optional[str] = None
    description: Optional[str] = None
    max_occupancy: Optional[int] = None
    price_per_night: Optional[float] = None

router = APIRouter(prefix="/roomtypes")


@router.get("/", response_model=List[RoomTypeResponse])
async def get_room_types(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    """Получить список всех типов номеров (доступно всем)"""
    result = await db.execute(
        select(RoomType).offset(skip).limit(limit)
    )
    room_types = result.scalars().all()
    return room_types


@router.get("/{roomtype_id}", response_model=RoomTypeResponse)
async def get_room_type(
    roomtype_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Получить тип номера по ID"""
    result = await db.execute(
        select(RoomType).where(RoomType.roomtype_id == roomtype_id)
    )
    room_type = result.scalar_one_or_none()
    
    if not room_type:
        raise HTTPException(status_code=404, detail="Тип номера не найден")
    
    return room_type


@router.post("/", response_model=RoomTypeResponse, status_code=status.HTTP_201_CREATED)
async def create_room_type(
    room_type_data: RoomTypeCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.hotel_admin, UserRole.system_admin))
):
    """Создать новый тип номера (администратор отеля)"""
    # Проверяем, не существует ли уже такой тип
    result = await db.execute(
        select(RoomType).where(RoomType.type_name == room_type_data.type_name)
    )
    existing = result.scalar_one_or_none()
    
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Тип номера с таким названием уже существует"
        )
    
    new_room_type = RoomType(**room_type_data.model_dump())
    db.add(new_room_type)
    await db.commit()
    await db.refresh(new_room_type)
    
    return new_room_type


@router.patch("/{roomtype_id}", response_model=RoomTypeResponse)
async def update_room_type(
    roomtype_id: int,
    room_type_data: RoomTypeUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.hotel_admin, UserRole.system_admin))
):
    """Обновить тип номера (администратор отеля)"""
    result = await db.execute(
        select(RoomType).where(RoomType.roomtype_id == roomtype_id)
    )
    room_type = result.scalar_one_or_none()
    
    if not room_type:
        raise HTTPException(status_code=404, detail="Тип номера не найден")
    
    update_data = room_type_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(room_type, field, value)
    
    await db.commit()
    await db.refresh(room_type)
    
    return room_type


@router.delete("/{roomtype_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_room_type(
    roomtype_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.hotel_admin, UserRole.system_admin))
):
    """Удалить тип номера (администратор отеля)"""
    result = await db.execute(
        select(RoomType).where(RoomType.roomtype_id == roomtype_id)
    )
    room_type = result.scalar_one_or_none()
    
    if not room_type:
        raise HTTPException(status_code=404, detail="Тип номера не найден")
    
    await db.delete(room_type)
    await db.commit()
    
    return None
