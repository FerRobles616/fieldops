import uuid
from datetime import datetime

from pydantic import BaseModel


class WorkOrderPhotoRead(BaseModel):
    id: uuid.UUID
    work_order_id: uuid.UUID
    caption: str | None
    content_type: str
    file_size: int
    created_at: datetime
    download_url: str
