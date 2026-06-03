from __future__ import annotations

import logging
from datetime import datetime

from aiogram import Bot, types

from bot.models import DATETIME_FORMAT, UserThread, now_str
from bot.services.formatting import html_escape, make_closed_topic_name, make_topic_name, trim_text

logger = logging.getLogger(__name__)


def display_user_name(user: types.User) -> str:
    user_name = user.full_name or "Без имени"
    if user.username:
        user_name += f" (@{user.username})"
    return user_name


def find_by_thread_id(threads: dict[int, UserThread], thread_id: int) -> UserThread | None:
    for thread in threads.values():
        if thread.thread_id == thread_id:
            return thread
    return None


def relative_activity(value: str) -> str:
    if not value:
        return "никогда"
    try:
        last_active = datetime.strptime(value, DATETIME_FORMAT)
    except ValueError:
        return value

    diff = datetime.now() - last_active
    if diff.days > 0:
        return f"{diff.days} дней назад"
    hours = diff.seconds // 3600
    if hours > 0:
        return f"{hours} часов назад"
    minutes = diff.seconds // 60
    if minutes > 0:
        return f"{minutes} минут назад"
    return "только что"


async def create_user_thread(
    *,
    bot: Bot,
    support_group_id: int,
    threads: dict[int, UserThread],
    message: types.Message,
) -> UserThread:
    user = message.from_user
    user_name = display_user_name(user)
    topic_name = make_topic_name(user_name)
    created_at = now_str()

    forum_topic = await bot.create_forum_topic(chat_id=support_group_id, name=topic_name)
    thread_id = forum_topic.message_thread_id

    welcome_text = (
        "🎫 <b>Новая тема создана</b>\n\n"
        f"👤 <b>Пользователь:</b> {html_escape(user_name)}\n"
        f"🆔 <b>ID:</b> {user.id}\n"
        f"📅 <b>Время:</b> {created_at}\n\n"
        "💬 <b>Все сообщения пользователя будут здесь</b>\n"
        "📝 <b>Чтобы ответить — просто пишите в эту тему</b>\n\n"
        "🔧 <b>Команды админа:</b> /close, /info, /rename, /stats, /users, /broadcast"
    )
    await bot.send_message(
        chat_id=support_group_id,
        message_thread_id=thread_id,
        text=welcome_text,
        parse_mode="HTML",
    )

    thread = UserThread(
        user_id=user.id,
        user_name=user_name,
        username=user.username,
        thread_id=thread_id,
        created_at=created_at,
        last_active=created_at,
        is_active=True,
    )
    threads[user.id] = thread
    logger.info("Создана тема %s для пользователя %s", thread_id, user.id)
    return thread


async def close_user_thread(
    *,
    bot: Bot,
    support_group_id: int,
    thread: UserThread,
    closed_by: int,
) -> None:
    if thread.thread_id is None:
        return

    await bot.edit_forum_topic(
        chat_id=support_group_id,
        message_thread_id=thread.thread_id,
        name=make_closed_topic_name(thread.user_name),
    )
    await bot.close_forum_topic(chat_id=support_group_id, message_thread_id=thread.thread_id)
    thread.is_active = False
    thread.closed_at = now_str()
    thread.closed_by = closed_by


async def send_to_thread(*, bot: Bot, support_group_id: int, thread: UserThread, message: types.Message) -> None:
    if not thread.thread_id:
        return

    timestamp = datetime.now().strftime("%H:%M")
    header = f"🕐 <b>{timestamp}</b>\n\n"

    if message.text:
        await bot.send_message(
            chat_id=support_group_id,
            message_thread_id=thread.thread_id,
            text=header + html_escape(message.text),
            parse_mode="HTML",
        )
    elif message.photo:
        caption = trim_text(header + html_escape(message.caption or ""), 1024)
        await bot.send_photo(
            chat_id=support_group_id,
            message_thread_id=thread.thread_id,
            photo=message.photo[-1].file_id,
            caption=caption,
            parse_mode="HTML",
        )
    elif message.video:
        caption = trim_text(header + html_escape(message.caption or ""), 1024)
        await bot.send_video(
            chat_id=support_group_id,
            message_thread_id=thread.thread_id,
            video=message.video.file_id,
            caption=caption,
            parse_mode="HTML",
        )
    elif message.document:
        caption = trim_text(header + html_escape(message.caption or ""), 1024)
        await bot.send_document(
            chat_id=support_group_id,
            message_thread_id=thread.thread_id,
            document=message.document.file_id,
            caption=caption,
            parse_mode="HTML",
        )
    else:
        await bot.forward_message(
            chat_id=support_group_id,
            message_thread_id=thread.thread_id,
            from_chat_id=message.chat.id,
            message_id=message.message_id,
        )


async def forward_to_user(*, bot: Bot, user_id: int, message: types.Message) -> None:
    reply_header = "📩 <b>Ответ от поддержки:</b>\n\n"

    if message.text:
        await bot.send_message(chat_id=user_id, text=reply_header + html_escape(message.text), parse_mode="HTML")
    elif message.photo:
        await bot.send_photo(
            chat_id=user_id,
            photo=message.photo[-1].file_id,
            caption=trim_text(reply_header + html_escape(message.caption or ""), 1024),
            parse_mode="HTML",
        )
    elif message.video:
        await bot.send_video(
            chat_id=user_id,
            video=message.video.file_id,
            caption=trim_text(reply_header + html_escape(message.caption or ""), 1024),
            parse_mode="HTML",
        )
    elif message.document:
        await bot.send_document(
            chat_id=user_id,
            document=message.document.file_id,
            caption=trim_text(reply_header + html_escape(message.caption or ""), 1024),
            parse_mode="HTML",
        )
    else:
        await bot.send_message(chat_id=user_id, text=reply_header + "Сообщение от поддержки:", parse_mode="HTML")
        await bot.forward_message(chat_id=user_id, from_chat_id=message.chat.id, message_id=message.message_id)
