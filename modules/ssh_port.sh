#!/bin/bash

source /etc/bakavps/config/settings.conf
source /etc/bakavps/modules/utils.sh

echo "=== Đổi Port SSH ==="

# Tìm port SSH hiện tại từ file cấu hình
CURRENT_PORT=$(grep -i "^Port " /etc/ssh/sshd_config | awk '{print $2}' | head -n1)

# Nếu không có dòng Port, mặc định là 22
if [ -z "$CURRENT_PORT" ]; then
    CURRENT_PORT=22
fi

# Kiểm tra xem SSH có đang chạy trên cổng đó không
if ss -tuln | grep -q ":$CURRENT_PORT"; then
    echo "Port SSH hiện tại: $CURRENT_PORT"
else
    echo "⚠️ SSH có thể không hoạt động trên port $CURRENT_PORT, kiểm tra lại."
    echo "Thử dò port đang mở có dịch vụ SSH đang chạy..."
    CURRENT_PORT=$(ss -tulnp | grep sshd | grep -oE ':[0-9]+' | tr -d ':' | head -n1)
    if [ -n "$CURRENT_PORT" ]; then
        echo "Phát hiện SSH đang chạy trên port: $CURRENT_PORT"
    else
        echo "❌ Không xác định được port SSH đang chạy!"
        exit 1
    fi
fi

read -p "Nhập port SSH mới (1024-65535): " NEW_PORT

# Validate port
if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1024 ] || [ "$NEW_PORT" -gt 65535 ]; then
    echo "Port không hợp lệ! Phải là số từ 1024 đến 65535."
    exit 1
fi

if [ "$NEW_PORT" -eq "$CURRENT_PORT" ]; then
    echo "Port $NEW_PORT đã được sử dụng cho SSH hiện tại!"
    exit 1
fi

# Kiểm tra port mới đã được sử dụng chưa
if ss -tuln | grep -q ":$NEW_PORT"; then
    echo "Port $NEW_PORT đã được sử dụng bởi dịch vụ khác!"
    exit 1
fi

# Sao lưu cấu hình SSH
BACKUP_FILE="/etc/ssh/sshd_config.bak-$(date +%Y%m%d_%H%M%S)"
cp /etc/ssh/sshd_config "$BACKUP_FILE"
chmod 600 "$BACKUP_FILE"

# Cập nhật cấu hình SSH
if grep -q "^Port " /etc/ssh/sshd_config; then
    sed -i "s/^Port .*/Port $NEW_PORT/" /etc/ssh/sshd_config
else
    echo "Port $NEW_PORT" >> /etc/ssh/sshd_config
fi

chmod 644 /etc/ssh/sshd_config

# Mở port mới và đóng port cũ trên iptables
iptables -I INPUT -p tcp --dport "$NEW_PORT" -j ACCEPT
iptables -D INPUT -p tcp --dport "$CURRENT_PORT" -j ACCEPT 2>/dev/null

# Lưu iptables
if command -v service >/dev/null 2>&1; then
    service iptables save
    service iptables restart
else
    iptables-save > /etc/sysconfig/iptables
    systemctl restart iptables
fi

# Khởi động lại SSH
systemctl restart sshd
if [ $? -eq 0 ]; then
    echo "✅ Đã đổi port SSH sang $NEW_PORT thành công!"
    echo "Changed SSH port to $NEW_PORT" >> /etc/bakavps/logs/bakavps.log
    echo "📌 Lưu ý: Kết nối SSH mới bằng: ssh -p $NEW_PORT user@IP"
else
    echo "❌ Đổi port SSH thất bại! Khôi phục cấu hình cũ..."
    cp "$BACKUP_FILE" /etc/ssh/sshd_config
    systemctl restart sshd
    echo "Failed to change SSH port to $NEW_PORT" >> /etc/bakavps/logs/bakavps.log
    exit 1
fi

