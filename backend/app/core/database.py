from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from .config import settings

# Создание асинхронного engine
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=True,  # Для отладки SQL запросов
    future=True
)

# Фабрика сессий
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

# Базовый класс для моделей
Base = declarative_base()


# Dependency для получения сессии БД
async def get_db() -> AsyncSession:
    """Dependency для получения сессии базы данных"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
