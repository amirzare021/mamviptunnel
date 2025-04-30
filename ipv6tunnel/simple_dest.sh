#!/bin/bash

# اسکریپت ساده برای تنظیم قوانین NAT در سرور مقصد بدون وابستگی به لاگ‌ها

# 1. فعال کردن IPv6 forwarding
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

# 2. پاک کردن قوانین قبلی
ip6tables -t nat -F

# 3. تنظیم NAT
INTERFACE="ens3"  # نام اینترفیس را متناسب با سرور مقصد تغییر دهید

# اطمینان از پذیرش ترافیک forwarded
ip6tables -P FORWARD ACCEPT

# تنظیم NAT برای مسیریابی ترافیک
ip6tables -t nat -A POSTROUTING -o "$INTERFACE" -j MASQUERADE

# 4. نمایش وضعیت
echo ""
echo "===== وضعیت قوانین NAT ====="
ip6tables -t nat -L -v
echo ""
echo "===== وضعیت IPv6 forwarding ====="
cat /proc/sys/net/ipv6/conf/all/forwarding
echo ""