from __future__ import annotations

from aiogram import Bot, F, Router, types

from bot.models import UserThread, now_str
from bot.services.threads import find_by_thread_id, forward_to_user
from bot.storage import ThreadStorage


def build_operator_router(
    *,
    bot: Bot,
    support_group_id: int,
    operator_ids: set[int],
    threads: dict[int, UserThread],
    storage: ThreadStorage,
) -> Router:
    router = Router(name="operator")

    @router.message(F.chat.id == support_group_id, F.message_thread_id)
    async def handle_operator_message(message: types.Message) -> None:
        if message.text and message.text.startswith("/"):
            return
        if not message.from_user or message.from_user.id not in operator_ids:
            return

        thread = find_by_thread_id(threads, message.message_thread_id)
        if not thread:
            return

        await forward_to_user(bot=bot, user_id=thread.user_id, message=message)
        thread.last_active = now_str()
        storage.save(threads)

    return router
