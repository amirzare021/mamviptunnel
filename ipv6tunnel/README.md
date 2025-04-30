# سرویس تونل IPv6 با ip6tables

این پروژه یک سرویس تونل IPv6 ساده ارائه می‌دهد که با استفاده از ip6tables، ترافیک را از یک سرور مبدا به یک سرور مقصد هدایت می‌کند.

## ویژگی‌ها

- هدایت ترافیک IPv6 از سرور مبدا به سرور مقصد
- استفاده از ip6tables برای مسیریابی
- امکان تعیین پورت‌های استثناء که از تونل عبور نمی‌کنند
- رابط خط فرمان ساده برای مدیریت
- نصب خودکار به عنوان سرویس systemd

## نصب

1. این مخزن را دانلود کنید
2. فایل‌های موجود را در یک پوشه قرار دهید
3. به پوشه منتقل شوید و دستور زیر را اجرا کنید:

```bash
sudo bash install.sh
```

4. گزینه‌های نصب را بر اساس نوع سرور (مبدا یا مقصد) انتخاب کنید

## مراحل نصب

### برای سرور مقصد
1. اسکریپت نصب را اجرا کنید
2. گزینه 2 (سرور مقصد) را انتخاب کنید

### برای سرور مبدا
1. اسکریپت نصب را اجرا کنید
2. گزینه 1 (سرور مبدا) را انتخاب کنید
3. آدرس IPv6 سرور مقصد را وارد کنید

## استفاده

برای مدیریت سرویس می‌توانید از رابط تعاملی یا دستورات مستقیم استفاده کنید:

### رابط تعاملی

```bash
sudo ipv6tunnel
```

### دستورات مستقیم

```bash
# شروع سرویس
sudo ipv6tunnel start

# توقف سرویس
sudo ipv6tunnel stop

# راه‌اندازی مجدد سرویس
sudo ipv6tunnel restart

# نمایش وضعیت
sudo ipv6tunnel status

# اضافه کردن پورت استثناء
sudo ipv6tunnel add-port 22

# حذف پورت استثناء
sudo ipv6tunnel remove-port 22
```

### کنترل سرویس با systemd

```bash
# شروع سرویس
sudo systemctl start ipv6tunnel

# توقف سرویس
sudo systemctl stop ipv6tunnel

# فعال کردن شروع خودکار در هنگام بوت
sudo systemctl enable ipv6tunnel

# غیرفعال کردن شروع خودکار
sudo systemctl disable ipv6tunnel

# وضعیت سرویس
sudo systemctl status ipv6tunnel
```

## ساختار فایل‌ها

- `install.sh`: اسکریپت نصب
- `ipv6tunnel.sh`: اسکریپت اصلی تونل و مدیریت
- `ipv6tunnel.service`: فایل سرویس systemd

## مسیرهای نصب

- `/usr/local/bin/ipv6tunnel`: اسکریپت اصلی
- `/etc/ipv6tunnel/config.db`: فایل پیکربندی
- `/var/log/ipv6tunnel/ipv6tunnel.log`: فایل لاگ
- `/etc/systemd/system/ipv6tunnel.service`: فایل سرویس