#!/bin/bash

# Tạo thư mục dự án
mkdir -p /opt/bakavps/{modules,config,logs}
chmod 750 /opt/bakavps
chmod 750 /opt/bakavps/{modules,config,logs}



# Tạo file cấu hình
cat > /opt/bakavps/config/settings.conf <<EOF
LOG_DIR=/home/private_html/log
INFO_FILE=/home/VPS-info.txt
DB_INFO_FILE=/home/DB-info.txt
BACKUP_DIR=/home/private_html/backup
EOF
chmod 644 /opt/bakavps/config/settings.conf

# Cập nhật hệ thống
sudo dnf update -y

# Kiểm tra và tắt SELinux
if [ "$(getenforce)" != "Disabled" ]; then
    setenforce 0
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    echo "SELinux disabled" >> /opt/bakavps/logs/bakavps.log
fi
chmod 644 /opt/bakavps/logs/bakavps.log

# Nhập port bảo vệ phpMyAdmin và kiểm tra
while true; do
    read -p "Enter the protection port for phpMyAdmin: " PROTECT_PORT
    if [[ -z "$PROTECT_PORT" ]]; then
        echo "Port cannot be empty. Please enter a valid port."
    elif ! [[ "$PROTECT_PORT" =~ ^[0-9]+$ ]] || [ "$PROTECT_PORT" -lt 1024 ] || [ "$PROTECT_PORT" -gt 65535 ]; then
        echo "Invalid port. Please enter a port between 1024 and 65535."
    else
        echo "PROTECT_PORT=$PROTECT_PORT" >> /opt/bakavps/config/settings.conf
        break
    fi
done

# Tạo các thư mục cần thiết
mkdir -p /home/private_html/{log,backup}
chmod 750 /home/private_html/{log,backup}

# Cài đặt các gói cơ bản nếu chưa có
if ! rpm -q epel-release >/dev/null 2>&1; then
    sudo dnf install -y epel-release wget unzip nano git-all
fi

# Gọi module setup
bash /opt/bakavps/setup.sh

# Di chuyển sang /etc/bakavps
mv /opt/bakavps /etc/bakavps
chmod 750 /etc/bakavps
chmod 750 /etc/bakavps/{modules,config,logs}
chmod 644 /etc/bakavps/logs/bakavps.log

# Tạo service systemd
cat > /etc/systemd/system/bakavps.service <<EOF
[Unit]
Description=BakaVPS Management Service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/bakavps/bakavps.sh
RemainAfterExit=yes
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit

[Install]
WantedBy=multi-user.target
EOF
chmod 644 /etc/systemd/system/bakavps.service

# Cập nhật lệnh bakavps
ln -sf /etc/bakavps/bakavps.sh /usr/local/bin/bakavps
chmod +x /usr/local/bin/bakavps

# Reload systemd và enable service
systemctl daemon-reload
systemctl enable bakavps.service

echo "Installation completed! Rebooting VPS..."
systemctl reboot
