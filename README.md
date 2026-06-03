# Telegram Support Bot (Aiogram 3 + Forum Threads)

Бот техподдержки для Telegram-форума: каждому пользователю в личных сообщениях создаётся отдельная тема в группе поддержки, а ответы операторов из темы возвращаются пользователю в личку.

## Возможности

### Для пользователей

- Пользователь пишет боту в личные сообщения.
- Бот создаёт персональную тему в forum-enabled supergroup.
- Все сообщения пользователя попадают в его тему.
- Ответы операторов из темы отправляются пользователю в личку.
- После закрытия темы новый вопрос пользователя создаёт новую тему.

### Для администраторов и операторов

Команды выполняются внутри тем группы поддержки:

- `/help` — список команд.
- `/stats` — статистика по пользователям, активным/закрытым темам и сообщениям.
- `/users` — последние активные пользователи.
- `/info` — информация о текущей теме.
- `/rename Новое название` — переименовать тему.
- `/close` — закрыть текущую тему и уведомить пользователя.
- `/broadcast` — рассылка по reply-сообщению всем активным пользователям с подтверждением.

## Технологии

- Python 3.10+
- Aiogram 3.x
- Telegram Bot API Forum Topics
- `.env` для конфигурации
- JSON-хранилище с атомарной записью и backup-файлом
- systemd для production-запуска на VPS

## Требования Telegram

1. Бот должен быть добавлен в supergroup с включёнными темами (Forum).
2. У бота должны быть права администратора на создание, редактирование и закрытие тем.
3. `SUPPORT_GROUP_ID` — это Bot API `chat_id` supergroup/forum. Для supergroup/channel Bot API ID отрицательный и обычно начинается с `-100`, например `-1001234567890`.
4. `message_thread_id` — ID темы, который Bot API возвращает при создании forum topic.

## Быстрый старт локально

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
nano .env
python -m bot.main
```

Минимальный `.env`:

```dotenv
BOT_TOKEN=1234567890:replace_me
SUPPORT_GROUP_ID=-1001234567890
ADMIN_IDS=12345678,87654321
```

Опционально можно задать:

```dotenv
OPERATOR_IDS=12345678,87654321
DATA_FILE=threads_data.json
LOG_LEVEL=INFO
```

Если `OPERATOR_IDS` не задан, отвечать пользователям из тем могут только `ADMIN_IDS`.

## Установка на VPS через systemd

```bash
chmod +x install_bot.sh
sudo ./install_bot.sh
sudo nano /opt/support-bot/.env
sudo systemctl start support-bot
sudo systemctl status support-bot
sudo journalctl -u support-bot -f
```

Установщик:

- создаёт отдельного системного пользователя `support-bot`;
- копирует приложение в `/opt/support-bot`;
- хранит данные в `/var/lib/support-bot/threads_data.json`;
- запускает сервис без root-прав;
- включает базовые systemd hardening-настройки.

## Структура проекта

```text
bot/
  config.py              # чтение и валидация .env
  main.py                # точка входа
  models.py              # модели данных
  storage.py             # JSON-хранилище с атомарной записью
  handlers/              # user/admin/operator/broadcast handlers
  services/              # форматирование и работа с темами
requirements.txt
requirements-dev.txt
install_bot.sh
.env.example
tests/
```

## Данные

По умолчанию бот хранит состояние тем в `threads_data.json`:

- ID пользователя;
- имя и username;
- ID темы;
- дата создания;
- последняя активность;
- количество сообщений;
- статус темы;
- дата и автор закрытия.

Запись выполняется через временный файл и `os.replace`, а перед перезаписью создаётся backup `threads_data.json.bak`.

## Проверки для разработки

```bash
pip install -r requirements-dev.txt
python -m py_compile $(find bot -name '*.py')
ruff check .
pytest
bash -n install_bot.sh
```

## Как узнать ID

- `ADMIN_IDS` и `OPERATOR_IDS` — это Telegram user ID администраторов/операторов.
- `SUPPORT_GROUP_ID` можно получить из update/debug-логов бота или через служебных ботов, которые показывают chat ID. Для forum supergroup значение должно быть в Bot API формате `-100...`.

## Безопасность

- Не коммитьте `.env` и токен бота.
- Запускайте сервис под отдельным пользователем, а не под root.
- Добавляйте в `OPERATOR_IDS` только тех, кому разрешено отвечать пользователям.
- Регулярно делайте backup `threads_data.json` или перенесите хранение в SQLite/PostgreSQL при росте нагрузки.
