#!/bin/bash

source /etc/bakavps/config/settings.conf
source /etc/bakavps/modules/utils.sh

echo "=== Tạo Swap ==="
if swapon --show | grep -q '^/swapfile'; then
    echo "Swap đã tồn tại."
    read -p "Bạn có muốn xoá swap cũ và tạo lại mới không? (Y/n): " confirm_swap
    case "$confirm_swap" in
        [Yy]* )
            echo "→ Tắt và xoá swap cũ..."
            swapoff /swapfile
            rm -f /swapfile
            sed -i '/\/swapfile/d' /etc/fstab
            ;;
        [Nn]* )
            echo "Đã huỷ thao tác tạo swap."
            exit 1
            ;;
        * )
            echo "Lựa chọn không hợp lệ! Thoát."
            exit 1
            ;;
    esac
fi

echo "Chọn kích thước swap:"
echo "1. 4GB"
echo "2. 6GB"
echo "3. 8GB"
read -p "Chọn option: " swap_choice

case $swap_choice in
    1) SWAP_SIZE_MB=$((4 * 1024)) ;;
    2) SWAP_SIZE_MB=$((6 * 1024)) ;;
    3) SWAP_SIZE_MB=$((8 * 1024)) ;;
    *) echo "Lựa chọn không hợp lệ!" && exit 1 ;;
esac

echo "→ Đang tạo swap ${SWAP_SIZE_MB}MB bằng dd..."
dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_SIZE_MB status=progress

chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Thêm vào fstab nếu chưa có
grep -q '/swapfile' /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab
chmod 644 /etc/fstab

if swapon --show | grep -q '^/swapfile'; then
    echo "Tạo swap ${SWAP_SIZE_MB}MB thành công!"
    echo "Created swap: ${SWAP_SIZE_MB}MB" >> /etc/bakavps/logs/bakavps.log
else
    echo "Tạo swap thất bại!"
    echo "Failed to create swap: ${SWAP_SIZE_MB}MB" >> /etc/bakavps/logs/bakavps.log
    exit 1
fi

