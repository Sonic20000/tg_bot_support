from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime

DATETIME_FORMAT = "%Y-%m-%d %H:%M:%S"


def now_str() -> str:
    return datetime.now().strftime(DATETIME_FORMAT)


@dataclass
class UserThread:
    user_id: int
    user_name: str
    username: str | None = None
    thread_id: int | None = None
    created_at: str = ""
    message_count: int = 0
    last_active: str = ""
    is_active: bool = True
    closed_at: str | None = None
    closed_by: int | None = None
    tags: list[str] = field(default_factory=list)

    @classmethod
    def from_dict(cls, data: dict) -> UserThread:
        return cls(
            user_id=int(data["user_id"]),
            user_name=data.get("user_name") or "Без имени",
            username=data.get("username"),
            thread_id=data.get("thread_id"),
            created_at=data.get("created_at") or "",
            message_count=int(data.get("message_count", 0)),
            last_active=data.get("last_active") or "",
            is_active=bool(data.get("is_active", True)),
            closed_at=data.get("closed_at"),
            closed_by=data.get("closed_by"),
            tags=list(data.get("tags", [])),
        )
