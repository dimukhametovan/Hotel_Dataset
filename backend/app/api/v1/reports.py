from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, text
from typing import List, Optional
from datetime import date, datetime
import csv
import io
from app.core.database import get_db
from app.models.booking import Booking
from app.models.room import Room
from app.models.hotel import Hotel
from app.models.user import User, UserRole
from app.api.dependencies import get_current_user, require_role
from pydantic import BaseModel

# Schemas для отчетов
class RoomOccupancyReport(BaseModel):
    room_id: int
    room_number: str
    hotel_name: str
    total_bookings: int
    occupied_days: int
    occupancy_rate: float

class BookingReport(BaseModel):
    booking_id: int
    guest_name: str
    hotel_name: str
    room_number: str
    check_in_date: date
    check_out_date: date
    total_price: float
    status: str
    created_at: datetime

router = APIRouter(prefix="/reports")


@router.get("/room-occupancy")
async def get_room_occupancy_report(
    hotel_id: Optional[int] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.hotel_admin, UserRole.system_admin))
):
    """
    Отчет по загрузке номеров
    Доступен администраторам отеля и системным администраторам
    """
    # Если не указаны даты, берем последние 30 дней
    if not end_date:
        end_date = date.today()
    if not start_date:
        from datetime import timedelta
        start_date = end_date - timedelta(days=30)
    
    # Базовый запрос
    query = text("""
        SELECT 
            r.room_id,
            r.room_number,
            h.name as hotel_name,
            COUNT(DISTINCT b.booking_id) as total_bookings,
            COALESCE(SUM(
                CASE 
                    WHEN b.status IN ('confirmed', 'checked_in', 'completed') THEN
                        (LEAST(b.check_out_date, :end_date) - GREATEST(b.check_in_date, :start_date))
                    ELSE 0
                END
            ), 0) as occupied_days,
            ROUND(
                COALESCE(SUM(
                    CASE 
                        WHEN b.status IN ('confirmed', 'checked_in', 'completed') THEN
                            (LEAST(b.check_out_date, :end_date) - GREATEST(b.check_in_date, :start_date))
                        ELSE 0
                    END
                ), 0) * 100.0 / NULLIF((:end_date - :start_date), 0), 2
            ) as occupancy_rate
        FROM rooms r
        JOIN hotels h ON r.hotel_id = h.hotel_id
        LEFT JOIN bookings b ON r.room_id = b.room_id
            AND b.check_in_date <= :end_date
            AND b.check_out_date >= :start_date
        WHERE 1=1
        """ + ("AND h.hotel_id = :hotel_id" if hotel_id else "") + """
        GROUP BY r.room_id, r.room_number, h.hotel_name
        ORDER BY occupancy_rate DESC
    """)
    
    params = {
        "start_date": start_date,
        "end_date": end_date
    }
    if hotel_id:
        params["hotel_id"] = hotel_id
    
    result = await db.execute(query, params)
    rows = result.fetchall()
    
    report = []
    for row in rows:
        report.append({
            "room_id": row[0],
            "room_number": row[1],
            "hotel_name": row[2],
            "total_bookings": row[3],
            "occupied_days": row[4],
            "occupancy_rate": float(row[5]) if row[5] else 0.0
        })
    
    return {
        "period": {
            "start_date": start_date,
            "end_date": end_date
        },
        "data": report
    }


@router.get("/bookings")
async def get_bookings_report(
    hotel_id: Optional[int] = None,
    status: Optional[str] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.hotel_admin, UserRole.system_admin))
):
    """
    Отчет по бронированиям
    Доступен администраторам отеля и системным администраторам
    """
    query = select(
        Booking.booking_id,
        Booking.check_in_date,
        Booking.check_out_date,
        Booking.total_price,
        Booking.status,
        Booking.created_at,
        User.first_name,
        User.last_name,
        Room.room_number,
        Hotel.name
    ).join(
        Room, Booking.room_id == Room.room_id
    ).join(
        Hotel, Room.hotel_id == Hotel.hotel_id
    ).join(
        User, Booking.user_id == User.user_id
    )
    
    # Фильтры
    if hotel_id:
        query = query.where(Hotel.hotel_id == hotel_id)
    
    if status:
        query = query.where(Booking.status == status)
    
    if start_date:
        query = query.where(Booking.check_in_date >= start_date)
    
    if end_date:
        query = query.where(Booking.check_out_date <= end_date)
    
    # Если пользователь - администратор отеля, показываем только его отели
    if current_user.role == UserRole.hotel_admin:
        # Получаем отели, которыми управляет этот администратор
        query = query.where(Hotel.admin_id == current_user.user_id)
    
    query = query.order_by(Booking.created_at.desc())
    
    result = await db.execute(query)
    rows = result.fetchall()
    
    report = []
    for row in rows:
        report.append({
            "booking_id": row[0],
            "check_in_date": row[1],
            "check_out_date": row[2],
            "total_price": float(row[3]) if row[3] else 0.0,
            "status": row[4],
            "created_at": row[5],
            "guest_name": f"{row[6]} {row[7]}",
            "room_number": row[8],
            "hotel_name": row[9]
        })
    
    return {
        "filters": {
            "hotel_id": hotel_id,
            "status": status,
            "start_date": start_date,
            "end_date": end_date
        },
        "total_count": len(report),
        "data": report
    }


@router.get("/bookings/export")
async def export_bookings_report_csv(
    hotel_id: Optional[int] = None,
    status: Optional[str] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.hotel_admin, UserRole.system_admin))
):
    """
    Экспорт отчета по бронированиям в CSV
    """
    # Получаем данные отчета
    query = select(
        Booking.booking_id,
        Booking.check_in_date,
        Booking.check_out_date,
        Booking.total_price,
        Booking.status,
        Booking.created_at,
        User.first_name,
        User.last_name,
        Room.room_number,
        Hotel.name
    ).join(
        Room, Booking.room_id == Room.room_id
    ).join(
        Hotel, Room.hotel_id == Hotel.hotel_id
    ).join(
        User, Booking.user_id == User.user_id
    )
    
    # Применяем фильтры
    if hotel_id:
        query = query.where(Hotel.hotel_id == hotel_id)
    
    if status:
        query = query.where(Booking.status == status)
    
    if start_date:
        query = query.where(Booking.check_in_date >= start_date)
    
    if end_date:
        query = query.where(Booking.check_out_date <= end_date)
    
    if current_user.role == UserRole.hotel_admin:
        query = query.where(Hotel.admin_id == current_user.user_id)
    
    query = query.order_by(Booking.created_at.desc())
    
    result = await db.execute(query)
    rows = result.fetchall()
    
    # Создаем CSV в памяти
    output = io.StringIO()
    writer = csv.writer(output)
    
    # Заголовки
    writer.writerow([
        "ID бронирования",
        "Гость",
        "Отель",
        "Номер",
        "Дата заезда",
        "Дата выезда",
        "Стоимость",
        "Статус",
        "Дата создания"
    ])
    
    # Данные
    for row in rows:
        writer.writerow([
            row[0],
            f"{row[6]} {row[7]}",
            row[9],
            row[8],
            row[1],
            row[2],
            row[3],
            row[4],
            row[5]
        ])
    
    output.seek(0)
    
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={
            "Content-Disposition": f"attachment; filename=bookings_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        }
    )
