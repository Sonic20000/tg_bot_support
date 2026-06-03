from __future__ import annotations

import asyncio

from aiogram import Bot, Router, types
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup

from bot.models import UserThread


class AdminStates(StatesGroup):
    waiting_broadcast = State()


def build_broadcast_router(
    *,
    bot: Bot,
    support_group_id: int,
    admin_ids: set[int],
    threads: dict[int, UserThread],
) -> Router:
    router = Router(name="broadcast")

    def is_admin_thread(message: types.Message) -> bool:
        return bool(
            message.from_user
            and message.from_user.id in admin_ids
            and message.chat.id == support_group_id
            and message.message_thread_id is not None
        )

    @router.message(Command("broadcast"))
    async def cmd_broadcast_start(message: types.Message, state: FSMContext) -> None:
        if not is_admin_thread(message):
            if message.from_user and message.from_user.id in admin_ids:
                await message.answer("⚠️ Команду /broadcast нужно отправлять внутри темы группы поддержки.")
            return

        if not message.reply_to_message:
            await message.answer(
                "❌ <b>Для рассылки нужно ответить (reply) на сообщение!</b>\n\n"
                "1. Найдите сообщение для рассылки\n"
                "2. Ответьте на него командой /broadcast\n"
                "3. Подтвердите рассылку",
                parse_mode="HTML",
            )
            return

        active_count = sum(1 for thread in threads.values() if thread.is_active)
        await state.update_data(
            broadcast_chat_id=message.reply_to_message.chat.id,
            broadcast_message_id=message.reply_to_message.message_id,
        )
        await message.answer(
            "📢 <b>Подтверждение рассылки</b>\n\n"
            f"<b>Получатели:</b> все активные пользователи ({active_count} чел.)\n"
            "Будет скопировано сообщение, на которое вы ответили.\n\n"
            "Отправляем рассылку? Напишите «да» или «нет».",
            parse_mode="HTML",
        )
        await state.set_state(AdminStates.waiting_broadcast)

    @router.message(AdminStates.waiting_broadcast)
    async def cmd_broadcast_confirm(message: types.Message, state: FSMContext) -> None:
        if not is_admin_thread(message):
            await message.answer("⚠️ Подтверждать рассылку нужно в теме группы поддержки.")
            await state.clear()
            return

        if not message.text or message.text.lower() not in {"да", "yes", "ок", "ok", "подтверждаю"}:
            await message.answer("❌ Рассылка отменена")
            await state.clear()
            return

        data = await state.get_data()
        source_chat_id = data.get("broadcast_chat_id")
        source_message_id = data.get("broadcast_message_id")
        if not source_chat_id or not source_message_id:
            await message.answer("❌ Исходное сообщение для рассылки не найдено")
            await state.clear()
            return

        active_users = [uid for uid, thread in threads.items() if thread.is_active]
        if not active_users:
            await message.answer("❌ Нет активных пользователей для рассылки")
            await state.clear()
            return

        success = 0
        failed = 0
        total = len(active_users)
        progress_msg = await message.answer(f"📤 Начинаю рассылку для {total} пользователей...")

        for index, user_id in enumerate(active_users, 1):
            try:
                await bot.copy_message(chat_id=user_id, from_chat_id=source_chat_id, message_id=source_message_id)
                success += 1
            except Exception:
                failed += 1

            if index % 5 == 0 or index == total:
                await progress_msg.edit_text(f"📤 Рассылка: {index}/{total} ({success} успешно, {failed} ошибок)")
            await asyncio.sleep(0.2)

        await message.answer(
            "✅ <b>Рассылка завершена</b>\n\n"
            f"👥 Всего получателей: {total}\n"
            f"✅ Успешно отправлено: {success}\n"
            f"❌ Не удалось: {failed}",
            parse_mode="HTML",
        )
        await state.clear()

    return router
