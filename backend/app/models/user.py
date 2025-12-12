from sqlalchemy import Column, Integer, String, Boolean, TIMESTAMP, Enum as SQLEnum, text
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from ..core.database import Base


class UserRole(str, enum.Enum):
    """Роли пользователей"""
    guest = "guest"
    hotel_admin = "hotel_admin"
    system_admin = "system_admin"


class User(Base):
    """Модель пользователя"""
    __tablename__ = "users"
    
    user_id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    phone = Column(String(20))
    role = Column(SQLEnum(UserRole, name="user_role"), nullable=False, default=UserRole.guest)
    is_active = Column(Boolean, default=True)
    hotel_id = Column(Integer)  # Для привязки hotel_admin к отелю
    created_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    updated_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    
    # Relationships
    bookings = relationship("Booking", back_populates="user")
    reviews = relationship("Review", back_populates="user")
    managed_hotels = relationship("Hotel", back_populates="admin")
    
    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"
