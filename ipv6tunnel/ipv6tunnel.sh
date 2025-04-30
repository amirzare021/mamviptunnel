#!/bin/bash

# سرویس تونل IPv6 با استفاده از ip6tables
# این اسکریپت ترافیک IPv6 را بین دو سرور تونل می‌کند
# با استفاده از ip6tables و قوانین مسیریابی

# تنظیم لوکال برای نمایش درست متن‌های فارسی
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# تنظیم متغیرهای مسیر
CONFIG_DIR="/etc/ipv6tunnel"
CONFIG_FILE="$CONFIG_DIR/config.conf"
EXCLUDED_PORTS_FILE="$CONFIG_DIR/excluded_ports.txt"

# تابع ثبت پیام - بدون تداخل با خروجی دستورات
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  # فقط در حالت COMMAND_MODE=0 پیام‌ها را نمایش بده
  # این متغیر را قبل از اجرای دستورات مهم تنظیم می‌کنیم
  if [ "${COMMAND_MODE:-0}" -eq 0 ]; then
    # نوشتن لاگ فقط به stderr
    printf "[$timestamp] [$level] $message\n" >&2
  fi
}

# بررسی اینکه آیا اسکریپت با دسترسی root اجرا شده است
if [ "$(id -u)" != "0" ]; then
   log "ERROR" "این اسکریپت باید با دسترسی root اجرا شود."
   exit 1
fi

# بررسی وجود فایل پیکربندی
if [ ! -f "$CONFIG_FILE" ]; then
  log "ERROR" "فایل پیکربندی یافت نشد. لطفاً ابتدا اسکریپت نصب را اجرا کنید."
  exit 1
fi

# دریافت نوع سرور از فایل پیکربندی
get_server_type() {
  grep "server_type" "$CONFIG_FILE" | cut -d '=' -f 2
}

# دریافت آدرس سرور مقصد از فایل پیکربندی
get_destination_server() {
  grep "destination_server" "$CONFIG_FILE" | cut -d '=' -f 2
}

# دریافت لیست پورت‌های استثناء
get_excluded_ports() {
  if [ -f "$EXCLUDED_PORTS_FILE" ]; then
    cat "$EXCLUDED_PORTS_FILE" | tr '\n' ',' | sed 's/,$//'
  else
    echo ""
  fi
}

# فعال کردن IPv6 forwarding
enable_ipv6_forwarding() {
  if [ "$(cat /proc/sys/net/ipv6/conf/all/forwarding)" != "1" ]; then
    log "INFO" "فعال کردن IPv6 forwarding..."
    echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
  fi
}

# پیدا کردن اینترفیس شبکه اصلی
get_main_interface() {
  # تغییر استاندارد خروجی لاگ به stderr
  exec 3>&2 # ذخیره stderr اصلی
  exec 2>/dev/null # جلوگیری از نمایش خروجی خطاها
  
  # لیست همه اینترفیس‌های فعال (به جز loopback) را دریافت کن
  local interfaces=""
  
  # روش 1: استفاده از ip -br link برای یافتن اینترفیس‌های فعال
  interfaces=$(ip -br link show up 2>/dev/null | grep -v "lo" | awk '{print $1}')
  
  # اگر این روش کار نکرد، استفاده از روش جایگزین
  if [ -z "$interfaces" ]; then
    interfaces=$(ip link show 2>/dev/null | grep -v "lo:" | grep "state UP" | cut -d: -f2 | tr -d ' ')
  fi
  
  # اگر هنوز هیچ اینترفیسی پیدا نشد، بررسی همه اینترفیس‌ها (حتی اگر UP نباشند)
  if [ -z "$interfaces" ]; then
    interfaces=$(ip link show 2>/dev/null | grep -v "lo:" | cut -d: -f2 | tr -d ' ')
  fi
  
  if [ -z "$interfaces" ]; then
    # بازگرداندن stderr اصلی
    exec 2>&3
    log "ERROR" "هیچ اینترفیس فعالی پیدا نشد."
    return 1
  fi
  
  # انتخاب اینترفیس مناسب
  local selected_interface=""
  
  # نام‌های اینترفیس رایج را بررسی کن (به ترتیب اولویت)
  for iface_name in ens160 ens3 eth0 enp0s3 eno1; do
    if echo "$interfaces" | grep -q "$iface_name"; then
      selected_interface="$iface_name"
      break
    fi
  done
  
  # اگر هیچ اینترفیس ترجیحی پیدا نشد، اولین اینترفیس را انتخاب کن
  if [ -z "$selected_interface" ]; then
    selected_interface=$(echo "$interfaces" | head -n1)
  fi
  
  # بازگرداندن stderr اصلی
  exec 2>&3
  
  if [ -z "$selected_interface" ]; then
    log "ERROR" "هیچ اینترفیس شبکه مناسبی پیدا نشد."
    return 1
  fi
  
  # بررسی نهایی اینترفیس انتخاب شده
  if ! ip link show "$selected_interface" &>/dev/null; then
    log "ERROR" "اینترفیس انتخاب شده '$selected_interface' وجود ندارد یا قابل دسترسی نیست."
    return 1
  fi
  
  log "INFO" "اینترفیس شبکه '$selected_interface' برای تونل انتخاب شد"
  echo "$selected_interface"
}

# اعمال قانون استثناء برای یک پورت مشخص
apply_port_exception() {
  local port="$1"
  local server_type=$(get_server_type)
  
  if [ "$server_type" = "source" ]; then
    # پاک کردن قوانین قبلی برای این پورت
    ip6tables -t mangle -D PREROUTING -p tcp --dport "$port" -j MARK --set-mark 1 2>/dev/null || true
    ip6tables -t mangle -D PREROUTING -p udp --dport "$port" -j MARK --set-mark 1 2>/dev/null || true
    
    # اضافه کردن قوانین جدید
    ip6tables -t mangle -A PREROUTING -p tcp --dport "$port" -j MARK --set-mark 1
    ip6tables -t mangle -A PREROUTING -p udp --dport "$port" -j MARK --set-mark 1
    
    log "INFO" "قوانین برای استثناء کردن پورت $port اعمال شد"
  else
    # پاک کردن قوانین قبلی برای این پورت
    ip6tables -t nat -D PREROUTING -p tcp --dport "$port" -j RETURN 2>/dev/null || true
    ip6tables -t nat -D PREROUTING -p udp --dport "$port" -j RETURN 2>/dev/null || true
    
    # اضافه کردن قوانین جدید
    ip6tables -t nat -A PREROUTING -p tcp --dport "$port" -j RETURN
    ip6tables -t nat -A PREROUTING -p udp --dport "$port" -j RETURN
    
    log "INFO" "قوانین برای استثناء کردن پورت $port اعمال شد"
  fi
  
  return 0
}

# اعمال تمام قوانین استثناء بر اساس فایل پورت‌ها
apply_all_port_exceptions() {
  if [ -f "$EXCLUDED_PORTS_FILE" ]; then
    local ports=$(cat "$EXCLUDED_PORTS_FILE")
    local excluded_ports=$(get_excluded_ports)
    
    if [ -n "$excluded_ports" ]; then
      log "INFO" "اعمال قوانین برای پورت‌های استثناء: $excluded_ports"
      
      for port in $ports; do
        apply_port_exception "$port"
      done
    fi
  fi
  
  return 0
}

# اضافه کردن پورت به لیست استثناء
add_excluded_port() {
  local port="$1"
  
  # بررسی معتبر بودن پورت
  if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    log "ERROR" "شماره پورت نامعتبر: $port"
    return 1
  fi
  
  # بررسی اینکه آیا پورت از قبل وجود دارد
  if [ -f "$EXCLUDED_PORTS_FILE" ] && grep -q "^$port$" "$EXCLUDED_PORTS_FILE"; then
    log "INFO" "پورت $port قبلاً در لیست استثناء وجود دارد"
    return 0
  fi
  
  # اضافه کردن پورت
  echo "$port" >> "$EXCLUDED_PORTS_FILE"
  log "INFO" "پورت $port به لیست استثناء اضافه شد"
  
  # اعمال قانون
  apply_port_exception "$port"
  
  return 0
}

# حذف پورت از لیست استثناء
remove_excluded_port() {
  local port="$1"
  local server_type=$(get_server_type)
  
  # بررسی معتبر بودن پورت
  if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    log "ERROR" "شماره پورت نامعتبر: $port"
    return 1
  fi
  
  # بررسی اینکه آیا پورت وجود دارد
  if [ ! -f "$EXCLUDED_PORTS_FILE" ] || ! grep -q "^$port$" "$EXCLUDED_PORTS_FILE"; then
    log "ERROR" "پورت $port در لیست استثناء وجود ندارد"
    return 1
  fi
  
  # حذف پورت از فایل
  sed -i "/^$port$/d" "$EXCLUDED_PORTS_FILE" 2>/dev/null || 
  (grep -v "^$port$" "$EXCLUDED_PORTS_FILE" > "$EXCLUDED_PORTS_FILE.tmp" && mv "$EXCLUDED_PORTS_FILE.tmp" "$EXCLUDED_PORTS_FILE")
  
  # حذف قوانین مربوط به پورت
  if [ "$server_type" = "source" ]; then
    ip6tables -t mangle -D PREROUTING -p tcp --dport "$port" -j MARK --set-mark 1 2>/dev/null || true
    ip6tables -t mangle -D PREROUTING -p udp --dport "$port" -j MARK --set-mark 1 2>/dev/null || true
  else
    ip6tables -t nat -D PREROUTING -p tcp --dport "$port" -j RETURN 2>/dev/null || true
    ip6tables -t nat -D PREROUTING -p udp --dport "$port" -j RETURN 2>/dev/null || true
  fi
  
  log "INFO" "پورت $port از لیست استثناء حذف شد"
  
  return 0
}

# راه‌اندازی تونل در سرور مبدا
setup_source_tunnel() {
  log "INFO" "راه‌اندازی تونل در سرور مبدا"
  
  # فعال کردن حالت اجرای دستورات - در این حالت لاگ‌ها نمایش داده نمی‌شوند
  COMMAND_MODE=1
  
  # دریافت آدرس سرور مقصد
  local destination_server=$(get_destination_server)
  
  # بازگشت به حالت عادی
  COMMAND_MODE=0
  
  if [ -z "$destination_server" ]; then
    log "ERROR" "آدرس سرور مقصد تنظیم نشده است"
    return 1
  fi
  
  log "INFO" "راه‌اندازی تونل در سرور مبدا به مقصد $destination_server"
  
  # فعال کردن IPv6 forwarding
  enable_ipv6_forwarding
  
  # پاک کردن قوانین قبلی
  ip6tables -t mangle -F
  
  # اعمال قوانین برای پورت‌های استثناء
  local excluded_ports=$(get_excluded_ports)
  if [ -n "$excluded_ports" ]; then
    log "INFO" "اعمال قوانین برای پورت‌های استثناء: $excluded_ports"
    apply_all_port_exceptions
  else
    log "INFO" "هیچ پورت استثنایی تعریف نشده است"
  fi
  
  # ترافیک استثناء با مارک 1 علامت‌گذاری شده‌اند، اکنون بقیه ترافیک را با 2 علامت‌گذاری می‌کنیم
  ip6tables -t mangle -A PREROUTING -m mark --mark 1 -j ACCEPT
  ip6tables -t mangle -A PREROUTING -j MARK --set-mark 2
  
  # دریافت اینترفیس اصلی بدون نمایش لاگ‌ها
  COMMAND_MODE=1
  local interface=""
  interface=$(get_main_interface 2>/dev/null || ip -br link show | grep -v lo | head -n1 | awk '{print $1}')
  COMMAND_MODE=0
  
  if [ -z "$interface" ]; then
    log "ERROR" "هیچ اینترفیس شبکه پیدا نشد"
    return 1
  fi
  
  log "INFO" "استفاده از اینترفیس $interface برای تونل"
  
  # اجرای دستورات IP در یک اسکریپت جداگانه
  # این روش از تداخل پیام‌های لاگ با دستورات IP جلوگیری می‌کند
  SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
  if [ -x "$SCRIPT_DIR/setup_ip_cmds.sh" ]; then
    "$SCRIPT_DIR/setup_ip_cmds.sh" "$interface" "$destination_server" "setup"
    if [ $? -ne 0 ]; then
      log "ERROR" "خطا در اجرای دستورات IP"
      return 1
    fi
  else
    log "ERROR" "اسکریپت setup_ip_cmds.sh یافت نشد یا قابل اجرا نیست"
    return 1
  fi
  
  log "INFO" "مسیریابی از طریق اینترفیس $interface تنظیم شد"
  log "INFO" "تونل با موفقیت در سرور مبدا راه‌اندازی شد"
  return 0
}

# راه‌اندازی تونل در سرور مقصد
setup_destination_tunnel() {
  log "INFO" "راه‌اندازی تونل در سرور مقصد"
  
  # فعال کردن IPv6 forwarding
  enable_ipv6_forwarding
  
  # دریافت اینترفیس اصلی بدون نمایش لاگ‌ها
  COMMAND_MODE=1
  local interface=""
  interface=$(get_main_interface 2>/dev/null || ip -br link show | grep -v lo | head -n1 | awk '{print $1}')
  COMMAND_MODE=0
  
  if [ -z "$interface" ]; then
    log "ERROR" "هیچ اینترفیس شبکه پیدا نشد"
    return 1
  fi
  
  log "INFO" "استفاده از اینترفیس $interface برای NAT"
  
  # پاک کردن قوانین قبلی NAT
  ip6tables -t nat -F
  
  # اطمینان از پذیرش ترافیک forwarded
  ip6tables -P FORWARD ACCEPT
  
  # تنظیم NAT برای مسیریابی ترافیک
  ip6tables -t nat -A POSTROUTING -o "$interface" -j MASQUERADE
  
  # اعمال قوانین پورت‌های استثناء
  apply_all_port_exceptions
  
  # اطمینان از اجازه forwarding در کرنل
  echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
  
  log "INFO" "مسیریابی از طریق اینترفیس $interface تنظیم شد"
  log "INFO" "تونل با موفقیت در سرور مقصد راه‌اندازی شد"
  
  return 0
}

# شروع سرویس
start_service() {
  local server_type=$(get_server_type)
  
  if [ -z "$server_type" ]; then
    log "ERROR" "نوع سرور مشخص نشده است. لطفاً اسکریپت نصب را اجرا کنید."
    return 1
  fi
  
  log "INFO" "شروع سرویس تونل IPv6 در سرور $server_type"
  
  # بررسی اینکه آیا IPv6 فعال است
  if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] && [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" == "1" ]; then
    log "ERROR" "IPv6 غیرفعال است. لطفاً با دستور زیر آن را فعال کنید:"
    log "ERROR" "echo 0 > /proc/sys/net/ipv6/conf/all/disable_ipv6"
    return 1
  fi
  
  case "$server_type" in
    source)
      setup_source_tunnel
      ;;
    destination)
      setup_destination_tunnel
      ;;
    *)
      log "ERROR" "نوع سرور نامعتبر: $server_type"
      return 1
      ;;
  esac
  
  log "INFO" "سرویس تونل IPv6 با موفقیت شروع شد"
  return 0
}

# توقف سرویس
stop_service() {
  local server_type=$(get_server_type)
  
  log "INFO" "توقف سرویس تونل IPv6 در سرور $server_type"
  
  case "$server_type" in
    source)
      # پاک کردن قوانین مسیریابی
      ip6tables -t mangle -F
      ip -6 rule del fwmark 2 table 200 2>/dev/null || true
      ip -6 route flush table 200 2>/dev/null || true
      ;;
    destination)
      # پاک کردن قوانین NAT
      ip6tables -t nat -F
      ;;
    *)
      log "ERROR" "نوع سرور نامعتبر: $server_type"
      return 1
      ;;
  esac
  
  log "INFO" "سرویس تونل IPv6 با موفقیت متوقف شد"
  return 0
}

# راه‌اندازی مجدد سرویس
restart_service() {
  log "INFO" "راه‌اندازی مجدد سرویس تونل IPv6"
  stop_service
  sleep 2
  start_service
  return $?
}

# نمایش وضعیت سرویس
show_status() {
  local server_type=$(get_server_type)
  local destination_server=$(get_destination_server)
  local excluded_ports=$(get_excluded_ports)
  
  echo "====================================================="
  echo "              وضعیت سرویس تونل IPv6                "
  echo "====================================================="
  echo ""
  echo "نوع سرور: $server_type"
  
  # نمایش اطلاعات اینترفیس شبکه (با محدود کردن خروجی‌های لاگ)
  COMMAND_MODE=1 # غیرفعال کردن لاگ‌ها
  local interface=$(get_main_interface 2>/dev/null || ip -br link show | grep -v lo | head -n1 | awk '{print $1}')
  COMMAND_MODE=0 # فعال کردن مجدد لاگ‌ها
  
  if [ -n "$interface" ]; then
    echo "اینترفیس شبکه: $interface (فعال)"
    
    # نمایش آدرس‌های IPv6 اینترفیس با مسیر دقیق
    echo "آدرس‌های IPv6 اینترفیس:"
    ip -6 addr show dev "$interface" 2>/dev/null | grep "inet6" | awk '{print "  - " $2}' || echo "  - آدرس IPv6 پیدا نشد"
  else
    echo "اینترفیس شبکه: نامشخص (مشکل در شناسایی اینترفیس)"
    
    # نمایش همه اینترفیس‌های موجود برای کمک به عیب‌یابی
    echo "اینترفیس‌های موجود:"
    ip -br link show 2>/dev/null | grep -v "lo" || echo "  - هیچ اینترفیسی پیدا نشد"
  fi
  
  echo ""
  
  if [ "$server_type" = "source" ]; then
    echo "آدرس سرور مقصد: $destination_server"
    
    # بررسی اینکه آیا قوانین مسیریابی و ip6tables فعال هستند
    local routing_rules=$(ip -6 rule show | grep "from all fwmark 2 lookup 200" | wc -l)
    local mangle_rules=$(ip6tables -t mangle -L 2>/dev/null | grep -c "MARK set 0x2" || echo 0)
    local routes=$(ip -6 route show table 200 2>/dev/null | grep -c "default" || echo 0)
    
    if [ "$routing_rules" -gt 0 ] && [ "$mangle_rules" -gt 0 ] && [ "$routes" -gt 0 ]; then
      echo "وضعیت تونل: فعال"
    else
      echo "وضعیت تونل: غیرفعال"
      
      # نمایش وضعیت دقیق‌تر برای عیب‌یابی
      if [ "$routing_rules" -eq 0 ]; then
        echo "  - قوانین مسیریابی تنظیم نشده‌اند"
      fi
      if [ "$mangle_rules" -eq 0 ]; then
        echo "  - قوانین ip6tables (mangle) تنظیم نشده‌اند"
      fi
      if [ "$routes" -eq 0 ]; then
        echo "  - مسیر پیش‌فرض در جدول مسیریابی 200 وجود ندارد"
      fi
    fi
    
    # بررسی قابلیت دسترسی به سرور مقصد
    ping6 -c 1 -W 3 "$destination_server" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "دسترسی به سرور مقصد: موفق"
    else
      echo "دسترسی به سرور مقصد: ناموفق"
      echo "  - لطفاً اتصال شبکه و آدرس سرور مقصد را بررسی کنید"
    fi
  else
    # بررسی اینکه آیا قوانین NAT فعال هستند
    local nat_rules=$(ip6tables -t nat -L | grep MASQUERADE | wc -l)
    local forwarding=$(cat /proc/sys/net/ipv6/conf/all/forwarding)
    
    if [ "$nat_rules" -gt 0 ] && [ "$forwarding" -eq 1 ]; then
      echo "وضعیت تونل: فعال"
    else
      echo "وضعیت تونل: غیرفعال"
      
      # نمایش وضعیت دقیق‌تر برای عیب‌یابی
      if [ "$nat_rules" -eq 0 ]; then
        echo "  - قوانین NAT تنظیم نشده‌اند"
      fi
      if [ "$forwarding" -ne 1 ]; then
        echo "  - IPv6 forwarding فعال نیست"
      fi
    fi
  fi
  
  echo ""
  echo "پورت‌های استثناء: ${excluded_ports:-'هیچ'}"
  echo ""
  
  # نمایش آمار مسیریابی
  if [ "$server_type" = "source" ]; then
    echo "جدول مسیریابی (Table 200):"
    ip -6 route show table 200
    echo ""
    echo "قوانین مسیریابی:"
    ip -6 rule show | grep "from all fwmark"
  else
    echo "قوانین NAT:"
    ip6tables -t nat -L -v
  fi
  
  echo ""
  echo "====================================================="
}

# مدیریت پورت‌های استثناء
manage_ports() {
  local excluded_ports=$(get_excluded_ports)
  
  echo "====================================================="
  echo "              مدیریت پورت‌های استثناء                "
  echo "====================================================="
  echo ""
  echo "پورت‌های فعلی: ${excluded_ports:-'هیچ'}"
  echo ""
  echo "1) اضافه کردن پورت"
  echo "2) حذف پورت"
  echo "3) بازگشت به منوی اصلی"
  echo ""
  
  read -p "گزینه را انتخاب کنید [1-3]: " port_choice
  
  case $port_choice in
    1)
      read -p "شماره پورت را وارد کنید: " port
      add_excluded_port "$port"
      ;;
    2)
      read -p "شماره پورت را وارد کنید: " port
      remove_excluded_port "$port"
      ;;
    3)
      return 0
      ;;
    *)
      echo "گزینه نامعتبر!"
      ;;
  esac
  
  # بازگشت به مدیریت پورت‌ها
  manage_ports
}

# صفحه اصلی
main_menu() {
  local server_type=$(get_server_type)
  
  if [ -z "$server_type" ]; then
    echo "خطا: نوع سرور مشخص نشده است. لطفاً ابتدا اسکریپت نصب را اجرا کنید."
    exit 1
  fi
  
  echo "====================================================="
  echo "              مدیریت سرویس تونل IPv6                "
  echo "====================================================="
  echo ""
  echo "نوع سرور: $server_type"
  echo ""
  echo "1) شروع سرویس"
  echo "2) توقف سرویس"
  echo "3) راه‌اندازی مجدد سرویس"
  echo "4) نمایش وضعیت"
  echo "5) مدیریت پورت‌های استثناء"
  echo "6) خروج"
  echo ""
  
  read -p "گزینه را انتخاب کنید [1-6]: " choice
  
  case $choice in
    1)
      start_service
      read -p "برای بازگشت به منو، کلید Enter را فشار دهید..." enter
      ;;
    2)
      stop_service
      read -p "برای بازگشت به منو، کلید Enter را فشار دهید..." enter
      ;;
    3)
      restart_service
      read -p "برای بازگشت به منو، کلید Enter را فشار دهید..." enter
      ;;
    4)
      show_status
      read -p "برای بازگشت به منو، کلید Enter را فشار دهید..." enter
      ;;
    5)
      manage_ports
      ;;
    6)
      exit 0
      ;;
    *)
      echo "گزینه نامعتبر!"
      sleep 2
      ;;
  esac
  
  # بازگشت به منوی اصلی
  main_menu
}

# کنترل اسکریپت با پارامترها
if [ $# -gt 0 ]; then
  case "$1" in
    start)
      start_service
      ;;
    stop)
      stop_service
      ;;
    restart)
      restart_service
      ;;
    status)
      show_status
      ;;
    add-port)
      if [ -z "$2" ]; then
        echo "خطا: شماره پورت را وارد کنید"
        echo "مثال: $0 add-port 22"
        exit 1
      fi
      add_excluded_port "$2"
      ;;
    remove-port)
      if [ -z "$2" ]; then
        echo "خطا: شماره پورت را وارد کنید"
        echo "مثال: $0 remove-port 22"
        exit 1
      fi
      remove_excluded_port "$2"
      ;;
    *)
      echo "استفاده: $0 {start|stop|restart|status|add-port PORT|remove-port PORT}"
      exit 1
      ;;
  esac
else
  # اجرای منو در حالت تعاملی
  main_menu
fi

exit 0