#!/bin/bash

# نسخه شبیه‌سازی شده برای اجرا در محیط Replit

# ایجاد دایرکتوری داده
mkdir -p ./data 2>/dev/null

# مسیر فایل‌ها
CONFIG_FILE="./data/config.txt"
EXCLUDED_PORTS_FILE="./data/excluded_ports.txt"

# تابع ثبت پیام
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $message"
}

# ایجاد فایل پیکربندی اگر وجود ندارد
if [ ! -f "$CONFIG_FILE" ]; then
  echo "server_type=none" > "$CONFIG_FILE"
  echo "destination_server=" >> "$CONFIG_FILE"
fi

# دریافت نوع سرور
get_server_type() {
  grep "server_type" "$CONFIG_FILE" | cut -d '=' -f 2
}

# دریافت آدرس سرور مقصد
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
  
  return 0
}

# حذف پورت از لیست استثناء
remove_excluded_port() {
  local port="$1"
  
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
  
  # حذف پورت
  sed -i "/^$port$/d" "$EXCLUDED_PORTS_FILE" 2>/dev/null || 
  (grep -v "^$port$" "$EXCLUDED_PORTS_FILE" > "$EXCLUDED_PORTS_FILE.tmp" && mv "$EXCLUDED_PORTS_FILE.tmp" "$EXCLUDED_PORTS_FILE")
  
  log "INFO" "پورت $port از لیست استثناء حذف شد"
  
  return 0
}

# شبیه‌سازی راه‌اندازی سرویس
start_service() {
  local server_type=$(get_server_type)
  
  if [ "$server_type" == "none" ]; then
    log "ERROR" "نوع سرور مشخص نشده است. لطفاً ابتدا پیکربندی را انجام دهید."
    return 1
  fi
  
  log "INFO" "شبیه‌سازی شروع سرویس تونل IPv6 در سرور $server_type"
  
  if [ "$server_type" == "source" ]; then
    local destination_server=$(get_destination_server)
    log "INFO" "راه‌اندازی تونل از این سرور به سرور مقصد $destination_server (شبیه‌سازی شده)"
    log "INFO" "تنظیم قوانین ip6tables برای مسیریابی ترافیک (شبیه‌سازی شده)"
    
    # لیست پورت‌های استثناء
    local excluded_ports=$(get_excluded_ports)
    if [ -n "$excluded_ports" ]; then
      log "INFO" "پورت‌های استثناء: $excluded_ports (شبیه‌سازی شده)"
    fi
  else
    log "INFO" "راه‌اندازی NAT برای سرور مقصد (شبیه‌سازی شده)"
    
    # لیست پورت‌های استثناء
    local excluded_ports=$(get_excluded_ports)
    if [ -n "$excluded_ports" ]; then
      log "INFO" "پورت‌های استثناء: $excluded_ports (شبیه‌سازی شده)"
    fi
  fi
  
  log "INFO" "سرویس تونل IPv6 با موفقیت شروع شد (شبیه‌سازی شده)"
  
  return 0
}

# شبیه‌سازی توقف سرویس
stop_service() {
  local server_type=$(get_server_type)
  
  log "INFO" "شبیه‌سازی توقف سرویس تونل IPv6 در سرور $server_type"
  
  if [ "$server_type" == "source" ]; then
    log "INFO" "حذف قوانین ip6tables برای مسیریابی (شبیه‌سازی شده)"
  else
    log "INFO" "حذف قوانین NAT (شبیه‌سازی شده)"
  fi
  
  log "INFO" "سرویس تونل IPv6 با موفقیت متوقف شد (شبیه‌سازی شده)"
  
  return 0
}

# شبیه‌سازی راه‌اندازی مجدد سرویس
restart_service() {
  log "INFO" "شبیه‌سازی راه‌اندازی مجدد سرویس تونل IPv6"
  stop_service
  sleep 1
  start_service
  return $?
}

# نمایش وضعیت سرویس
show_status() {
  local server_type=$(get_server_type)
  local destination_server=$(get_destination_server)
  local excluded_ports=$(get_excluded_ports)
  
  echo "====================================================="
  echo "        وضعیت سرویس تونل IPv6 (شبیه‌سازی شده)        "
  echo "====================================================="
  echo ""
  echo "نوع سرور: $server_type"
  
  if [ "$server_type" == "source" ]; then
    echo "آدرس سرور مقصد: $destination_server"
    echo "وضعیت تونل: شبیه‌سازی شده"
  else
    echo "وضعیت NAT: شبیه‌سازی شده"
  fi
  
  echo ""
  echo "پورت‌های استثناء: ${excluded_ports:-'هیچ'}"
  echo ""
  
  echo "تذکر: این یک شبیه‌سازی است و در محیط واقعی، اطلاعات دقیق‌تری"
  echo "از وضعیت تونل و قوانین ip6tables نمایش داده می‌شود."
  echo ""
  echo "====================================================="
}

# پیکربندی سرور
configure_server() {
  echo "====================================================="
  echo "                پیکربندی سرور تونل IPv6               "
  echo "====================================================="
  echo ""
  echo "لطفاً نوع سرور را انتخاب کنید:"
  echo "1) سرور مبدا (ترافیک از این سرور به سرور مقصد هدایت می‌شود)"
  echo "2) سرور مقصد (ترافیک از سرور مبدا به این سرور می‌آید)"
  echo ""
  
  read -p "گزینه را انتخاب کنید [1-2]: " server_choice
  
  case $server_choice in
    1)
      # پیکربندی سرور مبدا
      sed -i "s/server_type=.*/server_type=source/g" "$CONFIG_FILE" 2>/dev/null ||
      (grep -v "server_type" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" &&
       echo "server_type=source" >> "$CONFIG_FILE.tmp" &&
       mv "$CONFIG_FILE.tmp" "$CONFIG_FILE")
      
      # دریافت آدرس IPv6 سرور مقصد
      read -p "آدرس IPv6 سرور مقصد را وارد کنید: " destination_server
      
      # ذخیره آدرس سرور مقصد
      sed -i "s/destination_server=.*/destination_server=$destination_server/g" "$CONFIG_FILE" 2>/dev/null ||
      (grep -v "destination_server" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" &&
       echo "destination_server=$destination_server" >> "$CONFIG_FILE.tmp" &&
       mv "$CONFIG_FILE.tmp" "$CONFIG_FILE")
      
      log "INFO" "سرور به عنوان مبدا پیکربندی شد"
      ;;
      
    2)
      # پیکربندی سرور مقصد
      sed -i "s/server_type=.*/server_type=destination/g" "$CONFIG_FILE" 2>/dev/null ||
      (grep -v "server_type" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" &&
       echo "server_type=destination" >> "$CONFIG_FILE.tmp" &&
       mv "$CONFIG_FILE.tmp" "$CONFIG_FILE")
      
      log "INFO" "سرور به عنوان مقصد پیکربندی شد"
      ;;
      
    *)
      log "ERROR" "گزینه نامعتبر!"
      return 1
      ;;
  esac
  
  return 0
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

# منوی اصلی
main_menu() {
  local server_type=$(get_server_type)
  
  if [ "$server_type" == "none" ]; then
    configure_server
    server_type=$(get_server_type)
  fi
  
  echo "====================================================="
  echo "        مدیریت سرویس تونل IPv6 (شبیه‌سازی شده)       "
  echo "====================================================="
  echo ""
  echo "نوع سرور: $server_type"
  echo ""
  echo "1) شروع سرویس"
  echo "2) توقف سرویس"
  echo "3) راه‌اندازی مجدد سرویس"
  echo "4) نمایش وضعیت"
  echo "5) مدیریت پورت‌های استثناء"
  echo "6) پیکربندی مجدد سرور"
  echo "7) خروج"
  echo ""
  
  read -p "گزینه را انتخاب کنید [1-7]: " choice
  
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
      configure_server
      ;;
    7)
      exit 0
      ;;
    *)
      echo "گزینه نامعتبر!"
      sleep 1
      ;;
  esac
  
  # بازگشت به منوی اصلی
  main_menu
}

# شروع برنامه
echo "====================================================="
echo "       سرویس تونل IPv6 با ip6tables (شبیه‌سازی)       "
echo "====================================================="
echo ""
echo "تذکر: این نسخه شبیه‌سازی شده برای محیط Replit است و"
echo "فقط عملکرد را نمایش می‌دهد. برای استفاده واقعی، کد اصلی را"
echo "در یک سرور لینوکس با دسترسی root اجرا کنید."
echo ""

# اجرای منوی اصلی
main_menu

exit 0