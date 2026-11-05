from fastapi import APIRouter

from app.api.deps import CurrentUser
from app.schemas.auth import UserRead

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserRead)
def read_current_user(current_user: CurrentUser) -> UserRead:
    return UserRead.model_validate(current_user)
