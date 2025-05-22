#!/bin/bash

source /etc/bakavps/config/settings.conf
source /etc/bakavps/modules/utils.sh

echo "=== Iptables Menu ==="
echo "1. Thêm port"
echo "2. Xóa port"
echo "3. Show list port kết nối"
echo "4. Block IP"
echo "5. Quay lại"
read -p "Chọn option: " iptables_choice

case $iptables_choice in
    1)
        read -p "Nhập port cần mở: " PORT
        read -p "Chọn giao thức (tcp/udp, mặc định tcp): " PROTOCOL
        PROTOCOL=${PROTOCOL:-tcp}
        iptables -A INPUT -p $PROTOCOL --dport $PORT -j ACCEPT
        service iptables save
	service iptables restart
        echo "Đã mở port $PORT ($PROTOCOL)"
        echo "Opened port $PORT ($PROTOCOL)" >> /etc/bakavps/logs/bakavps.log
        ;;
    2)
        echo "Danh sách port đang mở:"
        iptables -L INPUT -v -n --line-numbers | grep ACCEPT
        read -p "Nhập port cần xóa: " PORT
        read -p "Chọn giao thức (tcp/udp, mặc định tcp): " PROTOCOL
        PROTOCOL=${PROTOCOL:-tcp}
        iptables -D INPUT -p $PROTOCOL --dport $PORT -j ACCEPT
        service iptables save
	service iptables restart
        echo "Đã xóa port $PORT ($PROTOCOL)"
        echo "Deleted port $PORT ($PROTOCOL)" >> /etc/bakavps/logs/bakavps.log
        ;;
    3)
        echo "Danh sách port đang kết nối:"
        netstat -tulnp | grep LISTEN || echo "Không có kết nối nào!"
        echo "Danh sách port đang mở trong iptables:"
        iptables -L INPUT -v -n --line-numbers | grep ACCEPT || echo "Không có port nào được mở!"
        echo "Showed active ports" >> /etc/bakavps/logs/bakavps.log
        ;;
    4)
        read -p "Nhập IP cần block: " IP
        iptables -A INPUT -s $IP -j DROP
        service iptables save
	service iptables restart
        echo "Đã block IP $IP"
        echo "Blocked IP $IP" >> /etc/bakavps/logs/bakavps.log
        ;;
    5)
        exit 0
        ;;
    *)
        echo "Invalid option!"
        ;;
esac
