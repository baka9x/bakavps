#!/bin/bash

source /etc/bakavps/config/settings.conf
source /etc/bakavps/modules/utils.sh

echo "=== Quản lý Redis ==="

# Kiểm tra xem Redis đã cài chưa
if ! command -v redis-server >/dev/null 2>&1; then
    echo "Redis chưa được cài đặt. Đang tiến hành cài đặt..."
    sudo dnf install -y epel-release
    sudo dnf install -y redis
    if [ $? -eq 0 ]; then
        echo "Cài đặt Redis thành công!"
        sudo systemctl enable redis
        sudo systemctl start redis
        echo "Installed and started Redis" >> /etc/bakavps/logs/bakavps.log
    else
        echo "Cài đặt Redis thất bại!"
        echo "Failed to install Redis" >> /etc/bakavps/logs/bakavps.log
        exit 1
    fi
else
    echo "Redis đã được cài đặt."
fi

# Menu quản lý Redis
while true; do
    echo "1. Khởi động Redis"
    echo "2. Dừng Redis"
    echo "3. Kiểm tra trạng thái Redis"
    echo "4. Gỡ cài đặt Redis"
    echo "5. Cài đặt lại Redis"
    echo "6. Lấy hoặc tạo mật khẩu Redis"
    echo "0. Quay lại"
    read -p "Chọn option: " redis_choice
    case $redis_choice in
        1)
            echo "Đang khởi động Redis..."
            sudo systemctl start redis
            if [ $? -eq 0 ]; then
                echo "Khởi động Redis thành công!"
                echo "Started Redis" >> /etc/bakavps/logs/bakavps.log
            else
                echo "Khởi động Redis thất bại!"
                echo "Failed to start Redis" >> /etc/bakavps/logs/bakavps.log
            fi
            ;;
        2)
            echo "Đang dừng Redis..."
            sudo systemctl stop redis
            if [ $? -eq 0 ]; then
                echo "Dừng Redis thành công!"
                echo "Stopped Redis" >> /etc/bakavps/logs/bakavps.log
            else
                echo "Dừng Redis thất bại!"
                echo "Failed to stop Redis" >> /etc/bakavps/logs/bakavps.log
            fi
            ;;
        3)
            echo "Trạng thái Redis:"
            sudo systemctl status redis --no-pager
            ;;
        4)
            read -p "Bạn chắc chắn muốn gỡ cài đặt Redis? (y/n): " CONFIRM
            if [ "$CONFIRM" == "y" ]; then
                echo "Đang gỡ cài đặt Redis..."
                sudo systemctl stop redis
                sudo dnf remove -y redis
                if [ $? -eq 0 ]; then
                    echo "Gỡ cài đặt Redis thành công!"
                    echo "Uninstalled Redis" >> /etc/bakavps/logs/bakavps.log
                else
                    echo "Gỡ cài đặt Redis thất bại!"
                    echo "Failed to uninstall Redis" >> /etc/bakavps/logs/bakavps.log
                fi
            else
                echo "Hủy gỡ cài đặt Redis."
            fi
            ;;
        5)
            echo "Đang cài đặt lại Redis..."
            sudo systemctl stop redis
            sudo dnf remove -y redis
            sudo dnf install -y redis
            if [ $? -eq 0 ]; then
                sudo systemctl enable redis
                sudo systemctl start redis
                echo "Cài đặt lại Redis thành công!"
                echo "Reinstalled Redis" >> /etc/bakavps/logs/bakavps.log
            else
                echo "Cài đặt lại Redis thất bại!"
                echo "Failed to reinstall Redis" >> /etc/bakavps/logs/bakavps.log
            fi
            ;;
        6)
            REDIS_CONF="/etc/redis/redis.conf"
            if [ -f "$REDIS_CONF" ]; then
                # Kiểm tra xem đã có mật khẩu chưa
                CURRENT_PASSWORD=$(grep "^requirepass" "$REDIS_CONF" | awk '{print $2}' | tr -d '"')
                if [ -n "$CURRENT_PASSWORD" ]; then
                    echo "Mật khẩu Redis hiện tại: $CURRENT_PASSWORD"
                    echo "Để kết nối, dùng: redis-cli -a $CURRENT_PASSWORD"
                else
                    echo "Redis chưa có mật khẩu. Đang tạo mật khẩu ngẫu nhiên..."
                    NEW_PASSWORD=$(openssl rand -base64 16)  # Tạo mật khẩu ngẫu nhiên
                    sudo sed -i "/^# requirepass/c\requirepass \"$NEW_PASSWORD\"" "$REDIS_CONF"
                    sudo systemctl restart redis
                    if [ $? -eq 0 ]; then
                        echo "Đã tạo và áp dụng mật khẩu mới: $NEW_PASSWORD"
                        echo "Để kết nối, dùng: redis-cli -a $NEW_PASSWORD"
                        echo "Set Redis password to $NEW_PASSWORD" >> /etc/bakavps/logs/bakavps.log
                    else
                        echo "Không thể khởi động lại Redis sau khi thêm mật khẩu!"
                        echo "Failed to set Redis password" >> /etc/bakavps/logs/bakavps.log
                    fi
                fi
            else
                echo "Không tìm thấy file cấu hình Redis tại $REDIS_CONF!"
            fi
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Lựa chọn không hợp lệ!"
            ;;
    esac
done
