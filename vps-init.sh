#!/usr/bin/env bash
set -Eeuo pipefail

trap 'rc=$?; printf "ERROR: line %s, exit %s: %s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2' ERR

# 1. Check root and apt
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Please run as root."
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "ERROR: apt-get not found. This script supports Debian/Ubuntu systems."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "===== 1. Update package index ====="
apt-get update

echo "===== 2. Upgrade installed packages ====="
apt-get \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    upgrade -y

echo "===== 3. Install required software ====="
apt-get install -y \
    vim \
    cron \
    curl \
    ca-certificates \
    locales \
    tzdata

echo "===== 4. Set Vim as default editor ====="
if update-alternatives --list editor 2>/dev/null |
    grep -Fxq '/usr/bin/vim.basic'; then
    update-alternatives --set editor /usr/bin/vim.basic
else
    echo "WARNING: vim.basic is not registered as an editor alternative."
fi

echo "===== 5. Set timezone to Shanghai ====="
if [[ -d /run/systemd/system ]] &&
    command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-timezone Asia/Shanghai
else
    ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    printf 'Asia/Shanghai\n' > /etc/timezone
fi

echo "===== 6. Configure UTF-8 locale ====="
update-locale LANG=C.UTF-8
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

echo "===== 7. Configure monthly reboot ====="

# First Saturday of every month, 04:30 Shanghai time
CRON_JOB='30 4 1-7 * * [ "$(date +\%u)" -eq 6 ] && /sbin/reboot'

OLD_CRON="$(crontab -l 2>/dev/null || true)"

{
    if [[ -n "$OLD_CRON" ]]; then
        printf '%s\n' "$OLD_CRON" |
            grep -Fvx -- "$CRON_JOB" || true
    fi
    printf '%s\n' "$CRON_JOB"
} | crontab -

echo "===== 8. Enable and start cron ====="
if [[ -d /run/systemd/system ]] &&
    command -v systemctl >/dev/null 2>&1; then
    systemctl enable cron
    systemctl restart cron || systemctl start cron
elif [[ -x /etc/init.d/cron ]]; then
    /etc/init.d/cron restart || /etc/init.d/cron start
else
    echo "ERROR: Cannot find a supported cron service manager."
    exit 1
fi

echo
echo "===== Verification: timezone ====="
if command -v timedatectl >/dev/null 2>&1; then
    timedatectl || true
else
    date
fi

echo
echo "===== Verification: locale ====="
cat /etc/default/locale
locale charmap

echo
echo "===== Verification: Vim and curl ====="
vim --version | sed -n '1,2p'
curl --version | sed -n '1p'

echo
echo "===== Verification: root crontab ====="
crontab -l

echo
echo "===== Verification: cron service ====="
if command -v systemctl >/dev/null 2>&1 &&
    [[ -d /run/systemd/system ]]; then
    systemctl is-active cron
    systemctl is-enabled cron
fi

echo
echo "===== Verification: system status ====="
if command -v uptime >/dev/null 2>&1; then
    uptime
fi
if command -v who >/dev/null 2>&1; then
    who
    who -b || true
fi
if command -v last >/dev/null 2>&1; then
    last -n 5 reboot || true
fi

echo
echo "===== VPS initialization completed ====="
echo "Reconnect SSH to apply the new login locale."
