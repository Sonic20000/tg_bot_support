from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def load_dotenv(dotenv_path: str | os.PathLike[str] | None = None) -> bool:
    """Load simple KEY=VALUE pairs from a .env file without overriding environment variables."""
    path = Path(dotenv_path or ".env")
    if not path.exists():
        return False

    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key:
            os.environ.setdefault(key, value)
    return True


BOT_API_SUPERGROUP_PREFIX = "-100"


class ConfigError(ValueError):
    """Raised when bot configuration is invalid."""


@dataclass(frozen=True)
class Settings:
    bot_token: str
    support_group_id: int
    admin_ids: list[int]
    data_file: Path
    log_level: str = "INFO"
    operator_ids: list[int] | None = None

    @property
    def allowed_operator_ids(self) -> set[int]:
        return set(self.operator_ids or self.admin_ids)


def parse_int_list(raw: str, name: str) -> list[int]:
    values: list[int] = []
    for chunk in raw.split(","):
        value = chunk.strip()
        if not value:
            continue
        try:
            values.append(int(value))
        except ValueError as exc:
            raise ConfigError(f"{name} должен содержать ID через запятую: {raw!r}") from exc
    return values


def parse_support_group_id(raw: str) -> int:
    value = raw.strip()
    if not value:
        raise ConfigError("SUPPORT_GROUP_ID не задан")
    try:
        chat_id = int(value)
    except ValueError as exc:
        raise ConfigError("SUPPORT_GROUP_ID должен быть целым числом Bot API chat_id") from exc

    # Bot API supergroup/channel dialog IDs are negative and commonly look like -100... .
    # Telegram documents this as a conversion of MTProto channel IDs by adding
    # 1000000000000 and making the result negative.
    if not str(chat_id).startswith(BOT_API_SUPERGROUP_PREFIX):
        raise ConfigError(
            "SUPPORT_GROUP_ID должен быть ID supergroup/forum из Bot API, обычно в формате -100..."
        )
    return chat_id


def load_settings(env_file: str | os.PathLike[str] | None = None) -> Settings:
    if env_file:
        load_dotenv(env_file)
    else:
        load_dotenv()

    bot_token = os.getenv("BOT_TOKEN", "").strip()
    if not bot_token:
        raise ConfigError("BOT_TOKEN не задан")

    support_group_id = parse_support_group_id(os.getenv("SUPPORT_GROUP_ID", ""))

    admin_ids = parse_int_list(os.getenv("ADMIN_IDS", ""), "ADMIN_IDS")
    if not admin_ids:
        raise ConfigError("ADMIN_IDS должен содержать хотя бы один Telegram user_id")

    operator_raw = os.getenv("OPERATOR_IDS", "").strip()
    operator_ids = parse_int_list(operator_raw, "OPERATOR_IDS") if operator_raw else admin_ids

    return Settings(
        bot_token=bot_token,
        support_group_id=support_group_id,
        admin_ids=admin_ids,
        operator_ids=operator_ids,
        data_file=Path(os.getenv("DATA_FILE", "threads_data.json")),
        log_level=os.getenv("LOG_LEVEL", "INFO").upper(),
    )
