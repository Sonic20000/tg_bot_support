#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Установка Telegram бота поддержки на VPS ===${NC}"

# 1. Обновление системы
echo -e "${YELLOW}[1/8] Обновление системы...${NC}"
sudo apt update && sudo apt upgrade -y

# 2. Установка Python и pip
echo -e "${YELLOW}[2/8] Установка Python и pip...${NC}"
sudo apt install -y python3 python3-pip python3-venv git curl

# 3. Создание папки для бота
echo -e "${YELLOW}[3/8] Создание папки бота...${NC}"
mkdir -p ~/support_bot
cd ~/support_bot

# 4. Создание виртуального окружения
echo -e "${YELLOW}[4/8] Создание виртуального окружения...${NC}"
python3 -m venv venv
source venv/bin/activate

# 5. Установка зависимостей
echo -e "${YELLOW}[5/8] Установка зависимостей...${NC}"
pip install --upgrade pip
pip install aiogram python-dotenv

# 6. Создание файлов бота
echo -e "${YELLOW}[6/8] Создание файлов бота...${NC}"

# Создаем main.py
cat > main.py << 'EOF'
import asyncio
import logging
from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.fsm.storage.memory import MemoryStorage
from datetime import datetime
import json
import os
from dataclasses import dataclass, asdict
from typing import Dict, Optional

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Токены и ID
BOT_TOKEN = "" # Обязательно в кавычках
SUPPORT_GROUP_ID =  # ID группы с темами
ADMIN_IDS = [12345678]  # ID админов

# Инициализация бота
bot = Bot(token=BOT_TOKEN)
storage = MemoryStorage()
dp = Dispatcher(storage=storage)

# Модель данных
@dataclass
class UserThread:
    user_id: int
    user_name: str
    thread_id: Optional[int] = None
    created_at: str = ""
    message_count: int = 0
    last_active: str = ""
    is_active: bool = True

# Хранилище
user_threads: Dict[int, UserThread] = {}
DATA_FILE = "threads_data.json"

def save_data():
    try:
        data = {
            'threads': {uid: asdict(thread) for uid, thread in user_threads.items()}
        }
        with open(DATA_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        logger.error(f"Ошибка сохранения: {e}")

def load_data():
    global user_threads
    try:
        if os.path.exists(DATA_FILE):
            with open(DATA_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
                user_threads = {int(uid): UserThread(**tdata) for uid, tdata in data['threads'].items()}
                logger.info(f"Загружено {len(user_threads)} тем")
    except Exception as e:
        logger.error(f"Ошибка загрузки: {e}")

load_data()

# Состояния для админских команд
class AdminStates(StatesGroup):
    waiting_broadcast = State()

# ========== КОМАНДЫ ДЛЯ ВСЕХ ==========

@dp.message(Command("start"))
async def cmd_start(message: types.Message):
    user_id = message.from_user.id
    
    if user_id in ADMIN_IDS and message.chat.type == "private":
        admin_text = (
            "👑 <b>Админ-панель бота поддержки</b>\n\n"
            "<b>Основные команды:</b>\n"
            "/stats - статистика (в любой теме)\n"
            "/users - список пользователей (в любой теме)\n"
            "/help - помощь по командам\n\n"
            "<b>Команды в теме пользователя:</b>\n"
            "/close - закрыть тему\n"
            "/info - информация о пользователе\n"
            "/rename [текст] - переименовать тему\n\n"
            "⚡ <b>Все админские команды работают в темах группы!</b>"
        )
        await message.answer(admin_text, parse_mode="HTML")
        return
    
    # Для обычных пользователей
    welcome = (
        "👋 <b>Добро пожаловать в поддержку!</b>\n\n"
        "Просто напишите свой вопрос, и я создам для вас отдельную тему "
        "в чате поддержки, где операторы смогут вам помочь.\n\n"
        "📝 <b>Как это работает:</b>\n"
        "1. Вы пишете сюда вопрос\n"
        "2. Создается ваша личная тема в чате операторов\n"
        "3. Операторы отвечают в вашей теме\n"
        "4. Вы получаете ответы здесь\n\n"
        "⚡ <b>Начните прямо сейчас!</b>"
    )
    await message.answer(welcome, parse_mode="HTML")

@dp.message(Command("help"))
async def cmd_help(message: types.Message):
    user_id = message.from_user.id
    
    # Если админ в теме или группе
    if user_id in ADMIN_IDS and (message.chat.id == SUPPORT_GROUP_ID or message.message_thread_id):
        help_text = (
            "🆘 <b>Админские команды:</b>\n\n"
            "📋 <b>В любой теме:</b>\n"
            "/stats - статистика бота\n"
            "/users - список пользователей\n\n"
            "🔧 <b>В теме пользователя:</b>\n"
            "/close - закрыть тему\n"
            "/info - информация о пользователе\n"
            "/rename [текст] - переименовать тему\n"
            "/broadcast - начать рассылку\n\n"
            "📝 <b>Как работать:</b>\n"
            "1. Пишите команды прямо в теме\n"
            "2. Для рассылки нужен reply на сообщение"
        )
        await message.answer(help_text, parse_mode="HTML")
        return
    
    # Для обычных пользователей
    await message.answer(
        "ℹ️ <b>Помощь</b>\n\n"
        "Просто напишите свой вопрос, и я передам его нашей команде поддержки.\n"
        "Операторы ответят вам в этом же чате.\n\n"
        "Для связи с администратором используйте команду /start",
        parse_mode="HTML"
    )

# ========== АДМИНСКИЕ КОМАНДЫ В ТЕМАХ ==========

@dp.message(Command("stats"))
async def cmd_stats_in_thread(message: types.Message):
    """Команда /stats - статистика (в теме)"""
    logger.info(
        f"/stats от {message.from_user.id} в чате {message.chat.id}, "
        f"thread={message.message_thread_id}, type={message.chat.type}"
    )

    # 1. Проверка: админ ли это
    if message.from_user.id not in ADMIN_IDS:
        logger.info("Отказано в /stats: пользователь не админ")
        return

    # 2. Проверка: нужная группа
    if message.chat.id != SUPPORT_GROUP_ID:
        await message.answer("⚠️ Команду /stats нужно отправлять в группе поддержки.")
        return

    # 3. Проверка: именно тема, а не общий чат
    if message.message_thread_id is None:
        await message.answer("⚠️ Команду /stats нужно отправлять внутри темы (треда).")
        return

    logger.info(f"Админ {message.from_user.id} запросил статистику в теме")

    active = sum(1 for t in user_threads.values() if t.is_active)
    total = len(user_threads)
    today = datetime.now().strftime("%Y-%m-%d")
    today_count = sum(1 for t in user_threads.values() if t.created_at.startswith(today))
    total_messages = sum(t.message_count for t in user_threads.values())

    stats = (
        f"📊 <b>Статистика бота поддержки</b>\n\n"
        f"👥 <b>Всего пользователей:</b> {total}\n"
        f"🟢 <b>Активных тем:</b> {active}\n"
        f"🔴 <b>Закрытых тем:</b> {total - active}\n"
        f"📅 <b>Новых сегодня:</b> {today_count}\n"
        f"💬 <b>Всего сообщений:</b> {total_messages}\n"
        f"📈 <b>Среднее на пользователя:</b> {total_messages//total if total > 0 else 0}\n\n"
        f"⏰ <b>Текущее время:</b> {datetime.now().strftime('%H:%M:%S')}"
    )

    await message.answer(stats, parse_mode="HTML")


@dp.message(Command("users"))
async def cmd_users_in_thread(message: types.Message):
    """Команда /users - список пользователей (в теме)"""
    logger.info(
        f"/users от {message.from_user.id} в чате {message.chat.id}, "
        f"thread={message.message_thread_id}, type={message.chat.type}"
    )

    if message.from_user.id not in ADMIN_IDS:
        logger.info("Отказано в /users: пользователь не админ")
        return

    if message.chat.id != SUPPORT_GROUP_ID or message.message_thread_id is None:
        await message.answer("⚠️ Команду /users нужно отправлять внутри темы группы поддержки.")
        return

    if not user_threads:
        await message.answer("📭 Нет активных пользователей")
        return

    # Сортируем по последней активности
    sorted_threads = sorted(
        user_threads.values(),
        key=lambda x: x.last_active if x.last_active else "",
        reverse=True
    )[:10]  # Последние 10

    response = "👥 <b>Последние активные пользователи</b>\n\n"

    for i, thread in enumerate(sorted_threads, 1):
        status = "🟢" if thread.is_active else "🔴"
        time_str = thread.last_active[11:16] if thread.last_active else "??:??"
        name = thread.user_name
        if len(name) > 20:
            name = name[:17] + "..."

        response += (
            f"{i}. {status} <b>{name}</b>\n"
            f"   🆔 ID: {thread.user_id}\n"
            f"   🕐 {time_str} | 📨 {thread.message_count}\n"
            f"   💬 Тема ID: {thread.thread_id or 'Общий'}\n\n"
        )

    await message.answer(response, parse_mode="HTML")


@dp.message(Command("close"))
async def cmd_close_thread(message: types.Message):
    """Команда /close - закрыть текущую тему"""
    logger.info(
        f"/close от {message.from_user.id} в чате {message.chat.id}, "
        f"thread={message.message_thread_id}"
    )

    if message.from_user.id not in ADMIN_IDS:
        logger.info("Отказано в /close: пользователь не админ")
        return

    if message.chat.id != SUPPORT_GROUP_ID or message.message_thread_id is None:
        await message.answer("⚠️ Команду /close нужно отправлять внутри темы.")
        return

    thread_id = message.message_thread_id

    # Ищем пользователя по thread_id
    user_id = None
    thread_info = None
    for uid, thread in user_threads.items():
        if thread.thread_id == thread_id:
            user_id = uid
            thread_info = thread
            break

    if not user_id or not thread_info:
        await message.answer("❌ Не удалось найти тему или пользователя")
        return

    if not thread_info.is_active:
        await message.answer("⚠️ Эта тема уже закрыта")
        return

    try:
        # Переименовываем тему как закрытую
        new_name = f"🔒 ЗАКРЫТО: {thread_info.user_name}"
        if len(new_name) > 128:
            new_name = new_name[:125] + "..."

        await bot.edit_forum_topic(
            chat_id=SUPPORT_GROUP_ID,
            message_thread_id=thread_id,
            name=new_name
        )

        # Помечаем как закрытую
        thread_info.is_active = False
        save_data()

        # Уведомляем пользователя
        try:
            await bot.send_message(
                chat_id=user_id,
                text=(
                    "🔒 <b>Ваша тема в поддержке закрыта</b>\n\n"
                    "Спасибо за обращение! Если появится новый вопрос — пишите, создадим новую тему!"
                ),
                parse_mode="HTML"
            )
        except Exception as e:
            logger.error(f"Не удалось уведомить пользователя: {e}")

        await message.answer(
            f"✅ <b>Тема закрыта</b>\n\n"
            f"👤 Пользователь: {thread_info.user_name}\n"
            f"🆔 ID: {user_id}\n"
            f"📅 Создана: {thread_info.created_at}",
            parse_mode="HTML"
        )

    except Exception as e:
        logger.error(f"Ошибка закрытия темы: {e}")
        await message.answer("❌ Ошибка при закрытии темы")


@dp.message(Command("info"))
async def cmd_info_thread(message: types.Message):
    """Команда /info - информация о текущей теме"""
    logger.info(
        f"/info от {message.from_user.id} в чате {message.chat.id}, "
        f"thread={message.message_thread_id}"
    )

    if message.from_user.id not in ADMIN_IDS:
        logger.info("Отказано в /info: пользователь не админ")
        return

    if message.chat.id != SUPPORT_GROUP_ID or message.message_thread_id is None:
        await message.answer("⚠️ Команду /info нужно отправлять внутри темы.")
        return

    thread_id = message.message_thread_id

    # Ищем пользователя по thread_id
    thread_info = None
    for thread in user_threads.values():
        if thread.thread_id == thread_id:
            thread_info = thread
            break

    if not thread_info:
        await message.answer("❌ Не удалось найти информацию о теме")
        return

    # Рассчитываем время с последней активности
    last_active_str = "никогда"
    if thread_info.last_active:
        try:
            last_active = datetime.strptime(thread_info.last_active, "%Y-%m-%d %H:%M:%S")
            now = datetime.now()
            diff = now - last_active

            if diff.days > 0:
                last_active_str = f"{diff.days} дней назад"
            elif diff.seconds // 3600 > 0:
                last_active_str = f"{diff.seconds // 3600} часов назад"
            elif diff.seconds // 60 > 0:
                last_active_str = f"{diff.seconds // 60} минут назад"
            else:
                last_active_str = "только что"
        except Exception:
            last_active_str = thread_info.last_active

    info_text = (
        f"👤 <b>Информация о теме</b>\n\n"
        f"📛 <b>Пользователь:</b> {thread_info.user_name}\n"
        f"🆔 <b>ID пользователя:</b> {thread_info.user_id}\n"
        f"💬 <b>ID темы:</b> {thread_info.thread_id}\n"
        f"📅 <b>Создана:</b> {thread_info.created_at}\n"
        f"📊 <b>Сообщений от пользователя:</b> {thread_info.message_count}\n"
        f"⏰ <b>Последняя активность:</b> {last_active_str}\n"
        f"🔧 <b>Статус:</b> {'🟢 Активна' if thread_info.is_active else '🔴 Закрыта'}"
    )

    await message.answer(info_text, parse_mode="HTML")


@dp.message(Command("rename"))
async def cmd_rename_thread(message: types.Message):
    """Команда /rename - переименовать текущую тему"""
    logger.info(
        f"/rename от {message.from_user.id} в чате {message.chat.id}, "
        f"thread={message.message_thread_id}"
    )

    if message.from_user.id not in ADMIN_IDS:
        logger.info("Отказано в /rename: пользователь не админ")
        return

    if message.chat.id != SUPPORT_GROUP_ID or message.message_thread_id is None:
        await message.answer("⚠️ Команду /rename нужно отправлять внутри темы.")
        return

    thread_id = message.message_thread_id

    # Извлекаем новое название
    parts = message.text.split(maxsplit=1)
    if len(parts) < 2:
        await message.answer("❌ Используйте: /rename Новое название темы")
        return

    new_name = parts[1].strip()
    if len(new_name) > 128:
        new_name = new_name[:125] + "..."

    try:
        await bot.edit_forum_topic(
            chat_id=SUPPORT_GROUP_ID,
            message_thread_id=thread_id,
            name=new_name
        )

        await message.answer(f"✅ Тема переименована в: <b>{new_name}</b>", parse_mode="HTML")

    except Exception as e:
        logger.error(f"Ошибка переименования темы: {e}")
        await message.answer("❌ Ошибка при переименовании темы")


# ========== КОМАНДА /BROADCAST С REPLY ==========

@dp.message(Command("broadcast"))
async def cmd_broadcast_start(message: types.Message, state: FSMContext):
    """Команда /broadcast - начать рассылку (требует reply)"""
    logger.info(
        f"/broadcast от {message.from_user.id} в чате {message.chat.id}, "
        f"thread={message.message_thread_id}"
    )

    if message.from_user.id not in ADMIN_IDS:
        logger.info("Отказано в /broadcast: пользователь не админ")
        return

    if message.chat.id != SUPPORT_GROUP_ID or message.message_thread_id is None:
        await message.answer("⚠️ Команду /broadcast нужно отправлять внутри темы группы поддержки.")
        return

    if not message.reply_to_message:
        await message.answer(
            "❌ <b>Для рассылки нужно ответить (reply) на сообщение!</b>\n\n"
            "1. Найдите сообщение для рассылки\n"
            "2. Ответьте (reply) на него командой /broadcast\n"
            "3. Подтвердите рассылку",
            parse_mode="HTML"
        )
        return

    # Сохраняем сообщение для рассылки
    broadcast_text = (
        message.reply_to_message.text
        or message.reply_to_message.caption
        or ""
    )
    await state.update_data(
        broadcast_text=broadcast_text,
        broadcast_message_id=message.reply_to_message.message_id
    )

    preview_text = broadcast_text or "Сообщение без текста"

    confirm_text = (
        f"📢 <b>Подтверждение рассылки</b>\n\n"
        f"<b>Текст для рассылки:</b>\n{preview_text}\n\n"
        f"<b>Получатели:</b> Все активные пользователи "
        f"({len([u for u in user_threads.values() if u.is_active])} чел.)\n\n"
        f"Отправляем рассылку? (да/нет)"
    )

    await message.answer(confirm_text, parse_mode="HTML")
    await state.set_state(AdminStates.waiting_broadcast)


@dp.message(AdminStates.waiting_broadcast)
async def cmd_broadcast_confirm(message: types.Message, state: FSMContext):
    """Подтверждение рассылки"""
    logger.info(
        f"Ответ на подтверждение рассылки от {message.from_user.id} "
        f"в чате {message.chat.id}, thread={message.message_thread_id}: {message.text!r}"
    )

    if message.from_user.id not in ADMIN_IDS:
        logger.info("Отказано в подтверждении рассылки: пользователь не админ")
        await message.answer("❌ Только администратор может подтверждать рассылку.")
        await state.clear()
        return

    if message.chat.id != SUPPORT_GROUP_ID or message.message_thread_id is None:
        await message.answer("⚠️ Подтверждать рассылку нужно в теме группы поддержки.")
        await state.clear()
        return

    if not message.text or message.text.lower() not in ['да', 'yes', 'ок', 'ok', 'подтверждаю']:
        await message.answer("❌ Рассылка отменена")
        await state.clear()
        return

    # Получаем сохраненный текст
    data = await state.get_data()
    broadcast_text = data.get('broadcast_text', '')

    if not broadcast_text:
        await message.answer("❌ Текст для рассылки не найден")
        await state.clear()
        return

    # Форматируем текст рассылки
    formatted_text = f"📢 <b>Объявление от поддержки:</b>\n\n{broadcast_text}"

    # Собираем активных пользователей
    active_users = [uid for uid, thread in user_threads.items() if thread.is_active]

    if not active_users:
        await message.answer("❌ Нет активных пользователей для рассылки")
        await state.clear()
        return

    # Отправляем рассылку
    success = 0
    failed = 0
    total = len(active_users)

    progress_msg = await message.answer(f"📤 Начинаю рассылку для {total} пользователей...")

    for i, user_id in enumerate(active_users, 1):
        try:
            await bot.send_message(
                chat_id=user_id,
                text=formatted_text,
                parse_mode="HTML"
            )
            success += 1

            # Обновляем прогресс
            if i % 5 == 0 or i == total:
                await progress_msg.edit_text(
                    f"📤 Рассылка: {i}/{total} ({success} успешно, {failed} ошибок)"
                )

            await asyncio.sleep(0.2)  # Небольшая задержка, чтобы не словить лимиты
        except Exception as e:
            failed += 1
            logger.error(f"Ошибка отправки {user_id}: {e}")

    # Финальный результат
    result_text = (
        f"✅ <b>Рассылка завершена</b>\n\n"
        f"👥 Всего получателей: {total}\n"
        f"✅ Успешно отправлено: {success}\n"
        f"❌ Не удалось: {failed}"
    )

    await message.answer(result_text, parse_mode="HTML")
    await state.clear()


# ========== ОБРАБОТКА СООБЩЕНИЙ ОТ ПОЛЬЗОВАТЕЛЕЙ ==========

@dp.message(F.chat.type == "private", ~F.from_user.id.in_(ADMIN_IDS))
async def handle_user_message(message: types.Message):
    """Обработка сообщений от обычных пользователей в личке"""
    
    if message.text and message.text.startswith('/'):
        await message.answer("Просто напишите ваш вопрос, и я помогу связать вас с поддержкой!")
        return
    
    user_id = message.from_user.id
    
    logger.info(f"Сообщение от пользователя {user_id}")
    
    # Создаем или получаем тему пользователя
    if user_id not in user_threads:
        await create_user_thread(user_id, message)
    
    thread = user_threads[user_id]
    
    # Если тема не создана
    if not thread.thread_id:
        await create_user_thread(user_id, message)
        thread = user_threads[user_id]
    
    # Отправляем сообщение в тему
    await send_to_thread(thread, message)
    
    # Обновляем данные
    thread.last_active = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    thread.message_count += 1
    save_data()
    
    # Подтверждение пользователю
    await message.answer(
        "✅ <b>Сообщение отправлено!</b>\n\n"
        "Операторы уже видят ваш вопрос и скоро ответят.\n"
        "Все ответы придут сюда, в этот чат.",
        parse_mode="HTML"
    )

async def create_user_thread(user_id: int, message: types.Message):
    """Создать тему для пользователя"""
    user_name = message.from_user.full_name or "Без имени"
    if message.from_user.username:
        user_name += f" (@{message.from_user.username})"
    
    thread_name = f"👤 {user_name}"
    if len(thread_name) > 128:
        thread_name = thread_name[:125] + "..."
    
    try:
        # Создаем тему
        forum_topic = await bot.create_forum_topic(
            chat_id=SUPPORT_GROUP_ID,
            name=thread_name
        )
        
        thread_id = forum_topic.message_thread_id
        
        # Приветственное сообщение в теме
        welcome_text = (
            f"🎫 <b>Новая тема создана</b>\n\n"
            f"👤 <b>Пользователь:</b> {user_name}\n"
            f"🆔 <b>ID:</b> {user_id}\n"
            f"📅 <b>Время:</b> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
            f"💬 <b>Все сообщения пользователя будут здесь</b>\n"
            f"📝 <b>Чтобы ответить - просто пишите в эту тему</b>\n\n"
            f"🔧 <b>Команды админа:</b> /close, /info, /rename, /stats, /users"
        )
        
        await bot.send_message(
            chat_id=SUPPORT_GROUP_ID,
            message_thread_id=thread_id,
            text=welcome_text,
            parse_mode="HTML"
        )
        
        # Сохраняем
        thread = UserThread(
            user_id=user_id,
            user_name=user_name,
            thread_id=thread_id,
            created_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            message_count=0,
            last_active=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            is_active=True
        )
        
        user_threads[user_id] = thread
        save_data()
        
        logger.info(f"Создана тема {thread_id} для {user_id}")
        
        return thread
        
    except Exception as e:
        logger.error(f"Ошибка создания темы: {e}")
        
        thread = UserThread(
            user_id=user_id,
            user_name=user_name,
            thread_id=None,
            created_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            last_active=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            is_active=True
        )
        
        user_threads[user_id] = thread
        save_data()
        
        return thread

async def send_to_thread(thread: UserThread, message: types.Message):
    """Отправить сообщение в тему пользователя"""
    try:
        if not thread.thread_id:
            return
        
        # В тему пользователя
        timestamp = datetime.now().strftime("%H:%M")
        header = f"🕐 <b>{timestamp}</b>\n\n"
        
        if message.text:
            await bot.send_message(
                chat_id=SUPPORT_GROUP_ID,
                message_thread_id=thread.thread_id,
                text=header + message.text,
                parse_mode="HTML"
            )
        elif message.photo:
            caption = header + (message.caption or "")
            await bot.send_photo(
                chat_id=SUPPORT_GROUP_ID,
                message_thread_id=thread.thread_id,
                photo=message.photo[-1].file_id,
                caption=caption[:1024],
                parse_mode="HTML"
            )
        elif message.video:
            caption = header + (message.caption or "")
            await bot.send_video(
                chat_id=SUPPORT_GROUP_ID,
                message_thread_id=thread.thread_id,
                video=message.video.file_id,
                caption=caption[:1024],
                parse_mode="HTML"
            )
        elif message.document:
            caption = header + (message.caption or "")
            await bot.send_document(
                chat_id=SUPPORT_GROUP_ID,
                message_thread_id=thread.thread_id,
                document=message.document.file_id,
                caption=caption[:1024],
                parse_mode="HTML"
            )
        else:
            await bot.forward_message(
                chat_id=SUPPORT_GROUP_ID,
                message_thread_id=thread.thread_id,
                from_chat_id=message.chat.id,
                message_id=message.message_id
            )
            
    except Exception as e:
        logger.error(f"Ошибка отправки в тему: {e}")

# ========== ОБРАБОТКА ОТВЕТОВ ОПЕРАТОРОВ ==========

@dp.message(F.chat.id == SUPPORT_GROUP_ID, F.message_thread_id)
async def handle_operator_message(message: types.Message):
    """Обработка сообщений операторов в темах (не команд)"""
    
    # Пропускаем команды
    if message.text and message.text.startswith('/'):
        return
    
    thread_id = message.message_thread_id
    
    # Ищем пользователя по thread_id
    user_id = None
    for uid, thread in user_threads.items():
        if thread.thread_id == thread_id:
            user_id = uid
            break
    
    if not user_id:
        return
    
    # Пересылаем сообщение пользователю
    await forward_to_user(user_id, message)
    
    # Обновляем активность
    if user_id in user_threads:
        user_threads[user_id].last_active = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        save_data()

async def forward_to_user(user_id: int, message: types.Message):
    """Переслать сообщение пользователю"""
    try:
        reply_header = f"📩 <b>Ответ от поддержки:</b>\n\n"
        
        if message.text:
            await bot.send_message(
                chat_id=user_id,
                text=reply_header + message.text,
                parse_mode="HTML"
            )
        elif message.photo:
            caption = reply_header + (message.caption or "")
            await bot.send_photo(
                chat_id=user_id,
                photo=message.photo[-1].file_id,
                caption=caption[:1024],
                parse_mode="HTML"
            )
        elif message.video:
            caption = reply_header + (message.caption or "")
            await bot.send_video(
                chat_id=user_id,
                video=message.video.file_id,
                caption=caption[:1024],
                parse_mode="HTML"
            )
        elif message.document:
            caption = reply_header + (message.caption or "")
            await bot.send_document(
                chat_id=user_id,
                document=message.document.file_id,
                caption=caption[:1024],
                parse_mode="HTML"
            )
        else:
            await bot.send_message(
                chat_id=user_id,
                text=reply_header + "Сообщение от поддержки:",
                parse_mode="HTML"
            )
            await bot.forward_message(
                chat_id=user_id,
                from_chat_id=message.chat.id,
                message_id=message.message_id
            )
        
        logger.info(f"Сообщение отправлено пользователю {user_id}")
        
    except Exception as e:
        logger.error(f"Ошибка отправки пользователю {user_id}: {e}")

# ========== ЗАПУСК БОТА ==========

async def main():
    logger.info("🤖 Запуск бота поддержки с админскими командами в темах...")
    
    # Важно: проверяем настройки
    logger.info(f"ADMIN_IDS: {ADMIN_IDS}")
    logger.info(f"Группа ID: {SUPPORT_GROUP_ID}")
    
    # Проверка группы
    try:
        chat = await bot.get_chat(SUPPORT_GROUP_ID)
        logger.info(f"Группа: {chat.title}")
        
        if not chat.is_forum:
            logger.error("❌ Группа должна быть с темами (Форум)!")
            return
            
        # Приветствие в группе
        await bot.send_message(
            chat_id=SUPPORT_GROUP_ID,
            text="🤖 <b>Бот поддержки запущен!</b>\n\n"
                 "📝 <b>Каждому пользователю создается отдельная тема.</b>\n\n"
                 "👑 <b>Админские команды (в любой теме):</b>\n"
                 "/stats - статистика\n"
                 "/users - список пользователей\n"
                 "/help - помощь\n\n"
                 "🔧 <b>Команды в теме пользователя:</b>\n"
                 "/close - закрыть тему\n"
                 "/info - информация\n"
                 "/rename [текст] - переименовать\n"
                 "/broadcast - рассылка (reply на сообщение)\n\n"
                 "✅ <b>Бот готов к работе!</b>",
            parse_mode="HTML"
        )
        
    except Exception as e:
        logger.error(f"Ошибка подключения к группе: {e}")
        return
    
    # Запуск бота
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Создаем .env файл
cat > .env << 'EOF'
# Конфигурация бота поддержки
BOT_TOKEN=
SUPPORT_GROUP_ID=
ADMIN_IDS=

# Дополнительные настройки
LOG_LEVEL=INFO
EOF

# Создаем requirements.txt
cat > requirements.txt << 'EOF'
aiogram>=3.0.0
python-dotenv>=1.0.0
EOF

# Создаем service файл для systemd
cat > /etc/systemd/system/support-bot.service << 'EOF'
[Unit]
Description=Telegram Support Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/support_bot
Environment="PATH=/root/support_bot/venv/bin"
ExecStart=/root/support_bot/venv/bin/python /root/support_bot/main.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=support-bot

[Install]
WantedBy=multi-user.target
EOF

# 7. Настройка прав
echo -e "${YELLOW}[7/8] Настройка прав и разрешений...${NC}"
chmod +x ~/support_bot/main.py
chmod 600 ~/support_bot/.env

# 8. Запуск бота как сервиса
echo -e "${YELLOW}[8/8] Настройка автозапуска...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable support-bot.service

echo -e "${GREEN}=== Установка завершена! ===${NC}"
echo -e "${YELLOW}Далее выполните:${NC}"
echo "1. Отредактируйте файл .env: nano ~/support_bot/.env"
echo "2. Запустите бота: sudo systemctl start support-bot"
echo "3. Проверьте статус: sudo systemctl status support-bot"
echo "4. Просмотрите логи: sudo journalctl -u support-bot -f"
