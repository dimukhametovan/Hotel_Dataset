from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text
from typing import List

from ...core.database import get_db
from ...models import Hotel, User, UserRole
from ...schemas.hotel import HotelResponse, HotelCreate, HotelUpdate
from ..dependencies import get_current_user, require_role

router = APIRouter(prefix="/hotels")


@router.get("/", response_model=List[HotelResponse])
async def get_hotels(
    skip: int = 0,
    limit: int = 100,
    city: str = None,
    db: AsyncSession = Depends(get_db)
):
    """Получение списка отелей (доступно всем)"""
    query = select(Hotel).where(Hotel.is_active == True)
    
    if city:
        query = query.where(Hotel.city.ilike(f"%{city}%"))
    
    query = query.offset(skip).limit(limit)
    result = await db.execute(query)
    hotels = result.scalars().all()
    
    return hotels


@router.get("/{hotel_id}", response_model=HotelResponse)
async def get_hotel(
    hotel_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Получение отеля по ID"""
    result = await db.execute(select(Hotel).where(Hotel.hotel_id == hotel_id))
    hotel = result.scalar_one_or_none()
    
    if not hotel:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Отель не найден")
    
    return hotel


@router.post("/", response_model=HotelResponse, status_code=status.HTTP_201_CREATED)
async def create_hotel(
    hotel_data: HotelCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.system_admin))
):
    """Создание отеля (только системный админ)"""
    new_hotel = Hotel(**hotel_data.model_dump())
    
    db.add(new_hotel)
    await db.commit()
    await db.refresh(new_hotel)
    
    return new_hotel


@router.patch("/{hotel_id}", response_model=HotelResponse)
async def update_hotel(
    hotel_id: int,
    hotel_data: HotelUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Обновление отеля (системный админ или админ отеля)"""
    result = await db.execute(select(Hotel).where(Hotel.hotel_id == hotel_id))
    hotel = result.scalar_one_or_none()
    
    if not hotel:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Отель не найден")
    
    # Проверка прав
    if current_user.role != UserRole.system_admin and hotel.admin_id != current_user.user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Недостаточно прав")
    
    # Обновление
    update_data = hotel_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(hotel, field, value)
    
    await db.commit()
    await db.refresh(hotel)
    
    return hotel


@router.delete("/{hotel_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_hotel(
    hotel_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.system_admin))
):
    """Удаление отеля (только системный админ)"""
    result = await db.execute(select(Hotel).where(Hotel.hotel_id == hotel_id))
    hotel = result.scalar_one_or_none()
    
    if not hotel:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Отель не найден")
    
    await db.delete(hotel)
    await db.commit()
    
    return None
