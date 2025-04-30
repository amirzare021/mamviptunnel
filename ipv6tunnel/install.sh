#!/bin/bash

# IPv6 Tunnel Installation Script
# این اسکریپت سرویس تونل IPv6 را نصب می‌کند

# چک کردن دسترسی root
if [ "$(id -u)" -ne 0 ]; then
  echo "خطا: این اسکریپت باید با دسترسی root اجرا شود."
  exit 1
fi

echo "====================================================="
echo "            نصب سرویس تونل IPv6 با ip6tables         "
echo "====================================================="
echo ""

# نصب پکیج‌های مورد نیاز
echo "در حال نصب پکیج‌های مورد نیاز..."
if command -v apt-get &>/dev/null; then
  apt-get update
  apt-get install -y iproute2 iptables sqlite3
elif command -v yum &>/dev/null; then
  yum install -y iproute iptables sqlite
elif command -v dnf &>/dev/null; then
  dnf install -y iproute iptables sqlite
else
  echo "پکیج منیجر شناسایی نشد. لطفاً پکیج‌های زیر را به صورت دستی نصب کنید:"
  echo "- iproute2/iproute"
  echo "- iptables"
  echo "- sqlite3/sqlite"
fi

# ایجاد دایرکتوری‌های مورد نیاز
mkdir -p /etc/ipv6tunnel
mkdir -p /var/log/ipv6tunnel

# کپی کردن فایل‌ها
echo "در حال نصب فایل‌ها..."
cp ipv6tunnel.sh /usr/local/bin/ipv6tunnel
cp ipv6tunnel.service /etc/systemd/system/
chmod +x /usr/local/bin/ipv6tunnel

# ایجاد دیتابیس
echo "در حال ایجاد دیتابیس..."
sqlite3 /etc/ipv6tunnel/config.db <<EOF
CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE IF NOT EXISTS excluded_ports (
    port INTEGER PRIMARY KEY
);
EOF

# فعال کردن IPv6 اگر غیرفعال است
if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] && [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" == "1" ]; then
  echo "IPv6 غیرفعال است. در حال فعال کردن..."
  echo 0 > /proc/sys/net/ipv6/conf/all/disable_ipv6
  echo "net.ipv6.conf.all.disable_ipv6=0" > /etc/sysctl.d/99-ipv6.conf
  sysctl -p /etc/sysctl.d/99-ipv6.conf
fi

# پیکربندی سرویس
echo ""
echo "لطفاً نوع سرور را انتخاب کنید:"
echo "1) سرور مبدا (ترافیک از این سرور به سرور مقصد هدایت می‌شود)"
echo "2) سرور مقصد (ترافیک از سرور مبدا به این سرور می‌آید)"
read -p "گزینه را انتخاب کنید [1-2]: " server_type

case $server_type in
  1)
    # پیکربندی سرور مبدا
    sqlite3 /etc/ipv6tunnel/config.db "INSERT OR REPLACE INTO config (key, value) VALUES ('server_type', 'source')"
    
    # دریافت آدرس IPv6 سرور مقصد
    read -p "آدرس IPv6 سرور مقصد را وارد کنید: " destination_server
    sqlite3 /etc/ipv6tunnel/config.db "INSERT OR REPLACE INTO config (key, value) VALUES ('destination_server', '$destination_server')"
    
    echo "سرور مبدا با موفقیت پیکربندی شد."
    ;;
    
  2)
    # پیکربندی سرور مقصد
    sqlite3 /etc/ipv6tunnel/config.db "INSERT OR REPLACE INTO config (key, value) VALUES ('server_type', 'destination')"
    echo "سرور مقصد با موفقیت پیکربندی شد."
    ;;
    
  *)
    echo "گزینه نامعتبر. خروج از برنامه."
    exit 1
    ;;
esac

# راه‌اندازی سرویس
echo "در حال راه‌اندازی سرویس..."
systemctl daemon-reload
systemctl enable ipv6tunnel.service
systemctl start ipv6tunnel.service

echo ""
echo "نصب با موفقیت انجام شد!"
echo "شما می‌توانید با دستور 'ipv6tunnel' سرویس را مدیریت کنید."
echo "سرویس به طور خودکار در هنگام راه‌اندازی سیستم شروع می‌شود."
echo ""

exit 0