#!/bin/bash

# اسکریپت حذف سرویس تونل IPv6
# این اسکریپت سرویس تونل را حذف و تمام فایل‌های مربوطه را پاک می‌کند

# بررسی اینکه آیا اسکریپت با دسترسی root اجرا شده است
if [ "$(id -u)" != "0" ]; then
   echo "خطا: این اسکریپت باید با دسترسی root اجرا شود."
   exit 1
fi

# چاپ بنر
echo "======================================================"
echo "            حذف سرویس تونل IPv6 با ip6tables           "
echo "======================================================"
echo ""

# تنظیم متغیرهای مسیر
SYSTEM_SCRIPT_PATH="/usr/local/bin/ipv6tunnel"
SYSTEM_SERVICE_PATH="/etc/systemd/system/ipv6tunnel.service"
CONFIG_DIR="/etc/ipv6tunnel"

# توقف و حذف سرویس
echo "[INFO] توقف و غیرفعال‌سازی سرویس..."
systemctl stop ipv6tunnel 2>/dev/null || true
systemctl disable ipv6tunnel 2>/dev/null || true
systemctl daemon-reload

# پاک کردن قوانین مسیریابی و ip6tables
echo "[INFO] پاک کردن قوانین مسیریابی و ip6tables..."
ip6tables -t mangle -F 2>/dev/null || true
ip6tables -t nat -F 2>/dev/null || true
ip -6 rule del fwmark 2 table 200 2>/dev/null || true
ip -6 route flush table 200 2>/dev/null || true

# حذف فایل‌ها
echo "[INFO] حذف فایل‌های سرویس..."
rm -f "$SYSTEM_SCRIPT_PATH"
rm -f "$SYSTEM_SERVICE_PATH"
rm -rf "$CONFIG_DIR"

echo ""
echo "سرویس تونل IPv6 با موفقیت حذف شد."
echo ""

exit 0