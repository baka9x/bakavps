#!/bin/bash

source /etc/bakavps/config/settings.conf
source /etc/bakavps/modules/utils.sh

echo "1. Thêm website (HTTP only)"
echo "2. Thêm website + database (với SSL)"
echo "0. Quay lại"
read -p "Chọn option: " subchoice

case $subchoice in
    0)
       exit 0
       ;;
    1)
        read -p "Nhập tên domain: " DOMAIN
        cat > /etc/nginx/conf.d/$DOMAIN.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root /home/$DOMAIN/public_html;
    index index.html index.php;
    access_log $LOG_DIR/${DOMAIN}_access.log;
    error_log $LOG_DIR/${DOMAIN}_error.log;
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
        chmod 644 /etc/nginx/conf.d/$DOMAIN.conf
        mkdir -p /home/$DOMAIN/public_html
        chmod 755 /home/$DOMAIN/public_html
        systemctl restart nginx
        echo "Website $DOMAIN added" >> /etc/bakavps/logs/bakavps.log
        echo "Website $DOMAIN đã được thêm (HTTP only)."
        ;;

    2)
        read -p "Nhập tên domain: " DOMAIN
        DB_USER="$(echo $DOMAIN | tr -d '.')_$(openssl rand -hex 2)"
        DB_PASS=$(generate_password)
        DB_NAME=$DB_USER
        MYSQL_ROOT_PASS=$(grep "MYSQLRootPassword" $INFO_FILE | cut -d' ' -f2)
        if [ -z "$MYSQL_ROOT_PASS" ]; then
    echo "Không tìm thấy mật khẩu root MySQL trong $INFO_FILE."
    read -s -p "Nhập mật khẩu root MySQL: " MYSQL_ROOT_PASS
    echo
    if ! grep -q "MySQLRootUsername: root" $INFO_FILE; then
        echo "MySQLRootUsername: root" >> $INFO_FILE
        echo "MYSQLRootPassword: $MYSQL_ROOT_PASS" >> $INFO_FILE
        chmod 600 $INFO_FILE
    fi
    mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW DATABASES;" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Mật khẩu root MySQL không đúng. Thoát..."
            exit 1
        fi
    fi
        # Tạo database
        mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE DATABASE $DB_NAME; CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"

        # Tạo thư mục paidssl và các file mẫu (người dùng cần thay bằng file thật)
        mkdir -p /etc/nginx/paidssl/$DOMAIN
        chmod 750 /etc/nginx/paidssl/$DOMAIN
        touch /etc/nginx/paidssl/$DOMAIN/$DOMAIN.crt /etc/nginx/paidssl/$DOMAIN/$DOMAIN.key
        chmod 600 /etc/nginx/paidssl/$DOMAIN/$DOMAIN.crt /etc/nginx/paidssl/$DOMAIN/$DOMAIN.key
        mkdir -p /etc/nginx/paidssl
        chmod 750 /etc/nginx/paidssl
        cat > /etc/nginx/paidssl/origin_ca_rsa_root.pem <<EOF
-----BEGIN CERTIFICATE-----
MIIEADCCAuigAwIBAgIID+rOSdTGfGcwDQYJKoZIhvcNAQELBQAwgYsxCzAJBgNV
BAYTAlVTMRkwFwYDVQQKExBDbG91ZEZsYXJlLCBJbmMuMTQwMgYDVQQLEytDbG91
ZEZsYXJlIE9yaWdpbiBTU0wgQ2VydGlmaWNhdGUgQXV0aG9yaXR5MRYwFAYDVQQH
Ew1TYW4gRnJhbmNpc2NvMRMwEQYDVQQIEwpDYWxpZm9ybmlhMB4XDTE5MDgyMzIx
MDgwMFoXDTI5MDgxNTE3MDAwMFowgYsxCzAJBgNVBAYTAlVTMRkwFwYDVQQKExBD
bG91ZEZsYXJlLCBJbmMuMTQwMgYDVQQLEytDbG91ZEZsYXJlIE9yaWdpbiBTU0wg
Q2VydGlmaWNhdGUgQXV0aG9yaXR5MRYwFAYDVQQHEw1TYW4gRnJhbmNpc2NvMRMw
EQYDVQQIEwpDYWxpZm9ybmlhMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
AQEAwEiVZ/UoQpHmFsHvk5isBxRehukP8DG9JhFev3WZtG76WoTthvLJFRKFCHXm
V6Z5/66Z4S09mgsUuFwvJzMnE6Ej6yIsYNCb9r9QORa8BdhrkNn6kdTly3mdnykb
OomnwbUfLlExVgNdlP0XoRoeMwbQ4598foiHblO2B/LKuNfJzAMfS7oZe34b+vLB
yrP/1bgCSLdc1AxQc1AC0EsQQhgcyTJNgnG4va1c7ogPlwKyhbDyZ4e59N5lbYPJ
SmXI/cAe3jXj1FBLJZkwnoDKe0v13xeF+nF32smSH0qB7aJX2tBMW4TWtFPmzs5I
lwrFSySWAdwYdgxw180yKU0dvwIDAQABo2YwZDAOBgNVHQ8BAf8EBAMCAQYwEgYD
VR0TAQH/BAgwBgEB/wIBAjAdBgNVHQ4EFgQUJOhTV118NECHqeuU27rhFnj8KaQw
HwYDVR0jBBgwFoAUJOhTV118NECHqeuU27rhFnj8KaQwDQYJKoZIhvcNAQELBQAD
ggEBAHwOf9Ur1l0Ar5vFE6PNrZWrDfQIMyEfdgSKofCdTckbqXNTiXdgbHs+TWoQ
wAB0pfJDAHJDXOTCWRyTeXOseeOi5Btj5CnEuw3P0oXqdqevM1/+uWp0CM35zgZ8
VD4aITxity0djzE6Qnx3Syzz+ZkoBgTnNum7d9A66/V636x4vTeqbZFBr9erJzgz
hhurjcoacvRNhnjtDRM0dPeiCJ50CP3wEYuvUzDHUaowOsnLCjQIkWbR7Ni6KEIk
MOz2U0OBSif3FTkhCgZWQKOOLo1P42jHC3ssUZAtVNXrCk3fw9/E15k8NPkBazZ6
0iykLhH1trywrKRMVw67F44IE8Y=
-----END CERTIFICATE-----
EOF
        chmod 644 /etc/nginx/paidssl/origin_ca_rsa_root.pem

        # Tạo file cấu hình Nginx
        cat > /etc/nginx/conf.d/$DOMAIN.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://$DOMAIN\$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name www.$DOMAIN;
    return 301 https://$DOMAIN\$request_uri;
    ssl_certificate /etc/nginx/paidssl/$DOMAIN/$DOMAIN.crt;
    ssl_certificate_key /etc/nginx/paidssl/$DOMAIN/$DOMAIN.key;
    ssl_trusted_certificate /etc/nginx/paidssl/origin_ca_rsa_root.pem;
}

server {
    listen 443 ssl;
    http2 on;
    server_name $DOMAIN;
    access_log $LOG_DIR/${DOMAIN}_access.log;
    error_log $LOG_DIR/${DOMAIN}_error.log;

    ssl_certificate /etc/nginx/paidssl/$DOMAIN/$DOMAIN.crt;
    ssl_certificate_key /etc/nginx/paidssl/$DOMAIN/$DOMAIN.key;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_prefer_server_ciphers on;
    include /etc/nginx/conf/ssl-protocol-cipher.conf;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 30s;
    ssl_trusted_certificate /etc/nginx/paidssl/origin_ca_rsa_root.pem;
    ssl_buffer_size 1400;
    ssl_session_tickets on;
    add_header Strict-Transport-Security max-age=31536000;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    root /home/$DOMAIN/frontend/public; # Nếu không phải nextjs thì sửa ở đây
    include /etc/nginx/conf/securityheaders.conf;
    
    add_header Permissions-Policy 'geolocation=*, midi=(), sync-xhr=(self "https://$DOMAIN" "https://www.$DOMAIN"), microphone=(), camera=(), magnetometer=(), gyroscope=(), payment=(), fullscreen=(self "https://$DOMAIN" "https://www.$DOMAIN")';

    # Cấu hình cho Front End Nextjs
    location / {
                proxy_pass http://103.73.67.146:3007;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection 'upgrade';
                proxy_set_header Host $host;
                proxy_cache_bypass $http_upgrade;
    }
	location /robots.txt {
                proxy_pass http://103.73.67.146:3007/robots.txt;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection 'upgrade';
                proxy_set_header Host $host;
                proxy_cache_bypass $http_upgrade;
    }
    location ^~ /_next/static {
				expires 60d;
				add_header Cache-Control "public, immutable";
                proxy_pass http://103.73.67.146:3007/_next/static;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection 'upgrade';
                proxy_set_header Host $host;
                proxy_cache_bypass $http_upgrade;
   }
   
    include /etc/nginx/conf/staticfiles.conf;
    include /etc/nginx/conf/drop.conf;

}
EOF
        # Đặt quyền cho file cấu hình
        chmod 644 /etc/nginx/conf.d/$DOMAIN.conf

        # Tạo thư mục public_html
        mkdir -p /home/$DOMAIN/public_html
        chmod 755 /home/$DOMAIN/public_html

        # Lưu thông tin database
        echo "Website: $DOMAIN" >> $DB_INFO_FILE
        echo "Database: $DB_NAME" >> $DB_INFO_FILE
        echo "Username: $DB_USER" >> $DB_INFO_FILE
        echo "Password: $DB_PASS" >> $DB_INFO_FILE
        echo "--------------------------------" >> $DB_INFO_FILE
        chmod 600 $DB_INFO_FILE

        # Khởi động lại Nginx
        systemctl restart nginx
        echo "Website $DOMAIN và database $DB_NAME đã được thêm với SSL."
        echo "Website $DOMAIN + DB added with SSL" >> /etc/bakavps/logs/bakavps.log

        echo "Lưu ý: Vui lòng thay thế các file SSL trong /etc/nginx/paidssl/$DOMAIN/ bằng file thực tế của bạn."
        ;;
esac
