from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class ReviewBase(BaseModel):
    hotel_id: int
    rating: int = Field(ge=1, le=5)
    comment: Optional[str] = None

class ReviewCreateRequest(ReviewBase):
    pass

class ReviewUpdateRequest(BaseModel):
    rating: Optional[int] = Field(None, ge=1, le=5)
    comment: Optional[str] = None

class ReviewResponse(ReviewBase):
    review_id: int
    user_id: int
    created_at: datetime
    
    class Config:
        from_attributes = True
