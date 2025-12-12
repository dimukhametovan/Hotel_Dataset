from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from ...core.database import get_db
from ...models import User, UserRole
from ...schemas.user import UserResponse, UserCreate, UserUpdate
from ..dependencies import get_current_user, require_role
from ...core.security import get_password_hash

router = APIRouter(prefix="/users")


@router.get("/", response_model=List[UserResponse])
async def get_users(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.system_admin))
):
    """Получение списка всех пользователей (только системный админ)"""
    result = await db.execute(select(User).offset(skip).limit(limit))
    users = result.scalars().all()
    return users


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Получение пользователя по ID"""
    # Пользователь может видеть только себя, админ - всех
    if current_user.user_id != user_id and current_user.role != UserRole.system_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Недостаточно прав")
    
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Пользователь не найден")
    
    return user


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.system_admin))
):
    """Создание пользователя (только системный админ)"""
    
    # Проверка существования email
    result = await db.execute(select(User).where(User.email == user_data.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email уже используется")
    
    new_user = User(
        email=user_data.email,
        password_hash=get_password_hash(user_data.password),
        first_name=user_data.first_name,
        last_name=user_data.last_name,
        phone=user_data.phone,
        role=user_data.role
    )
    
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    
    return new_user


@router.patch("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: int,
    user_data: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Обновление пользователя"""
    # Пользователь может обновлять только себя, админ - всех
    if current_user.user_id != user_id and current_user.role != UserRole.system_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Недостаточно прав")
    
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Пользователь не найден")
    
    # Обновление полей
    update_data = user_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(user, field, value)
    
    await db.commit()
    await db.refresh(user)
    
    return user


@router.post("/{user_id}/block", response_model=UserResponse)
async def block_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.system_admin))
):
    """Блокировка пользователя (только системный админ)"""
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Пользователь не найден")
    
    user.is_active = False
    await db.commit()
    await db.refresh(user)
    
    return user


@router.post("/{user_id}/unblock", response_model=UserResponse)
async def unblock_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.system_admin))
):
    """Разблокировка пользователя (только системный админ)"""
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Пользователь не найден")
    
    user.is_active = True
    await db.commit()
    await db.refresh(user)
    
    return user


@router.patch("/{user_id}/role", response_model=UserResponse)
async def change_user_role(
    user_id: int,
    role_data: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.system_admin))
):
    """Изменение роли пользователя (только системный админ)"""
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Пользователь не найден")
    
    # Обновляем роль
    if 'role' in role_data:
        user.role = UserRole(role_data['role'])
    
    # Обновляем hotel_id если это admin отеля
    if 'hotel_id' in role_data:
        user.hotel_id = role_data['hotel_id']
    elif user.role == UserRole.hotel_admin and 'role' in role_data and role_data['role'] == 'hotel_admin':
        # Если назначаем роль hotel_admin без указания hotel_id - не меняем существующий
        pass
    else:
        # Если роль не hotel_admin - убираем привязку к отелю
        if user.role != UserRole.hotel_admin:
            user.hotel_id = None
    
    await db.commit()
    await db.refresh(user)
    
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_role(UserRole.system_admin))
):
    """Удаление пользователя (только системный админ)"""
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Пользователь не найден")
    
    await db.delete(user)
    await db.commit()
    
    return None
