#!/bin/bash

source /etc/bakavps/config/settings.conf
source /etc/bakavps/modules/utils.sh

MENU_ITEMS=(
    "1. Thêm website"
    "2. Quản lý Databases"
    "3. Tạo Swap"
    "4. Quản lý Iptables"
    "5. Quản lý Redis"
    "6. Đổi port đăng nhập SSH"
    "7. Cài đặt Go Version Manager (GVM)"
    "8. Cài đặt và quản lý Nodejs"
    "9. Cài đặt và quản lý RabbitMQ Docker"
    "10. Nâng cấp PHP theo phiên bản"
    "0. Thoát"
)

while true; do
    # Chia danh sách thành 2 cột đều nhau
    left=()
    right=()
    for i in "${!MENU_ITEMS[@]}"; do
        if (( i % 2 == 0 )); then
            left+=("${MENU_ITEMS[$i]}")
        else
            right+=("${MENU_ITEMS[$i]}")
        fi
    done

    clear
    echo "=== BakaVPS Manager v$BAKAVPS_VERSION ==="
    echo "Đã cài đặt sẵn Nginx (nginx -v), MariaDB (mariadb --version), Redis (redis-cli -v)"
    echo "Nếu chưa cài đặt cái nào vui lòng cài lại thủ công!"
    echo "====================================="
    paste <(printf "%-40s\n" "${left[@]}") <(printf "%-40s\n" "${right[@]}")
    echo

    read -p "Chọn option: " choice
    case $choice in
        1) bash /etc/bakavps/modules/add_website.sh ;;
        2) bash /etc/bakavps/modules/database.sh ;;
        3) bash /etc/bakavps/modules/swap.sh ;;
        4) bash /etc/bakavps/modules/iptables.sh ;;
        5) bash /etc/bakavps/modules/manage_redis.sh ;;
        6) bash /etc/bakavps/modules/ssh_port.sh ;;
        7) bash /etc/bakavps/modules/install_gvm.sh ;;
        8) bash /etc/bakavps/modules/install_nvm.sh ;;
        9) bash /etc/bakavps/modules/install_rabbitmq_docker.sh ;;
        10) bash /etc/bakavps/modules/upgrade_php.sh ;;
        0) echo "Bye...! Chạy lại bằng lệnh \"bakavps\" nhé." && exit 0 ;;
        *) echo "Lựa chọn không hợp lệ!" ;;
    esac

    echo
    read -p "Nhấn Enter để quay lại menu..."
done

