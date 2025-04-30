#!/bin/bash

# اسکریپت ساده برای تنظیم مسیریابی IPv6 بدون وابستگی به لاگ‌ها

# 1. پاک کردن قوانین قبلی
ip6tables -t mangle -F
ip -6 rule del fwmark 2 table 200 2>/dev/null || true
ip -6 route flush table 200 2>/dev/null || true

# 2. تنظیم مجدد قوانین ip6tables
ip6tables -t mangle -A PREROUTING -j MARK --set-mark 2

# 3. تنظیم مسیریابی
INTERFACE="ens160"
DEST_SERVER="2a01:4f8:c013:e676::1"

# مسیر پیش‌فرض به جدول 200 اضافه می‌شود
ip -6 route add default dev "$INTERFACE" table 200
ip -6 route add "$DEST_SERVER/128" dev "$INTERFACE" table 200

# قانون مسیریابی برای ترافیک با مارک 2
ip -6 rule add fwmark 2 table 200

# 4. نمایش وضعیت
echo ""
echo "===== وضعیت قوانین ip6tables ====="
ip6tables -t mangle -L -v
echo ""
echo "===== وضعیت جدول مسیریابی 200 ====="
ip -6 route show table 200
echo ""
echo "===== وضعیت قوانین مسیریابی ====="
ip -6 rule show
echo ""