#!/bin/bash

source /opt/bakavps/config/settings.conf
source /opt/bakavps/modules/utils.sh

# Kiểm tra và tạo file INFO_FILE nếu không tồn tại
if [ ! -f "$INFO_FILE" ]; then
    touch "$INFO_FILE"
    chmod 644 "$INFO_FILE"
fi

# Kiểm tra và tạo file DB_INFO_FILE nếu không tồn tại
if [ ! -f "$DB_INFO_FILE" ]; then
    touch "$DB_INFO_FILE"
    chmod 644 "$DB_INFO_FILE"
fi

IPVPS=$(curl -4 -s ipinfo.io/ip)

# Gỡ nginx bản cũ nếu đang dùng từ DNF repo mặc định
if rpm -q nginx >/dev/null 2>&1; then
    echo "Đã phát hiện nginx bản cũ, tiến hành gỡ bỏ..."
    dnf remove -y nginx
    systemctl daemon-reload
fi

# Cài repo chính thức từ Nginx (dành cho AlmaLinux/RHEL)
cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx-stable]
name=nginx stable repo
baseurl=https://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF

# Cài đặt nginx mới nhất (1.27+)
dnf install -y nginx

# Tối ưu Nginx nếu cần
bash /opt/bakavps/optimize.sh nginx

# Bật nginx khi khởi động và khởi động ngay
systemctl enable nginx
systemctl start nginx

# Kiểm tra phiên bản đã cài
nginx -v

# Cài MariaDB nếu chưa có
if ! rpm -q mariadb-server >/dev/null 2>&1; then
    dnf install mariadb-server -y
    systemctl enable mariadb
fi
bash /opt/bakavps/optimize.sh mariadb
systemctl start mariadb
MYSQL_ROOT_PASS=$(generate_password)
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS'; FLUSH PRIVILEGES;"
echo "MySQLRootUsername: root" > $INFO_FILE
echo "MYSQLRootPassword: $MYSQL_ROOT_PASS" >> $INFO_FILE
chmod 600 $INFO_FILE

# Cài phpMyAdmin nếu chưa có
if [ ! -d "/usr/share/phpmyadmin" ]; then
    dnf install php php-fpm php-mysqlnd -y
    wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip -O /tmp/phpmyadmin.zip
    unzip /tmp/phpmyadmin.zip -d /usr/share/
    mv /usr/share/phpMyAdmin-* /usr/share/phpmyadmin
    rm /tmp/phpmyadmin.zip
    chmod -R 755 /usr/share/phpmyadmin
fi
cat > /etc/nginx/conf.d/phpmyadmin.conf <<EOF
server {
    listen $PROTECT_PORT;
    server_name $IPVPS;
    root /usr/share/phpmyadmin;
    index index.php;
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    location ~ \.php$ {
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
chmod 644 /etc/nginx/conf.d/phpmyadmin.conf
systemctl restart nginx php-fpm
echo "Địa chỉ phpMyAdmin: http://$IPVPS:$PROTECT_PORT/phpmyadmin" >> $INFO_FILE

# Cài Docker nếu chưa có
if ! rpm -q docker-ce >/dev/null 2>&1; then
    dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
    dnf install docker-ce docker-ce-cli containerd.io -y
    systemctl enable docker
    systemctl start docker
fi

# Cài Redis nếu chưa có
if ! rpm -q redis >/dev/null 2>&1; then
    dnf install redis -y
    systemctl enable redis
fi
bash /opt/bakavps/optimize.sh redis
systemctl start redis

# Cài iptables-services nếu chưa có
if ! rpm -q iptables-services >/dev/null 2>&1; then
    dnf install iptables-services -y
    systemctl enable iptables
fi

iptables -I INPUT -p tcp -m tcp --dport $PROTECT_PORT -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT
service iptables save
service iptables restart

# Echo full info
echo "========== VPS INFO =========="
if [ -f "$INFO_FILE" ]; then
    cat "$INFO_FILE"
else
    echo "INFO_FILE not found: $INFO_FILE"
fi
echo "=============================="
