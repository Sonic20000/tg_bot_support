from __future__ import annotations

from aiogram import Router, types
from aiogram.filters import Command


def build_common_router(admin_ids: set[int], support_group_id: int) -> Router:
    router = Router(name="common")

    @router.message(Command("start"))
    async def cmd_start(message: types.Message) -> None:
        user_id = message.from_user.id
        if user_id in admin_ids and message.chat.type == "private":
            await message.answer(
                "👑 <b>Админ-панель бота поддержки</b>\n\n"
                "<b>Основные команды:</b>\n"
                "/stats - статистика (в теме)\n"
                "/users - список пользователей (в теме)\n"
                "/help - помощь по командам\n\n"
                "<b>Команды в теме пользователя:</b>\n"
                "/close - закрыть тему\n"
                "/info - информация о пользователе\n"
                "/rename [текст] - переименовать тему\n"
                "/broadcast - рассылка по reply\n\n"
                "⚡ <b>Все админские команды работают в темах группы!</b>",
                parse_mode="HTML",
            )
            return

        await message.answer(
            "👋 <b>Добро пожаловать в поддержку!</b>\n\n"
            "Просто напишите свой вопрос, и я создам для вас отдельную тему "
            "в чате поддержки, где операторы смогут вам помочь.\n\n"
            "📝 <b>Как это работает:</b>\n"
            "1. Вы пишете сюда вопрос\n"
            "2. Создается ваша личная тема в чате операторов\n"
            "3. Операторы отвечают в вашей теме\n"
            "4. Вы получаете ответы здесь\n\n"
            "⚡ <b>Начните прямо сейчас!</b>",
            parse_mode="HTML",
        )

    @router.message(Command("help"))
    async def cmd_help(message: types.Message) -> None:
        user_id = message.from_user.id
        if user_id in admin_ids and (message.chat.id == support_group_id or message.message_thread_id):
            await message.answer(
                "🆘 <b>Админские команды:</b>\n\n"
                "📋 <b>В любой теме:</b>\n"
                "/stats - статистика бота\n"
                "/users - список пользователей\n\n"
                "🔧 <b>В теме пользователя:</b>\n"
                "/close - закрыть тему\n"
                "/info - информация о пользователе\n"
                "/rename [текст] - переименовать тему\n"
                "/broadcast - начать рассылку reply-сообщения\n\n"
                "📝 <b>Как работать:</b>\n"
                "1. Пишите команды прямо в теме\n"
                "2. Для рассылки нужен reply на сообщение",
                parse_mode="HTML",
            )
            return

        await message.answer(
            "ℹ️ <b>Помощь</b>\n\n"
            "Просто напишите свой вопрос, и я передам его нашей команде поддержки.\n"
            "Операторы ответят вам в этом же чате.",
            parse_mode="HTML",
        )

    return router
