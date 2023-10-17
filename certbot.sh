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
    echo "[Unit]" > "$unit_file"
    echo "Description=Automatically update CA with certbot renewal." >> "$unit_file"
    echo "" >> "$unit_file"
    echo "[Service]" >> "$unit_file"
    echo "ExecStart=/usr/bin/certbot renew --force-renewal --post-hook 'systemctl reload nginx.service'" >> "$unit_file"
fi

# Создание systemd юнита таймера.
timer_file="/etc/systemd/system/certbot-renewal.timer"
if [ ! -f "$timer_file" ]; then
    echo "Creating systemd timer file..."
    echo "[Unit]" > "$timer_file"
    echo "Description=Timer for certbot" >> "$timer_file"
    echo "" >> "$timer_file"
    echo "[Timer]" >> "$timer_file"
    echo "OnBootSec=300" >> "$timer_file"
    echo "OnUnitActiveSec=1w" >> "$timer_file"
    echo "" >> "$timer_file"
    echo "[Install]" >> "$timer_file"
    echo "WantedBy=multi-user.target" >> "$timer_file"
fi

# Активация таймера в автозагрузку.
systemctl enable certbot-renewal.timer

# Завершаем логирование.
echo "[FINISHED]: SCRIPT SUCCESSFULLY COMPLETED $(date)"
