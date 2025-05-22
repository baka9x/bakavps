#!/bin/bash

source /opt/bakavps/config/settings.conf
source /opt/bakavps/modules/utils.sh

get_system_specs

# Đảm bảo thư mục log tồn tại và đặt quyền
mkdir -p $LOG_DIR
chmod 750 $LOG_DIR

case $1 in
nginx)
    # Tính toán động dựa trên CORES và RAM
    WORKER_PROCESSES=$CORES
    WORKER_CONNECTIONS=$((RAM * 1024 / 2)) # 2 connections per MB RAM, điều chỉnh nếu cần

    # Tạo file cấu hình Nginx
    cat >/etc/nginx/nginx.conf <<EOF
user nginx;
worker_processes $WORKER_PROCESSES;
error_log $LOG_DIR/nginx_error.log;
pid /run/nginx.pid;

# Load dynamic modules
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections $WORKER_CONNECTIONS;
    use epoll;
    multi_accept on;
}

http {
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    #access_log $LOG_DIR/nginx_access.log main;

    sendfile on;
    sendfile_max_chunk 512k;
    tcp_nopush on;
    tcp_nodelay on;
    types_hash_max_size 2048;

    server_tokens off;
    server_name_in_redirect off;

    server_names_hash_bucket_size 128;
    open_file_cache max=200000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors off;

    output_buffers 8 256k;
    postpone_output 1460;
    request_pool_size 32k;
    connection_pool_size 512;
    directio 4m;
    client_body_buffer_size 256k;
    client_body_timeout 50;
    client_header_buffer_size 64k;
    client_body_in_file_only off;
    large_client_header_buffers 4 256k;
    client_header_timeout 15;
    ignore_invalid_headers on;
    client_max_body_size 120m;

    keepalive_timeout 20;
    keepalive_requests 1000;
    keepalive_disable msie6;
    lingering_time 20s;
    lingering_timeout 5s;
    reset_timedout_connection on;
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
    fastcgi_read_timeout 300s;
    send_timeout 60s;

    gzip on;
    gzip_static on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 5;
    gzip_buffers 32 8k;
    gzip_min_length 1024;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Cloudflare module
    set_real_ip_from 204.93.240.0/24;
    set_real_ip_from 204.93.177.0/24;
    set_real_ip_from 199.27.128.0/21;
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    real_ip_header CF-Connecting-IP;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    include /etc/nginx/conf/ddos1.conf;

    # Load modular configuration files
    include /etc/nginx/conf.d/*.conf;
}
EOF

    touch $LOG_DIR/nginx_error.log $LOG_DIR/nginx_access.log
    chmod 644 $LOG_DIR/nginx_error.log $LOG_DIR/nginx_access.log
    chown nginx:nginx $LOG_DIR/nginx_error.log $LOG_DIR/nginx_access.log

    # Di chuyển file conf sang /etc/nginx/conf/
    mv /opt/bakavps/nginx/conf /etc/nginx/conf
    chmod 755 /etc/nginx/conf

    # Đặt quyền cho file cấu hình chính
    chmod 644 /etc/nginx/nginx.conf
    systemctl restart nginx
    ;;
mariadb)
    INNODB_BUFFER_POOL_SIZE=$((RAM * 50 / 100))M
    INNODB_LOG_FILE_SIZE=$((RAM * 8 / 100))M
    KEY_BUFFER_SIZE=$((RAM * 2 / 100))M
    QUERY_CACHE_SIZE=0
    MAX_CONNECTIONS=$((CORES * 150))
    THREAD_CACHE_SIZE=$((CORES * 10))
    cat >/etc/my.cnf.d/server.cnf <<EOF
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
log-error=$LOG_DIR/mariadb_error.log
pid-file=/run/mariadb/mariadb.pid

# InnoDB optimization
innodb_buffer_pool_size = ${INNODB_BUFFER_POOL_SIZE}
innodb_log_file_size = ${INNODB_LOG_FILE_SIZE}
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_io_capacity = 200
innodb_io_capacity_max = 400

# Connection and thread handling
max_connections = ${MAX_CONNECTIONS}
max_user_connections = 100
thread_cache_size = ${THREAD_CACHE_SIZE}
thread_handling = pool-of-threads

# Timeout
wait_timeout = 300
interactive_timeout = 300

# Query cache (deprecated, better disable)
query_cache_type = 0
query_cache_size = 0

# MyISAM (legacy)
key_buffer_size = ${KEY_BUFFER_SIZE}


# Logging & diagnostics
slow_query_log = 1
slow_query_log_file=$LOG_DIR/mariadb_slow.log
long_query_time = 1
log-queries-not-using-indexes

# Charset
collation-server = utf8_unicode_ci
character-set-server = utf8
init-connect = 'SET NAMES utf8'
EOF
    mkdir -p $LOG_DIR
    chmod 750 $LOG_DIR
    touch $LOG_DIR/mariadb_error.log $LOG_DIR/mariadb_slow.log
    chmod 644 $LOG_DIR/mariadb_error.log $LOG_DIR/mariadb_slow.log
    chown mysql:mysql $LOG_DIR/mariadb_error.log $LOG_DIR/mariadb_slow.log
    chmod 644 /etc/my.cnf.d/server.cnf
    systemctl restart mariadb
    ;;
redis)
    MAXMEMORY=$((RAM * 70 / 100))
    REDIS_PASS=$(generate_password)
    cat >/etc/redis/redis.conf <<EOF
bind 127.0.0.1
port 6379
maxmemory ${MAXMEMORY}mb
requirepass $REDIS_PASS
logfile $LOG_DIR/redis.log
EOF
    chmod 644 /etc/redis/redis.conf
    systemctl restart redis
    echo "Redis Username: redis_user" >>$INFO_FILE
    echo "Redis Password: $REDIS_PASS" >>$INFO_FILE
    ;;
esac
