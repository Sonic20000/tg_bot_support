from __future__ import annotations

from aiogram import Bot, Router, types
from aiogram.filters import Command

from bot.models import UserThread
from bot.services.formatting import html_escape, trim_text
from bot.services.threads import close_user_thread, find_by_thread_id, relative_activity
from bot.storage import ThreadStorage


def build_admin_router(
    *,
    bot: Bot,
    support_group_id: int,
    admin_ids: set[int],
    threads: dict[int, UserThread],
    storage: ThreadStorage,
) -> Router:
    router = Router(name="admin")

    def is_admin(message: types.Message) -> bool:
        return message.from_user and message.from_user.id in admin_ids

    async def require_admin_thread(message: types.Message, command: str) -> bool:
        if not is_admin(message):
            return False
        if message.chat.id != support_group_id or message.message_thread_id is None:
            await message.answer(f"⚠️ Команду /{command} нужно отправлять внутри темы группы поддержки.")
            return False
        return True

    @router.message(Command("stats"))
    async def cmd_stats(message: types.Message) -> None:
        if not await require_admin_thread(message, "stats"):
            return

        active = sum(1 for thread in threads.values() if thread.is_active)
        total = len(threads)
        total_messages = sum(thread.message_count for thread in threads.values())
        today = __import__("datetime").datetime.now().strftime("%Y-%m-%d")
        today_count = sum(1 for thread in threads.values() if thread.created_at.startswith(today))

        await message.answer(
            "📊 <b>Статистика бота поддержки</b>\n\n"
            f"👥 <b>Всего пользователей:</b> {total}\n"
            f"🟢 <b>Активных тем:</b> {active}\n"
            f"🔴 <b>Закрытых тем:</b> {total - active}\n"
            f"📅 <b>Новых сегодня:</b> {today_count}\n"
            f"💬 <b>Всего сообщений:</b> {total_messages}\n"
            f"📈 <b>Среднее на пользователя:</b> {total_messages // total if total else 0}",
            parse_mode="HTML",
        )

    @router.message(Command("users"))
    async def cmd_users(message: types.Message) -> None:
        if not await require_admin_thread(message, "users"):
            return
        if not threads:
            await message.answer("📭 Нет пользователей")
            return

        sorted_threads = sorted(threads.values(), key=lambda thread: thread.last_active or "", reverse=True)[:10]
        response = "👥 <b>Последние активные пользователи</b>\n\n"
        for index, thread in enumerate(sorted_threads, 1):
            status = "🟢" if thread.is_active else "🔴"
            time_str = thread.last_active[11:16] if thread.last_active else "??:??"
            name = trim_text(thread.user_name, 20)
            response += (
                f"{index}. {status} <b>{html_escape(name)}</b>\n"
                f"   🆔 ID: {thread.user_id}\n"
                f"   🕐 {time_str} | 📨 {thread.message_count}\n"
                f"   💬 Тема ID: {thread.thread_id or 'нет'}\n\n"
            )
        await message.answer(response, parse_mode="HTML")

    @router.message(Command("info"))
    async def cmd_info(message: types.Message) -> None:
        if not await require_admin_thread(message, "info"):
            return
        thread = find_by_thread_id(threads, message.message_thread_id)
        if not thread:
            await message.answer("❌ Не удалось найти информацию о теме")
            return

        await message.answer(
            "👤 <b>Информация о теме</b>\n\n"
            f"📛 <b>Пользователь:</b> {html_escape(thread.user_name)}\n"
            f"🆔 <b>ID пользователя:</b> {thread.user_id}\n"
            f"💬 <b>ID темы:</b> {thread.thread_id}\n"
            f"📅 <b>Создана:</b> {thread.created_at}\n"
            f"📊 <b>Сообщений от пользователя:</b> {thread.message_count}\n"
            f"⏰ <b>Последняя активность:</b> {relative_activity(thread.last_active)}\n"
            f"🔧 <b>Статус:</b> {'🟢 Активна' if thread.is_active else '🔴 Закрыта'}",
            parse_mode="HTML",
        )

    @router.message(Command("rename"))
    async def cmd_rename(message: types.Message) -> None:
        if not await require_admin_thread(message, "rename"):
            return
        parts = message.text.split(maxsplit=1)
        if len(parts) < 2 or not parts[1].strip():
            await message.answer("❌ Используйте: /rename Новое название темы")
            return
        new_name = trim_text(parts[1].strip(), 128)
        await bot.edit_forum_topic(chat_id=support_group_id, message_thread_id=message.message_thread_id, name=new_name)
        await message.answer(f"✅ Тема переименована в: <b>{html_escape(new_name)}</b>", parse_mode="HTML")

    @router.message(Command("close"))
    async def cmd_close(message: types.Message) -> None:
        if not await require_admin_thread(message, "close"):
            return
        thread = find_by_thread_id(threads, message.message_thread_id)
        if not thread:
            await message.answer("❌ Не удалось найти тему или пользователя")
            return
        if not thread.is_active:
            await message.answer("⚠️ Эта тема уже закрыта")
            return

        old_thread_id = thread.thread_id

        try:
            await bot.send_message(
                chat_id=thread.user_id,
                text=(
                    "🔒 <b>Ваша тема в поддержке закрыта</b>\n\n"
                    "Если появится новый вопрос — пишите, создадим новую тему!"
                ),
                parse_mode="HTML",
            )
        except Exception:
            pass

        await message.answer(
            "✅ <b>Тема закрыта</b>\n\n"
            f"👤 Пользователь: {html_escape(thread.user_name)}\n"
            f"🆔 ID: {thread.user_id}\n"
            f"💬 Старый thread ID: {old_thread_id}",
            parse_mode="HTML",
        )

        await close_user_thread(
            bot=bot,
            support_group_id=support_group_id,
            thread=thread,
            closed_by=message.from_user.id,
        )
        thread.thread_id = None
        storage.save(threads)

    return router
