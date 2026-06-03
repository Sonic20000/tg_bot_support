from __future__ import annotations

from html import escape

MAX_TOPIC_NAME_LENGTH = 128
MAX_CAPTION_LENGTH = 1024


def html_escape(value: object) -> str:
    return escape(str(value), quote=False)


def trim_text(value: str, max_length: int, suffix: str = "...") -> str:
    if len(value) <= max_length:
        return value
    return value[: max_length - len(suffix)] + suffix


def make_topic_name(user_name: str) -> str:
    return trim_text(f"👤 {user_name}", MAX_TOPIC_NAME_LENGTH)


def make_closed_topic_name(user_name: str) -> str:
    return trim_text(f"🔒 ЗАКРЫТО: {user_name}", MAX_TOPIC_NAME_LENGTH)
