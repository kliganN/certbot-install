#!/bin/bash

# Функция прогресс бара.
show_progress() {
    local duration="$1"
    local step="$2"
    local count=0
    while [ $count -lt $duration ]; do
        sleep $step
        count=$((count + step))
        percent=$((count * 100 / duration))
        echo -ne "[$percent%]\r"
    done
    echo ""
}

# Проверяем права суперпользователя.
if [ "$EUID" -ne 0 ]; then
  echo "-------------------------"
  echo "[ALERT] PLEASE RUN AS ROOT (sudo)"
  exit 1
fi

# Включаем обработку ошибок.
set -e

# Логи.
log_file="/var/log/certbot-script.log"
exec > >(tee -a "$log_file") 2>&1
echo "[START] SCRIPT STARTED: $(date)"

# Обновляем пакеты дистрибутива.
apt-get update

# Проверяем наличие установленных пакетов.
if ! dpkg -l | grep -q certbot; then
    apt-get install certbot -y
fi

if ! dpkg -l | grep -q python3-certbot-nginx; then
    apt-get install python3-certbot-nginx -y
fi

# Запуск самого Certbot.
echo "Installing Certbot..."
show_progress 10 1  # Пример: 10 секунд с шагом 1 секунда.
certbot run --nginx

# Создание systemd юнита.
unit_file="/etc/systemd/system/certbot-renewal.service"
if [ ! -f "$unit_file" ]; then
    echo "Creating systemd unit file..."
    cat > "$unit_file" << EOF
[Unit]
Description=Automatically update CA with certbot renewal.

[Service]
ExecStart=/usr/bin/certbot renew --force-renewal --post-hook 'systemctl reload nginx.service'
EOF

    if [ -f "$unit_file" ]; then
        echo "Systemd unit file was created successfully."
    else
        echo "Failed to create systemd unit file."
        exit 1
    fi
fi

# Создание systemd юнита таймера.
timer_file="/etc/systemd/system/certbot-renewal.timer"
if [ ! -f "$timer_file" ]; then
    echo "Creating systemd timer file..."
    cat > "$timer_file" << EOF
[Unit]
Description=Timer for certbot

[Timer]
OnBootSec=300
OnUnitActiveSec=1w

[Install]
WantedBy=multi-user.target
EOF

    if [ -f "$timer_file" ]; then
        echo "Systemd timer file was created successfully."
    else
        echo "Failed to create systemd timer file."
        exit 1
    fi
fi

# Активация таймера в автозагрузку.
systemctl enable certbot-renewal.timer

# Завершаем логирование.
echo "[FINISHED]: SCRIPT SUCCESSFULLY COMPLETED $(date)"
