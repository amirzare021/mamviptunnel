#!/bin/bash

# اسکریپت نصب سرویس تونل IPv6
# این اسکریپت همه وابستگی‌های مورد نیاز را نصب می‌کند و سرویس تونل را پیکربندی می‌کند

# بررسی اینکه آیا اسکریپت با دسترسی root اجرا شده است
if [ "$(id -u)" != "0" ]; then
   echo "خطا: این اسکریپت باید با دسترسی root اجرا شود."
   exit 1
fi

# تنظیم متغیرهای مسیر
SCRIPT_DIR=$(dirname "$(realpath "$0")")
MAIN_SCRIPT="$SCRIPT_DIR/ipv6tunnel.sh"
SERVICE_FILE="$SCRIPT_DIR/ipv6tunnel.service"
SYSTEM_SERVICE_PATH="/etc/systemd/system/ipv6tunnel.service"
CONFIG_DIR="/etc/ipv6tunnel"
CONFIG_FILE="$CONFIG_DIR/config.conf"
EXCLUDE_PORTS_FILE="$CONFIG_DIR/excluded_ports.txt"

# چاپ بنر
echo "======================================================"
echo "      نصب سرویس تونل IPv6 با استفاده از ip6tables     "
echo "======================================================"
echo ""

# نصب بسته‌های مورد نیاز
echo "[INFO] نصب بسته‌های مورد نیاز..."
apt update -qq
apt install -y iproute2 iptables iputils-ping dnsutils

# بررسی پشتیبانی از IPv6
if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] && [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" == "1" ]; then
    echo "[WARN] IPv6 غیرفعال است. در حال فعال کردن..."
    echo 0 > /proc/sys/net/ipv6/conf/all/disable_ipv6
    echo "net.ipv6.conf.all.disable_ipv6 = 0" >> /etc/sysctl.conf
    sysctl -p
fi

# فعال کردن IPv6 forwarding
echo "[INFO] فعال کردن IPv6 forwarding..."
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
sysctl -p

# ایجاد دایرکتوری پیکربندی
mkdir -p "$CONFIG_DIR"

# پیکربندی نوع سرور
echo "لطفاً نوع سرور را مشخص کنید:"
echo "1) سرور مبدا (ترافیک از این سرور به سرور مقصد هدایت می‌شود)"
echo "2) سرور مقصد (ترافیک از سرور مبدا به این سرور می‌آید)"
echo ""

read -p "گزینه را انتخاب کنید [1-2]: " server_choice

case $server_choice in
    1)
        echo "server_type=source" > "$CONFIG_FILE"
        
        # دریافت آدرس IPv6 سرور مقصد
        read -p "آدرس IPv6 سرور مقصد را وارد کنید: " destination_server
        echo "destination_server=$destination_server" >> "$CONFIG_FILE"
        
        echo "[INFO] سرور به عنوان مبدا پیکربندی شد."
        ;;
        
    2)
        echo "server_type=destination" > "$CONFIG_FILE"
        echo "[INFO] سرور به عنوان مقصد پیکربندی شد."
        ;;
        
    *)
        echo "[ERROR] گزینه نامعتبر!"
        exit 1
        ;;
esac

# ایجاد فایل خالی پورت‌های استثناء
touch "$EXCLUDE_PORTS_FILE"

# کپی اسکریپت اصلی به مسیر قابل اجرا
cp "$MAIN_SCRIPT" /usr/local/bin/ipv6tunnel
chmod +x /usr/local/bin/ipv6tunnel

# ایجاد و نصب فایل سرویس systemd
cat > "$SYSTEM_SERVICE_PATH" << EOL
[Unit]
Description=IPv6 Tunneling Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ipv6tunnel start
ExecStop=/usr/local/bin/ipv6tunnel stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# فعال کردن و شروع سرویس
systemctl daemon-reload
systemctl enable ipv6tunnel
systemctl start ipv6tunnel

echo ""
echo "نصب با موفقیت انجام شد!"
echo "شما می‌توانید با دستور 'ipv6tunnel' سرویس را مدیریت کنید."
echo "سرویس به طور خودکار در هنگام راه‌اندازی سیستم شروع می‌شود."
echo ""

exit 0