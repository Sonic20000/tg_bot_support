#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP_USER="support-bot"
APP_DIR="/opt/support-bot"
DATA_DIR="/var/lib/support-bot"
SERVICE_FILE="/etc/systemd/system/support-bot.service"

if [[ "${EUID}" -ne 0 ]]; then
  echo -e "${RED}Запустите установку от root: sudo ./install_bot.sh${NC}" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== Установка Telegram бота поддержки на VPS ===${NC}"

echo -e "${YELLOW}[1/7] Установка системных зависимостей...${NC}"
apt update
apt install -y python3 python3-pip python3-venv git curl rsync

echo -e "${YELLOW}[2/7] Создание пользователя и директорий...${NC}"
id -u "${APP_USER}" >/dev/null 2>&1 || useradd --system --home "${APP_DIR}" --shell /usr/sbin/nologin "${APP_USER}"
mkdir -p "${APP_DIR}" "${DATA_DIR}"

echo -e "${YELLOW}[3/7] Копирование файлов приложения...${NC}"
rsync -a --delete \
  --exclude '.git' \
  --exclude '.env' \
  --exclude 'venv' \
  --exclude '.venv' \
  --exclude '__pycache__' \
  "${SCRIPT_DIR}/" "${APP_DIR}/"

if [[ ! -f "${APP_DIR}/.env" ]]; then
  cp "${APP_DIR}/.env.example" "${APP_DIR}/.env"
  chmod 600 "${APP_DIR}/.env"
  echo -e "${YELLOW}Создан ${APP_DIR}/.env — заполните BOT_TOKEN, SUPPORT_GROUP_ID и ADMIN_IDS.${NC}"
fi

echo -e "${YELLOW}[4/7] Создание виртуального окружения...${NC}"
python3 -m venv "${APP_DIR}/venv"
"${APP_DIR}/venv/bin/pip" install --upgrade pip
"${APP_DIR}/venv/bin/pip" install -r "${APP_DIR}/requirements.txt"

echo -e "${YELLOW}[5/7] Настройка прав...${NC}"
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}" "${DATA_DIR}"
chmod 750 "${APP_DIR}" "${DATA_DIR}"
chmod 600 "${APP_DIR}/.env"

echo -e "${YELLOW}[6/7] Создание systemd service...${NC}"
cat > "${SERVICE_FILE}" <<EOF_SERVICE
[Unit]
Description=Telegram Support Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/.env
Environment=DATA_FILE=${DATA_DIR}/threads_data.json
ExecStart=${APP_DIR}/venv/bin/python -m bot.main
Restart=always
RestartSec=10
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=${DATA_DIR}

[Install]
WantedBy=multi-user.target
EOF_SERVICE

echo -e "${YELLOW}[7/7] Настройка автозапуска...${NC}"
systemctl daemon-reload
systemctl enable support-bot.service

echo -e "${GREEN}=== Установка завершена! ===${NC}"
echo "1. Отредактируйте файл: nano ${APP_DIR}/.env"
echo "2. Запустите бота: systemctl start support-bot"
echo "3. Проверьте статус: systemctl status support-bot"
echo "4. Просмотрите логи: journalctl -u support-bot -f"
