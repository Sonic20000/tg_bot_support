from __future__ import annotations

import logging

from aiogram import Bot, F, Router, types

from bot.models import UserThread, now_str
from bot.services.threads import create_user_thread, send_to_thread
from bot.storage import ThreadStorage

logger = logging.getLogger(__name__)


def build_user_router(
    *,
    bot: Bot,
    support_group_id: int,
    admin_ids: set[int],
    threads: dict[int, UserThread],
    storage: ThreadStorage,
) -> Router:
    router = Router(name="user")

    @router.message(F.chat.type == "private", ~F.from_user.id.in_(admin_ids))
    async def handle_user_message(message: types.Message) -> None:
        if message.text and message.text.startswith("/"):
            await message.answer("Просто напишите ваш вопрос, и я помогу связать вас с поддержкой!")
            return

        user_id = message.from_user.id
        thread = threads.get(user_id)
        if not thread or not thread.is_active or not thread.thread_id:
            thread = await create_user_thread(
                bot=bot,
                support_group_id=support_group_id,
                threads=threads,
                message=message,
            )

        await send_to_thread(bot=bot, support_group_id=support_group_id, thread=thread, message=message)
        thread.last_active = now_str()
        thread.message_count += 1
        storage.save(threads)

        await message.answer(
            "✅ <b>Сообщение отправлено!</b>\n\n"
            "Операторы уже видят ваш вопрос и скоро ответят.\n"
            "Все ответы придут сюда, в этот чат.",
            parse_mode="HTML",
        )

    return router
