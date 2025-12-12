from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
from app.core.database import get_db
from app.models.room import Amenity, room_amenities
from app.models.user import User, UserRole
from app.api.dependencies import get_current_user, require_role
from pydantic import BaseModel

# Schemas
class AmenityResponse(BaseModel):
    amenity_id: int
    amenity_name: str
    description: Optional[str]
    
    class Config:
        from_attributes = True

class AmenityCreate(BaseModel):
    amenity_name: str
    description: Optional[str] = None

class AmenityUpdate(BaseModel):
    amenity_name: Optional[str] = None
    description: Optional[str] = None

router = APIRouter(prefix="/amenities")


@router.get("/", response_model=List[AmenityResponse])
async def get_amenities(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    """Получить список всех удобств (доступно всем)"""
    result = await db.execute(
        select(Amenity).offset(skip).limit(limit)
    )
    amenities = result.scalars().all()
    return amenities


@router.get("/{amenity_id}", response_model=AmenityResponse)
async def get_amenity(
    amenity_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Получить удобство по ID"""
    result = await db.execute(
        select(Amenity).where(Amenity.amenity_id == amenity_id)
    )
    amenity = result.scalar_one_or_none()
    
    if not amenity:
        raise HTTPException(status_code=404, detail="Удобство не найдено")
    
    return amenity


@router.post("/", response_model=AmenityResponse, status_code=status.HTTP_201_CREATED)
async def create_amenity(
    amenity_data: AmenityCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.system_admin))
):
    """Создать новое удобство (только системный администратор)"""
    # Проверяем, не существует ли уже такое удобство
    result = await db.execute(
        select(Amenity).where(Amenity.amenity_name == amenity_data.amenity_name)
    )
    existing = result.scalar_one_or_none()
    
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Удобство с таким названием уже существует"
        )
    
    new_amenity = Amenity(**amenity_data.model_dump())
    db.add(new_amenity)
    await db.commit()
    await db.refresh(new_amenity)
    
    return new_amenity


@router.patch("/{amenity_id}", response_model=AmenityResponse)
async def update_amenity(
    amenity_id: int,
    amenity_data: AmenityUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.system_admin))
):
    """Обновить удобство (только системный администратор)"""
    result = await db.execute(
        select(Amenity).where(Amenity.amenity_id == amenity_id)
    )
    amenity = result.scalar_one_or_none()
    
    if not amenity:
        raise HTTPException(status_code=404, detail="Удобство не найдено")
    
    update_data = amenity_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(amenity, field, value)
    
    await db.commit()
    await db.refresh(amenity)
    
    return amenity


@router.delete("/{amenity_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_amenity(
    amenity_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.system_admin))
):
    """Удалить удобство (только системный администратор)"""
    result = await db.execute(
        select(Amenity).where(Amenity.amenity_id == amenity_id)
    )
    amenity = result.scalar_one_or_none()
    
    if not amenity:
        raise HTTPException(status_code=404, detail="Удобство не найдено")
    
    await db.delete(amenity)
    await db.commit()
    
    return None


@router.post("/room/{room_id}/amenity/{amenity_id}", status_code=status.HTTP_201_CREATED)
async def assign_amenity_to_room(
    room_id: int,
    amenity_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.hotel_admin, UserRole.system_admin))
):
    """Назначить удобство конкретному номеру (администратор отеля)"""
    # Проверяем существование удобства
    result = await db.execute(
        select(Amenity).where(Amenity.amenity_id == amenity_id)
    )
    amenity = result.scalar_one_or_none()
    
    if not amenity:
        raise HTTPException(status_code=404, detail="Удобство не найдено")
    
    # Добавляем связь
    try:
        await db.execute(
            room_amenities.insert().values(
                room_id=room_id,
                amenity_id=amenity_id
            )
        )
        await db.commit()
        return {"message": "Удобство успешно назначено номеру"}
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Невозможно назначить удобство. Возможно, оно уже назначено этому номеру."
        )


@router.delete("/room/{room_id}/amenity/{amenity_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_amenity_from_room(
    room_id: int,
    amenity_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.hotel_admin, UserRole.system_admin))
):
    """Удалить удобство у номера (администратор отеля)"""
    await db.execute(
        room_amenities.delete().where(
            room_amenities.c.room_id == room_id,
            room_amenities.c.amenity_id == amenity_id
        )
    )
    await db.commit()
    
    return None
