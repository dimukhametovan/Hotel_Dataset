from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func
from typing import List, Optional
from datetime import datetime
from app.core.database import get_db
from app.models.booking import Review, Booking
from app.models.room import Room
from app.models.user import User
from app.api.dependencies import get_current_user, require_role
from pydantic import BaseModel, Field

# Temporary inline schemas
class UserInfo(BaseModel):
    user_id: int
    first_name: str
    last_name: str
    
    class Config:
        from_attributes = True

class ReviewCreateRequest(BaseModel):
    booking_id: int
    rating: int = Field(ge=1, le=5)
    comment: Optional[str] = None

class ReviewUpdateRequest(BaseModel):
    rating: Optional[int] = Field(None, ge=1, le=5)
    comment: Optional[str] = None

class ReviewResponse(BaseModel):
    review_id: int
    user_id: int
    rating: int
    comment: Optional[str]
    created_at: datetime
    user: Optional[UserInfo] = None
    
    class Config:
        from_attributes = True

router = APIRouter(prefix="/reviews")

@router.get("/hotel/{hotel_id}", response_model=List[ReviewResponse])
async def get_hotel_reviews(
    hotel_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Получить все отзывы об отеле с информацией о пользователях"""
    from sqlalchemy.orm import selectinload
    
    # Получаем отзывы через JOIN с bookings и rooms для фильтрации по hotel_id
    result = await db.execute(
        select(Review)
        .options(selectinload(Review.user))
        .join(Booking, Review.booking_id == Booking.booking_id)
        .join(Room, Booking.room_id == Room.room_id)
        .where(Room.hotel_id == hotel_id)
        .order_by(Review.created_at.desc())
    )
    reviews = result.scalars().all()
    
    return reviews

@router.get("/{review_id}", response_model=ReviewResponse)
async def get_review(
    review_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Получить конкретный отзыв"""
    result = await db.execute(
        select(Review).where(Review.review_id == review_id)
    )
    review = result.scalar_one_or_none()
    
    if not review:
        raise HTTPException(status_code=404, detail="Отзыв не найден")
    
    return review

@router.post("/", response_model=ReviewResponse)
async def create_review(
    review_data: ReviewCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Создать отзыв (только для завершенных бронирований)"""
    # Проверяем, что бронирование существует и принадлежит пользователю
    booking_result = await db.execute(
        select(Booking, Room.hotel_id)
        .join(Room, Booking.room_id == Room.room_id)
        .where(
            and_(
                Booking.booking_id == review_data.booking_id,
                Booking.user_id == current_user.user_id
            )
        )
    )
    result_row = booking_result.first()
    
    if not result_row:
        raise HTTPException(
            status_code=404,
            detail="Бронирование не найдено"
        )
    
    booking, hotel_id = result_row
    
    if not booking:
        raise HTTPException(
            status_code=404,
            detail="Бронирование не найдено"
        )
    
    # Проверяем, что бронирование завершено
    if booking.status != 'completed':
        raise HTTPException(
            status_code=403,
            detail="Отзыв можно оставить только для завершенных бронирований"
        )
    
    # Проверяем, нет ли уже отзыва к этому бронированию
    existing_review_check = await db.execute(
        select(Review).where(Review.booking_id == review_data.booking_id)
    )
    existing_review = existing_review_check.scalar_one_or_none()
    
    if existing_review:
        raise HTTPException(
            status_code=400,
            detail="Отзыв уже оставлен для этого бронирования"
        )
    
    # Проверяем, нет ли уже отзыва на этот отель от этого пользователя
    existing_hotel_review = await db.execute(
        select(Review)
        .join(Booking, Review.booking_id == Booking.booking_id)
        .join(Room, Booking.room_id == Room.room_id)
        .where(
            and_(
                Review.user_id == current_user.user_id,
                Room.hotel_id == hotel_id
            )
        )
    )
    existing_hotel_review_result = existing_hotel_review.scalar_one_or_none()
    
    if existing_hotel_review_result:
        raise HTTPException(
            status_code=400,
            detail="Вы уже оставляли отзыв для этого отеля"
        )
    
    # Создаем отзыв
    new_review = Review(
        booking_id=review_data.booking_id,
        user_id=current_user.user_id,
        rating=review_data.rating,
        comment=review_data.comment
    )
    
    db.add(new_review)
    await db.commit()
    await db.refresh(new_review)
    
    return new_review

@router.put("/{review_id}", response_model=ReviewResponse)
async def update_review(
    review_id: int,
    review_data: ReviewUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Обновить свой отзыв"""
    result = await db.execute(
        select(Review).where(Review.review_id == review_id)
    )
    review = result.scalar_one_or_none()
    
    if not review:
        raise HTTPException(status_code=404, detail="Отзыв не найден")
    
    # Проверяем, что это отзыв текущего пользователя
    if review.user_id != current_user.user_id:
        raise HTTPException(status_code=403, detail="Вы можете редактировать только свои отзывы")
    
    # Обновляем данные
    update_data = review_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(review, field, value)
    
    await db.commit()
    await db.refresh(review)
    
    return review

@router.delete("/{review_id}")
async def delete_review(
    review_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Удалить отзыв"""
    result = await db.execute(
        select(Review).where(Review.review_id == review_id)
    )
    review = result.scalar_one_or_none()
    
    if not review:
        raise HTTPException(status_code=404, detail="Отзыв не найден")
    
    # Проверяем права (пользователь может удалять свои отзывы, админы - любые)
    if review.user_id != current_user.user_id and current_user.role not in ["hotel_admin", "system_admin"]:
        raise HTTPException(status_code=403, detail="Нет доступа к этому отзыву")
    
    await db.delete(review)
    await db.commit()
    
    return {"message": "Отзыв успешно удален"}

@router.get("/my/all", response_model=List[ReviewResponse])
async def get_my_reviews(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получить все отзывы текущего пользователя"""
    result = await db.execute(
        select(Review)
        .where(Review.user_id == current_user.user_id)
        .order_by(Review.created_at.desc())
    )
    reviews = result.scalars().all()
    
    return reviews
