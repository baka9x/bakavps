#!/bin/bash

source /etc/bakavps/config/settings.conf
source /etc/bakavps/modules/utils.sh

echo "=== NÂNG CẤP PHP THEO PHIÊN BẢN (8.1 - 8.4) ==="
echo

echo "Các phiên bản PHP có sẵn:"
echo "1) PHP 8.1"
echo "2) PHP 8.2"
echo "3) PHP 8.3"
echo "4) PHP 8.4"
echo

read -p "Chọn phiên bản PHP muốn nâng cấp (1-4): " php_choice

case $php_choice in
    1) PHP_VERSION="8.1" ;;
    2) PHP_VERSION="8.2" ;;
    3) PHP_VERSION="8.3" ;;
    4) PHP_VERSION="8.4" ;;
    *) echo "Lựa chọn không hợp lệ!" && exit 1 ;;
esac

echo
read -p "Bạn có chắc muốn nâng cấp PHP lên $PHP_VERSION không? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "Hủy nâng cấp PHP."
    exit 1
fi

echo "Cài đặt EPEL và Remi repository..."
dnf install -y epel-release
dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
dnf update -y

echo "Reset module PHP hiện tại..."
dnf module reset php -y

echo "Bật module PHP $PHP_VERSION từ Remi..."
dnf module enable php:remi-$PHP_VERSION -y

echo "⬆Đang nâng cấp PHP và các gói liên quan..."
dnf update -y php\*

echo "Cài đặt lại các thư viện PHP phổ biến..."
dnf install -y php php-cli php-fpm php-mysqlnd php-pdo php-gd php-mbstring php-xml php-json php-opcache php-bcmath php-intl php-curl

echo "Khởi động lại php-fpm và nginx..."
systemctl restart php-fpm
systemctl restart nginx

echo "PHP đã được nâng cấp thành công!"
php -v
