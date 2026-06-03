from __future__ import annotations

import asyncio
import logging

from aiogram import Bot, Dispatcher
from aiogram.fsm.storage.memory import MemoryStorage

from bot.config import ConfigError, Settings, load_settings
from bot.handlers.admin import build_admin_router
from bot.handlers.broadcast import build_broadcast_router
from bot.handlers.common import build_common_router
from bot.handlers.operator import build_operator_router
from bot.handlers.user import build_user_router
from bot.storage import ThreadStorage

logger = logging.getLogger(__name__)


def build_dispatcher(bot: Bot, settings: Settings, storage: ThreadStorage) -> Dispatcher:
    threads = storage.load()
    admin_ids = set(settings.admin_ids)
    operator_ids = settings.allowed_operator_ids

    dp = Dispatcher(storage=MemoryStorage())
    dp.include_router(build_common_router(admin_ids=admin_ids, support_group_id=settings.support_group_id))
    dp.include_router(
        build_admin_router(
            bot=bot,
            support_group_id=settings.support_group_id,
            admin_ids=admin_ids,
            threads=threads,
            storage=storage,
        )
    )
    dp.include_router(
        build_broadcast_router(
            bot=bot,
            support_group_id=settings.support_group_id,
            admin_ids=admin_ids,
            threads=threads,
        )
    )
    dp.include_router(
        build_user_router(
            bot=bot,
            support_group_id=settings.support_group_id,
            admin_ids=admin_ids,
            threads=threads,
            storage=storage,
        )
    )
    dp.include_router(
        build_operator_router(
            bot=bot,
            support_group_id=settings.support_group_id,
            operator_ids=operator_ids,
            threads=threads,
            storage=storage,
        )
    )
    return dp


async def run() -> None:
    try:
        settings = load_settings()
    except ConfigError as exc:
        raise SystemExit(f"Ошибка конфигурации: {exc}") from exc

    logging.basicConfig(level=getattr(logging, settings.log_level, logging.INFO))
    bot = Bot(token=settings.bot_token)
    thread_storage = ThreadStorage(settings.data_file)
    dp = build_dispatcher(bot, settings, thread_storage)

    try:
        chat = await bot.get_chat(settings.support_group_id)
        logger.info("Группа поддержки: %s", chat.title)
        if not chat.is_forum:
            raise SystemExit("Группа поддержки должна быть supergroup с включёнными темами (Forum).")

        await bot.send_message(
            chat_id=settings.support_group_id,
            text=(
                "🤖 <b>Бот поддержки запущен!</b>\n\n"
                "📝 Каждому пользователю создается отдельная тема.\n\n"
                "👑 <b>Команды:</b> /stats, /users, /help, /close, /info, /rename, /broadcast"
            ),
            parse_mode="HTML",
        )
        await dp.start_polling(bot)
    finally:
        await bot.session.close()


def main() -> None:
    asyncio.run(run())


if __name__ == "__main__":
    main()
