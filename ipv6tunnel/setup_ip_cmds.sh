#!/bin/bash

# اسکریپت کمکی برای اجرای دستورات IP بدون تداخل لاگ‌ها

# تعریف اینترفیس مورد استفاده
INTERFACE="$1"
DEST_SERVER="$2"
ACTION="$3"

# بررسی پارامترها
if [ -z "$INTERFACE" ] || [ -z "$ACTION" ]; then
  echo "استفاده: $0 <interface> <dest_server> <action>"
  echo "مثال: $0 ens160 2a01:4f8:c013:e676::1 setup"
  exit 1
fi

case "$ACTION" in
  setup)
    # برای سرور مبدا
    # تنظیم مسیریابی
    ip -6 rule del fwmark 2 table 200 2>/dev/null || true
    ip -6 route flush table 200 2>/dev/null || true
    ip -6 route add default dev "$INTERFACE" table 200 || true
    
    if [ -n "$DEST_SERVER" ]; then
      ip -6 route add "$DEST_SERVER/128" dev "$INTERFACE" table 200 || true
      # مسیر مستقیم در جدول اصلی
      ip -6 route add "$DEST_SERVER/128" dev "$INTERFACE" 2>/dev/null || true
    fi
    
    # افزودن قانون مسیریابی
    ip -6 rule add fwmark 2 table 200 || true
    ;;
    
  cleanup)
    # حذف قوانین
    ip -6 rule del fwmark 2 table 200 2>/dev/null || true
    ip -6 route flush table 200 2>/dev/null || true
    ;;
    
  *)
    echo "عمل نامعتبر: $ACTION"
    echo "عملیات معتبر: setup, cleanup"
    exit 1
    ;;
esac

exit 0