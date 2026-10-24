#!/usr/bin/env bash
set -Eeuo pipefail

# Check root permission
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Please run as root."
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "ERROR: This script requires Debian/Ubuntu with apt."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "===== 1. Update and install packages ====="
apt-get update
apt-get install -y vim cron curl locales tzdata

echo "===== 2. Set Vim as default editor ====="
if [[ -x /usr/bin/vim.basic ]]; then
    update-alternatives --set editor /usr/bin/vim.basic || true
fi

echo "===== 3. Set timezone to Shanghai ====="
if [[ -d /run/systemd/system ]] && command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-timezone Asia/Shanghai
else
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    printf 'Asia/Shanghai\n' > /etc/timezone
fi

echo "===== 4. Set UTF-8 locale ====="
update-locale LANG=C.UTF-8
export LANG=C.UTF-8 LC_ALL=C.UTF-8

echo "===== 5. Configure monthly reboot ====="

# Reboot at 04:30 on the first Saturday of each month
CRON_JOB='30 4 1-7 * * [ "$(date +\%u)" -eq 6 ] && /sbin/reboot'

OLD_CRON="$(crontab -l 2>/dev/null || true)"

{
    if [[ -n "$OLD_CRON" ]]; then
        printf '%s\n' "$OLD_CRON" |
            grep -Fvx -- "$CRON_JOB" || true
    fi
    printf '%s\n' "$CRON_JOB"
} | crontab -

echo "===== 6. Enable and restart cron ====="
if [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null 2>&1; then
    systemctl enable cron
    systemctl restart cron || systemctl start cron
else
    /etc/init.d/cron restart || /etc/init.d/cron start
fi

echo
echo "===== Timezone ====="
if command -v timedatectl >/dev/null 2>&1; then
    timedatectl || true
else
    date
fi

echo
echo "===== Locale configuration ====="
cat /etc/default/locale
echo
locale charmap

echo
echo "===== Installed software ====="
vim --version | head -n 2
curl --version | head -n 1

echo
echo "===== Root crontab ====="
crontab -l

echo
echo "===== System status ====="
uptime || true
who || true
who -b || true
last -n 5 reboot || true

echo
echo "===== VPS initialization completed ====="
echo "Reconnect SSH to apply the new login locale."
