from __future__ import annotations

import json
import os
import shutil
from dataclasses import asdict
from pathlib import Path

from .models import UserThread


class ThreadStorage:
    def __init__(self, path: str | os.PathLike[str]):
        self.path = Path(path)

    def load(self) -> dict[int, UserThread]:
        if not self.path.exists():
            return {}

        with self.path.open("r", encoding="utf-8") as file:
            payload = json.load(file)

        threads = payload.get("threads", {})
        return {int(user_id): UserThread.from_dict(data) for user_id, data in threads.items()}

    def save(self, threads: dict[int, UserThread]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {"threads": {str(uid): asdict(thread) for uid, thread in threads.items()}}
        tmp_path = self.path.with_suffix(self.path.suffix + ".tmp")

        if self.path.exists():
            shutil.copy2(self.path, self.path.with_suffix(self.path.suffix + ".bak"))

        with tmp_path.open("w", encoding="utf-8") as file:
            json.dump(payload, file, ensure_ascii=False, indent=2)
            file.write("\n")
            file.flush()
            os.fsync(file.fileno())

        os.replace(tmp_path, self.path)
