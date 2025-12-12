from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from ..core.config import settings
from ..core.database import get_db
from ..core.security import decode_token
from ..models import User, UserRole


# OAuth2 схема
oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/auth/login")


# Dependency для получения текущего пользователя
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Получение текущего пользователя из токена"""
    print(f"[DEBUG] get_current_user called with token: {token[:20]}..." if token else "[DEBUG] Token is None")
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Не удалось проверить учетные данные",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = decode_token(token)
    print(f"[DEBUG] Decoded payload: {payload}")
    if payload is None:
        print("[DEBUG] Payload is None - invalid token")
        raise credentials_exception
    
    user_id = payload.get("sub")
    if user_id is None:
        raise credentials_exception
    
    # Преобразуем user_id в int, если это строка
    try:
        user_id = int(user_id)
    except (ValueError, TypeError):
        raise credentials_exception
    
    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    
    if user is None:
        raise credentials_exception
    
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Пользователь неактивен")
    
    return user


# Dependency для проверки роли
def require_role(*allowed_roles: UserRole):
    """Декоратор для проверки роли пользователя"""
    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Недостаточно прав для выполнения операции"
            )
        return current_user
    return role_checker
