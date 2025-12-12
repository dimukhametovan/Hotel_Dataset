from sqlalchemy import Column, Integer, String, Text, TIMESTAMP, Boolean, ForeignKey, Numeric, text
from sqlalchemy.orm import relationship
from ..core.database import Base


class Hotel(Base):
    """Модель отеля"""
    __tablename__ = "hotels"
    
    hotel_id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    address = Column(String(500), nullable=False)
    city = Column(String(100), nullable=False, index=True)
    country = Column(String(100), nullable=False)
    phone = Column(String(20))
    email = Column(String(255))
    star_rating = Column(Numeric(2, 1))
    description = Column(Text)
    admin_id = Column(Integer, ForeignKey("users.user_id", ondelete="SET NULL"))
    is_active = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    updated_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    
    # Relationships
    admin = relationship("User", back_populates="managed_hotels")
    rooms = relationship("Room", back_populates="hotel")
