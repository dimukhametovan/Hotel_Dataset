from sqlalchemy import Column, Integer, String, Date, TIMESTAMP, Text, ForeignKey, Numeric, Boolean, text
from sqlalchemy.orm import relationship
from ..core.database import Base


class Booking(Base):
    """Модель бронирования"""
    __tablename__ = "bookings"
    
    booking_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False, index=True)
    room_id = Column(Integer, ForeignKey("rooms.room_id", ondelete="RESTRICT"), nullable=False, index=True)
    check_in_date = Column(Date, nullable=False, index=True)
    check_out_date = Column(Date, nullable=False, index=True)
    status = Column(String(20), default="pending", index=True)
    total_price = Column(Numeric(10, 2))  # Рассчитывается автоматически триггером
    guests_count = Column(Integer, default=1)
    booking_date = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    created_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    updated_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    
    # Relationships
    user = relationship("User", back_populates="bookings")
    room = relationship("Room", back_populates="bookings")
    review = relationship("Review", back_populates="booking", uselist=False)


class Review(Base):
    """Модель отзыва"""
    __tablename__ = "reviews"
    
    review_id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.booking_id", ondelete="CASCADE"), nullable=False, unique=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False, index=True)
    rating = Column(Integer, nullable=False)  # 1-5
    comment = Column(Text)
    review_date = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    created_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    updated_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    
    # Relationships
    booking = relationship("Booking", back_populates="review")
    user = relationship("User", back_populates="reviews")

