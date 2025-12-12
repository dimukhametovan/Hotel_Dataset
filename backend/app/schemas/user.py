from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime
from ..models.user import UserRole


# Базовые схемы
class UserBase(BaseModel):
    email: EmailStr
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)


# Схема для создания пользователя
class UserCreate(UserBase):
    password: str = Field(..., min_length=6)
    role: UserRole = UserRole.guest


# Схема для регистрации (только гость)
class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6)
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)


# Схема для обновления пользователя
class UserUpdate(BaseModel):
    first_name: Optional[str] = Field(None, min_length=1, max_length=100)
    last_name: Optional[str] = Field(None, min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    is_active: Optional[bool] = None


# Схема ответа
class UserResponse(UserBase):
    user_id: int
    role: UserRole
    is_active: bool
    hotel_id: Optional[int] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


# Схема для логина
class UserLogin(BaseModel):
    email: EmailStr
    password: str


# Схема токена
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


# Схема данных токена
class TokenData(BaseModel):
    user_id: Optional[int] = None
    email: Optional[str] = None
    role: Optional[UserRole] = None
