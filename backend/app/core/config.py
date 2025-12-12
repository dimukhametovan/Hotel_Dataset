from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "postgresql+asyncpg://postgres:123456@172.30.219.23:5432/hotel_booking"
    DATABASE_URL_SYNC: str = "postgresql://postgres:123456@172.30.219.23:5432/hotel_booking"
    
    # Security
    SECRET_KEY: str = "your-secret-key-change-in-production-min-32-characters-long"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # CORS
    BACKEND_CORS_ORIGINS: List[str] = ["*"]
    
    # Application
    PROJECT_NAME: str = "Hotel Booking Service"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
