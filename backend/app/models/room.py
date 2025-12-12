from sqlalchemy import Column, Integer, String, Text, Numeric, Boolean, ForeignKey, TIMESTAMP, text, Table
from sqlalchemy.orm import relationship
from ..core.database import Base


# Связующая таблица для many-to-many отношения Room-Amenity
room_amenities = Table(
    'room_amenities',
    Base.metadata,
    Column('room_id', Integer, ForeignKey('rooms.room_id', ondelete="CASCADE"), primary_key=True),
    Column('amenity_id', Integer, ForeignKey('amenities.amenity_id', ondelete="CASCADE"), primary_key=True),
    Column('created_at', TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
)


class RoomType(Base):
    """Модель типа номера"""
    __tablename__ = "roomtypes"
    
    roomtype_id = Column(Integer, primary_key=True, index=True)
    type_name = Column(String(100), nullable=False)
    description = Column(Text)
    price_per_night = Column(Numeric(10, 2), nullable=False)
    max_occupancy = Column(Integer, default=2)
    created_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    
    # Relationships
    rooms = relationship("Room", back_populates="room_type")


class Room(Base):
    """Модель номера"""
    __tablename__ = "rooms"
    
    room_id = Column(Integer, primary_key=True, index=True)
    hotel_id = Column(Integer, ForeignKey("hotels.hotel_id", ondelete="CASCADE"), nullable=False, index=True)
    roomtype_id = Column(Integer, ForeignKey("roomtypes.roomtype_id", ondelete="RESTRICT"), nullable=False)
    room_number = Column(String(10), nullable=False)
    floor = Column(Integer)
    price_per_night = Column(Numeric(10, 2))  # Переопределяет цену из roomtype
    is_available = Column(Boolean, default=True, index=True)
    description = Column(Text)
    created_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    updated_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    
    # Relationships
    hotel = relationship("Hotel", back_populates="rooms")
    room_type = relationship("RoomType", back_populates="rooms")
    amenities = relationship("Amenity", secondary=room_amenities, back_populates="rooms")
    bookings = relationship("Booking", back_populates="room")


class Amenity(Base):
    """Модель удобства"""
    __tablename__ = "amenities"
    
    amenity_id = Column(Integer, primary_key=True, index=True)
    amenity_name = Column(String(255), nullable=False, unique=True)
    description = Column(Text)
    icon = Column(String(50))
    created_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    
    # Relationships
    rooms = relationship("Room", secondary=room_amenities, back_populates="amenities")
