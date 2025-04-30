#!/bin/bash

# IPv6 Tunnel Management Script
# این اسکریپت برای مدیریت تونل IPv6 با استفاده از ip6tables است

# چک کردن دسترسی root
if [ "$(id -u)" -ne 0 ]; then
  echo "خطا: این اسکریپت باید با دسترسی root اجرا شود."
  exit 1
fi

# مسیر دیتابیس
CONFIG_DB="/etc/ipv6tunnel/config.db"
LOG_FILE="/var/log/ipv6tunnel/ipv6tunnel.log"

# تابع ثبت لاگ
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
  echo "[$level] $message"
}

# چک کردن وجود دیتابیس
if [ ! -f "$CONFIG_DB" ]; then
  log "ERROR" "دیتابیس پیکربندی یافت نشد. لطفاً اول اسکریپت نصب را اجرا کنید."
  exit 1
fi

# دریافت نوع سرور (مبدا یا مقصد)
get_server_type() {
  sqlite3 "$CONFIG_DB" "SELECT value FROM config WHERE key='server_type'" 2>/dev/null || echo ""
}

# دریافت آدرس سرور مقصد
get_destination_server() {
  sqlite3 "$CONFIG_DB" "SELECT value FROM config WHERE key='destination_server'" 2>/dev/null || echo ""
}

# دریافت لیست پورت‌های استثناء
get_excluded_ports() {
  sqlite3 "$CONFIG_DB" "SELECT port FROM excluded_ports ORDER BY port ASC" 2>/dev/null | tr '\n' ',' | sed 's/,$//'
}

# اضافه کردن پورت به لیست استثناء
add_excluded_port() {
  local port="$1"
  if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    log "ERROR" "شماره پورت نامعتبر: $port"
    return 1
  fi
  
  sqlite3 "$CONFIG_DB" "INSERT OR IGNORE INTO excluded_ports (port) VALUES ($port)" 2>/dev/null
  if [ $? -eq 0 ]; then
    log "INFO" "پورت $port به لیست استثناء اضافه شد"
    # اعمال قوانین برای پورت جدید
    apply_port_exception "$port"
    return 0
  else
    log "ERROR" "خطا در اضافه کردن پورت $port به دیتابیس"
    return 1
  fi
}

# حذف پورت از لیست استثناء
remove_excluded_port() {
  local port="$1"
  if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    log "ERROR" "شماره پورت نامعتبر: $port"
    return 1
  fi
  
  # چک کردن اینکه آیا پورت در لیست وجود دارد
  local exists=$(sqlite3 "$CONFIG_DB" "SELECT COUNT(*) FROM excluded_ports WHERE port=$port" 2>/dev/null)
  if [ "$exists" -eq 0 ]; then
    log "ERROR" "پورت $port در لیست استثناء وجود ندارد"
    return 1
  fi
  
  sqlite3 "$CONFIG_DB" "DELETE FROM excluded_ports WHERE port=$port" 2>/dev/null
  if [ $? -eq 0 ]; then
    log "INFO" "پورت $port از لیست استثناء حذف شد"
    # حذف قوانین برای پورت
    remove_port_exception "$port"
    return 0
  else
    log "ERROR" "خطا در حذف پورت $port از دیتابیس"
    return 1
  fi
}

# اعمال قوانین برای پورت استثناء
apply_port_exception() {
  local port="$1"
  local server_type=$(get_server_type)
  
  if [ "$server_type" = "source" ]; then
    # برای سرور مبدا، ترافیک پورت را از تونل خارج کن
    ip6tables -t mangle -C PREROUTING -p tcp --dport "$port" -j MARK --set-mark 1 2>/dev/null || 
    ip6tables -t mangle -A PREROUTING -p tcp --dport "$port" -j MARK --set-mark 1
    
    ip6tables -t mangle -C PREROUTING -p udp --dport "$port" -j MARK --set-mark 1 2>/dev/null || 
    ip6tables -t mangle -A PREROUTING -p udp --dport "$port" -j MARK --set-mark 1
    
    log "INFO" "قوانین برای استثناء کردن پورت $port اعمال شد"
  else
    # برای سرور مقصد، ترافیک پورت را از masquerade استثناء کن
    local interface=$(ip -6 route | grep default | awk '{print $5}' | head -n 1)
    
    ip6tables -t nat -C POSTROUTING -o "$interface" -p tcp --dport "$port" -j RETURN 2>/dev/null || 
    ip6tables -t nat -A POSTROUTING -o "$interface" -p tcp --dport "$port" -j RETURN
    
    ip6tables -t nat -C POSTROUTING -o "$interface" -p udp --dport "$port" -j RETURN 2>/dev/null || 
    ip6tables -t nat -A POSTROUTING -o "$interface" -p udp --dport "$port" -j RETURN
    
    log "INFO" "قوانین برای استثناء کردن پورت $port در NAT اعمال شد"
  fi
}

# حذف قوانین برای پورت استثناء
remove_port_exception() {
  local port="$1"
  local server_type=$(get_server_type)
  
  if [ "$server_type" = "source" ]; then
    # برای سرور مبدا، قوانین استثناء را حذف کن
    ip6tables -t mangle -D PREROUTING -p tcp --dport "$port" -j MARK --set-mark 1 2>/dev/null
    ip6tables -t mangle -D PREROUTING -p udp --dport "$port" -j MARK --set-mark 1 2>/dev/null
    
    log "INFO" "قوانین استثناء برای پورت $port حذف شد"
  else
    # برای سرور مقصد، قوانین استثناء را حذف کن
    local interface=$(ip -6 route | grep default | awk '{print $5}' | head -n 1)
    
    ip6tables -t nat -D POSTROUTING -o "$interface" -p tcp --dport "$port" -j RETURN 2>/dev/null
    ip6tables -t nat -D POSTROUTING -o "$interface" -p udp --dport "$port" -j RETURN 2>/dev/null
    
    log "INFO" "قوانین NAT استثناء برای پورت $port حذف شد"
  fi
}

# اعمال همه قوانین پورت‌های استثناء
apply_all_port_exceptions() {
  local ports=$(get_excluded_ports)
  
  if [ -z "$ports" ]; then
    log "INFO" "هیچ پورت استثنایی تعریف نشده است"
    return 0
  fi
  
  log "INFO" "اعمال قوانین برای پورت‌های استثناء: $ports"
  IFS=',' read -ra PORT_ARRAY <<< "$ports"
  for port in "${PORT_ARRAY[@]}"; do
    apply_port_exception "$port"
  done
}

# راه‌اندازی IPv6 forwarding
enable_ipv6_forwarding() {
  log "INFO" "فعال کردن IPv6 forwarding"
  sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null
  echo "net.ipv6.conf.all.forwarding=1" > /etc/sysctl.d/30-ipv6-forwarding.conf
  sysctl -p /etc/sysctl.d/30-ipv6-forwarding.conf > /dev/null
}

# راه‌اندازی تونل در سرور مبدا
setup_source_tunnel() {
  local destination_server=$(get_destination_server)
  
  if [ -z "$destination_server" ]; then
    log "ERROR" "آدرس سرور مقصد تنظیم نشده است"
    return 1
  fi
  
  log "INFO" "راه‌اندازی تونل در سرور مبدا به مقصد $destination_server"
  
  # برای اطمینان از پاک بودن قوانین قبلی
  ip6tables -t mangle -F
  
  # مارک کردن ترافیک برای هدایت از طریق تونل به جز پورت‌های استثناء
  # ابتدا قوانین پورت‌های استثناء را اعمال کن (مارک 1)
  apply_all_port_exceptions
  
  # بقیه ترافیک را با مارک 2 علامت‌گذاری کن
  ip6tables -t mangle -A PREROUTING -m mark --mark 1 -j ACCEPT
  ip6tables -t mangle -A PREROUTING -j MARK --set-mark 2
  
  # تنظیم مسیریابی
  # حذف قوانین قبلی اگر وجود دارند
  ip -6 rule del fwmark 2 table 200 2>/dev/null || true
  
  # ایجاد جدول مسیریابی و قانون
  ip -6 route flush table 200 2>/dev/null || true
  
  # بجای استفاده از 'via'، فقط از 'default dev ...' استفاده می‌کنیم تا مسیریابی از طریق اینترفیس انجام شود
  # آدرس سرور مقصد را در مسیریابی ذخیره می‌کنیم، اما از آن مستقیماً استفاده نمی‌کنیم
  
  # دریافت اینترفیس اصلی
  local interface=$(ip -6 route | grep default | awk '{print $5}' | head -n 1)
  if [ -z "$interface" ]; then
    log "ERROR" "اینترفیس IPv6 پیش‌فرض پیدا نشد"
    interface=$(ip -6 addr | grep -v "host lo" | grep -oP '(?<=: )[^:]+' | head -n 1)
    if [ -z "$interface" ]; then
      log "ERROR" "هیچ اینترفیس IPv6 پیدا نشد. لطفاً اتصال IPv6 را بررسی کنید."
      return 1
    fi
    log "INFO" "استفاده از اینترفیس $interface به عنوان اینترفیس پیش‌فرض"
  fi
  
  # تلاش برای مسیریابی از طریق اینترفیس پیش‌فرض
  ip -6 route add default dev "$interface" table 200
  
  # اضافه کردن مسیر مستقیم به سرور مقصد، برای اطمینان از ارتباط
  ip -6 route add "$destination_server/128" dev "$interface" table 200 2>/dev/null || true
  
  # افزودن قانون مسیریابی
  ip -6 rule add fwmark 2 table 200
  
  log "INFO" "مسیریابی از طریق اینترفیس $interface تنظیم شد"
  
  log "INFO" "تونل با موفقیت در سرور مبدا راه‌اندازی شد"
  return 0
}

# راه‌اندازی تونل در سرور مقصد
setup_destination_tunnel() {
  log "INFO" "راه‌اندازی تونل در سرور مقصد"
  
  # فعال کردن IPv6 forwarding
  enable_ipv6_forwarding
  
  # دریافت اینترفیس اصلی
  local interface=$(ip -6 route | grep default | awk '{print $5}' | head -n 1)
  
  if [ -z "$interface" ]; then
    log "ERROR" "اینترفیس IPv6 پیش‌فرض پیدا نشد"
    interface=$(ip -6 addr | grep -v "host lo" | grep -oP '(?<=: )[^:]+' | head -n 1)
    if [ -z "$interface" ]; then
      log "ERROR" "هیچ اینترفیس IPv6 پیدا نشد. لطفاً اتصال IPv6 را بررسی کنید."
      return 1
    fi
    log "INFO" "استفاده از اینترفیس $interface به عنوان اینترفیس پیش‌فرض"
  fi
  
  # پاک کردن قوانین قبلی NAT
  ip6tables -t nat -F
  
  # تنظیم NAT برای مسیریابی ترافیک
  ip6tables -t nat -A POSTROUTING -o "$interface" -j MASQUERADE
  
  # اعمال قوانین پورت‌های استثناء
  apply_all_port_exceptions
  
  # اطمینان از اجازه forwarding در کرنل
  echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
  
  # اطمینان از پذیرش بسته‌های forwarded
  ip6tables -P FORWARD ACCEPT
  
  log "INFO" "تونل با موفقیت در سرور مقصد راه‌اندازی شد"
  log "INFO" "مسیریابی از طریق اینترفیس $interface تنظیم شد"
  
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
  
  if [ "$server_type" = "source" ]; then
    echo "آدرس سرور مقصد: $destination_server"
    
    # بررسی اینکه آیا قوانین مسیریابی و ip6tables فعال هستند
    local routing_rules=$(ip -6 rule show | grep "from all fwmark 2 lookup 200" | wc -l)
    local mangle_rules=$(ip6tables -t mangle -L | grep "MARK set 0x2" | wc -l)
    local routes=$(ip -6 route show table 200 | grep -c "default")
    
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
  else
    # بررسی اینکه آیا قوانین NAT فعال هستند
    local nat_rules=$(ip6tables -t nat -L | grep MASQUERADE | wc -l)
    if [ "$nat_rules" -gt 0 ]; then
      echo "وضعیت تونل: فعال"
    else
      echo "وضعیت تونل: غیرفعال"
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