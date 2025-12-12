from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .core.config import settings

# Создание приложения
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Корневой endpoint
@app.get("/")
async def root():
    return {
        "message": "Hotel Booking Service API",
        "version": settings.VERSION,
        "docs": "/docs"
    }


# Health check
@app.get("/health")
async def health_check():
    return {"status": "ok"}


# Подключение роутеров
from .api.v1 import auth, users, hotels, rooms, bookings, reviews, roomtypes, amenities, reports

app.include_router(auth.router, prefix=settings.API_V1_STR, tags=["auth"])
app.include_router(users.router, prefix=settings.API_V1_STR, tags=["users"])
app.include_router(hotels.router, prefix=settings.API_V1_STR, tags=["hotels"])
app.include_router(rooms.router, prefix=settings.API_V1_STR, tags=["rooms"])
app.include_router(roomtypes.router, prefix=settings.API_V1_STR, tags=["roomtypes"])
app.include_router(amenities.router, prefix=settings.API_V1_STR, tags=["amenities"])
app.include_router(bookings.router, prefix=settings.API_V1_STR, tags=["bookings"])
app.include_router(reviews.router, prefix=settings.API_V1_STR, tags=["reviews"])
app.include_router(reports.router, prefix=settings.API_V1_STR, tags=["reports"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
