from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_
from typing import List, Optional
from datetime import date, datetime
from app.core.database import get_db
from app.models.booking import Booking
from app.models.room import Room
from app.models.user import User, UserRole
from app.api.dependencies import get_current_user, require_role
from pydantic import BaseModel, validator

# Temporary inline schemas
class BookingCreateRequest(BaseModel):
    room_id: int
    check_in_date: date
    check_out_date: date
    guests_count: int = 1
    
    @validator('check_out_date')
    def check_out_after_check_in(cls, v, values):
        if 'check_in_date' in values and v <= values['check_in_date']:
            raise ValueError('Дата выезда должна быть позже даты заезда')
        return v

class BookingUpdateRequest(BaseModel):
    status: Optional[str] = None

class UserInfo(BaseModel):
    user_id: int
    email: str
    first_name: str
    last_name: str
    phone: Optional[str] = None
    
    class Config:
        from_attributes = True

class BookingResponse(BaseModel):
    booking_id: int
    user_id: int
    room_id: int
    check_in_date: date
    check_out_date: date
    guests_count: Optional[int]
    total_price: Optional[float]
    status: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class BookingWithUserResponse(BaseModel):
    booking_id: int
    user_id: int
    room_id: int
    check_in_date: date
    check_out_date: date
    guests_count: Optional[int]
    total_price: Optional[float]
    status: str
    created_at: datetime
    updated_at: datetime
    user: Optional[UserInfo] = None
    
    class Config:
        from_attributes = True

router = APIRouter(prefix="/bookings")

@router.get("/my", response_model=List[BookingResponse])
async def get_my_bookings(
    status: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить все бронирования текущего пользователя"""
    query = select(Booking).where(Booking.user_id == current_user.user_id)
    
    if status:
        query = query.where(Booking.status == status)
    
    query = query.order_by(Booking.created_at.desc())
    
    result = await db.execute(query)
    bookings = result.scalars().all()
    
    return bookings

@router.get("/{booking_id}", response_model=BookingResponse)
async def get_booking(
    booking_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить информацию о конкретном бронировании"""
    result = await db.execute(
        select(Booking).where(Booking.booking_id == booking_id)
    )
    booking = result.scalar_one_or_none()
    
    if not booking:
        raise HTTPException(status_code=404, detail="Бронирование не найдено")
    
    # Проверяем права доступа
    if booking.user_id != current_user.user_id and current_user.role not in [UserRole.hotel_admin, UserRole.system_admin]:
        raise HTTPException(status_code=403, detail="Нет доступа к этому бронированию")
    
    return booking

@router.post("/", response_model=BookingResponse)
async def create_booking(
    booking_data: BookingCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Создать новое бронирование"""
    # Проверяем, что комната существует
    room_result = await db.execute(
        select(Room).where(Room.room_id == booking_data.room_id)
    )
    room = room_result.scalar_one_or_none()
    
    if not room:
        raise HTTPException(status_code=404, detail="Комната не найдена")
    
    # Проверяем доступность комнаты
    availability_check = await db.execute(
        select(Booking).where(
            and_(
                Booking.room_id == booking_data.room_id,
                Booking.status.in_(['confirmed', 'checked_in']),
                or_(
                    and_(
                        Booking.check_in_date <= booking_data.check_in_date,
                        Booking.check_out_date > booking_data.check_in_date
                    ),
                    and_(
                        Booking.check_in_date < booking_data.check_out_date,
                        Booking.check_out_date >= booking_data.check_out_date
                    ),
                    and_(
                        Booking.check_in_date >= booking_data.check_in_date,
                        Booking.check_out_date <= booking_data.check_out_date
                    )
                )
            )
        )
    )
    conflicting_booking = availability_check.scalar_one_or_none()
    
    if conflicting_booking:
        raise HTTPException(
            status_code=400,
            detail="Комната уже забронирована на выбранные даты"
        )
    
    # Вычисляем количество ночей и стоимость
    nights = (booking_data.check_out_date - booking_data.check_in_date).days
    if nights <= 0:
        raise HTTPException(
            status_code=400,
            detail="Дата выезда должна быть позже даты заезда"
        )
    
    total_price = room.price_per_night * nights
    
    # Создаем бронирование
    new_booking = Booking(
        user_id=current_user.user_id,
        room_id=booking_data.room_id,
        check_in_date=booking_data.check_in_date,
        check_out_date=booking_data.check_out_date,
        total_price=total_price,
        status='pending',
        guests_count=booking_data.guests_count
    )
    
    db.add(new_booking)
    await db.commit()
    await db.refresh(new_booking)
    
    return new_booking

@router.put("/{booking_id}", response_model=BookingResponse)
async def update_booking(
    booking_id: int,
    booking_data: BookingUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Обновить статус бронирования"""
    result = await db.execute(
        select(Booking).where(Booking.booking_id == booking_id)
    )
    booking = result.scalar_one_or_none()
    
    if not booking:
        raise HTTPException(status_code=404, detail="Бронирование не найдено")
    
    # Проверяем права доступа
    if booking.user_id != current_user.user_id and current_user.role not in [UserRole.hotel_admin, UserRole.system_admin]:
        raise HTTPException(status_code=403, detail="Нет доступа к этому бронированию")
    
    # Обновляем данные
    update_data = booking_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(booking, field, value)
    
    await db.commit()
    await db.refresh(booking)
    
    return booking

@router.delete("/{booking_id}")
async def cancel_booking(
    booking_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Отменить бронирование"""
    result = await db.execute(
        select(Booking).where(Booking.booking_id == booking_id)
    )
    booking = result.scalar_one_or_none()
    
    if not booking:
        raise HTTPException(status_code=404, detail="Бронирование не найдено")
    
    # Проверяем права доступа
    if booking.user_id != current_user.user_id and current_user.role not in [UserRole.hotel_admin, UserRole.system_admin]:
        raise HTTPException(status_code=403, detail="Нет доступа к этому бронированию")
    
    # Проверяем, можно ли отменить
    if booking.status in ['completed', 'cancelled']:
        raise HTTPException(
            status_code=400,
            detail="Невозможно отменить завершенное или уже отмененное бронирование"
        )
    
    booking.status = 'cancelled'
    await db.commit()
    
    return {"message": "Бронирование успешно отменено"}

@router.get("/hotel/{hotel_id}/all", response_model=List[BookingWithUserResponse])
async def get_hotel_bookings(
    hotel_id: int,
    status: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.hotel_admin, UserRole.system_admin))
):
    """Получить все бронирования отеля (только для администраторов)"""
    from sqlalchemy.orm import selectinload
    
    query = (
        select(Booking)
        .options(selectinload(Booking.user))
        .join(Room, Booking.room_id == Room.room_id)
        .where(Room.hotel_id == hotel_id)
    )
    
    if status:
        query = query.where(Booking.status == status)
    
    query = query.order_by(Booking.check_in_date.desc())
    
    result = await db.execute(query)
    bookings = result.scalars().all()
    
    return bookings
