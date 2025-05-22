#!/bin/bash

source /etc/bakavps/config/settings.conf
source /etc/bakavps/modules/utils.sh

MYSQL_ROOT_PASS=$(grep "MYSQLRootPassword" $INFO_FILE | head -n 1 | cut -d' ' -f2)
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


echo "=== Database Menu ==="
echo "1. Tạo database"
echo "2. Backup database"
echo "3. Khôi phục database"
echo "4. Xóa database"
echo "5. Tự động backup database"
echo "6. Tự động xóa backup cũ"
echo "7. Danh sách database"
echo "0. Quay lại"
read -p "Chọn option: " db_choice

case $db_choice in
    1)
        read -p "Nhập tên database cần tạo (để trống để tạo ngẫu nhiên): " DB_NAME
        read -p "Nhập domain sử dụng database này: " DOMAIN
        if [ -z "$DB_NAME" ]; then
            DB_NAME="db_$(openssl rand -hex 4)"  # Tạo tên ngẫu nhiên nếu để trống
        fi
        if [ -z "$DOMAIN" ]; then
            echo "Không được để trống domain"
            exit 1
        fi
        
        if grep -q "Website: $DOMAIN" $DB_INFO_FILE; then
            echo "Đã tồn tại DB website này trong DB-info.txt"
            exit 1
    	fi
        echo "Website được chọn để sau này backup: $DOMAIN"
        DB_USER=$DB_NAME  # dbuser giống dbname
        DB_PASS=$(generate_password)  # Tạo password ngẫu nhiên

        # Tạo database và user
        mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE DATABASE $DB_NAME; CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"
        if [ $? -eq 0 ]; then
            echo "Tạo database $DB_NAME thành công!"
            echo "Website: $DOMAIN" >> $DB_INFO_FILE
            echo "Database: $DB_NAME" >> $DB_INFO_FILE
            echo "Username: $DB_USER" >> $DB_INFO_FILE
            echo "Password: $DB_PASS" >> $DB_INFO_FILE
            echo "--------------------------------" >> $DB_INFO_FILE
            chmod 600 $DB_INFO_FILE
            echo "Created database $DB_NAME with user $DB_USER" >> /etc/bakavps/logs/bakavps.log
            echo "Thông tin database đã được lưu vào $DB_INFO_FILE:"
            echo "Website: $DOMAIN" >> $DB_INFO_FILE
            echo "Database: $DB_NAME"
            echo "Username: $DB_USER"
            echo "Password: $DB_PASS"
        else
            echo "Tạo database thất bại!"
            echo "Failed to create database $DB_NAME" >> /etc/bakavps/logs/bakavps.log
        fi
        ;; 
    2)
        DATABASES=$(mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW DATABASES;" | grep -v "Database\|information_schema\|mysql\|performance_schema\|sys")
        echo "Danh sách database:"
        echo "$DATABASES"
        read -p "Nhập tên database cần backup: " DB_NAME
        BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_$(date +%Y%m%d_%H%M%S).sql"
        mysqldump -uroot -p$MYSQL_ROOT_PASS $DB_NAME > $BACKUP_FILE
        chmod 600 $BACKUP_FILE
        if [ $? -eq 0 ]; then
            echo "Backup database $DB_NAME thành công: $BACKUP_FILE"
            echo "Backup $DB_NAME to $BACKUP_FILE" >> /etc/bakavps/logs/bakavps.log
        else
            echo "Backup thất bại!"
            echo "Backup $DB_NAME failed" >> /etc/bakavps/logs/bakavps.log
        fi
        ;;
    3)
        echo "Danh sách file backup:"
        ls -lh $BACKUP_DIR/*.sql 2>/dev/null || echo "Không có file backup nào!"
        read -p "Nhập đường dẫn file backup cần khôi phục: " RESTORE_FILE
        read -p "Nhập tên database để khôi phục: " DB_NAME
        if [ -f "$RESTORE_FILE" ]; then
            mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
            if [[ "$RESTORE_FILE" == *.gz ]]; then
		gunzip -c "$RESTORE_FILE" | mysql -uroot -p$MYSQL_ROOT_PASS $DB_NAME
	    else
		mysql -uroot -p$MYSQL_ROOT_PASS $DB_NAME < "$RESTORE_FILE"
	    fi
            if [ $? -eq 0 ]; then
                echo "Khôi phục database $DB_NAME từ $RESTORE_FILE thành công!"
                echo "Restore $DB_NAME from $RESTORE_FILE" >> /etc/bakavps/logs/bakavps.log
            else
                echo "Khôi phục thất bại!"
                echo "Restore $DB_NAME failed" >> /etc/bakavps/logs/bakavps.log
            fi
        else
            echo "File $RESTORE_FILE không tồn tại!"
        fi
        ;;
    4)
        DATABASES=$(mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW DATABASES;" | grep -v "Database\|information_schema\|mysql\|performance_schema\|sys")
        echo "Danh sách database:"
        echo "$DATABASES"
        read -p "Nhập tên database cần xóa: " DB_NAME
        read -p "Bạn chắc chắn muốn xóa $DB_NAME? (y/n): " CONFIRM
        if [ "$CONFIRM" == "y" ]; then
            mysql -uroot -p$MYSQL_ROOT_PASS -e "DROP DATABASE $DB_NAME;"
            if [ $? -eq 0 ]; then
                echo "Xóa database $DB_NAME thành công!"
                echo "Deleted database $DB_NAME" >> /etc/bakavps/logs/bakavps.log
            else
                echo "Xóa thất bại!"
                echo "Delete $DB_NAME failed" >> /etc/bakavps/logs/bakavps.log
            fi
        else
            echo "Hủy xóa database."
        fi
        ;;
    5)
        DATABASES=$(mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW DATABASES;" | grep -v "Database\|information_schema\|mysql\|performance_schema\|sys")
        echo "Danh sách database:"
        echo "$DATABASES"
        read -p "Nhập tên database cần tự động backup: " DB_NAME
        read -p "Nhập giờ (0-23): " HOUR
        read -p "Nhập phút (0-59): " MINUTE
        read -p "Nhập thứ (0-6 hoặc *): " DAY_OF_WEEK
        CRON_JOB="$MINUTE $HOUR * * $DAY_OF_WEEK /usr/bin/mysqldump -uroot -p$MYSQL_ROOT_PASS $DB_NAME > $BACKUP_DIR/${DB_NAME}_\$(date +\%Y\%m\%d_\%H\%M\%S).sql && chmod 600 $BACKUP_DIR/${DB_NAME}_\$(date +\%Y\%m\%d_\%H\%M\%S).sql"
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "Đã thiết lập tự động backup $DB_NAME."
        echo "Scheduled backup for $DB_NAME" >> /etc/bakavps/logs/bakavps.log
        ;;
    6)
        echo "Chọn thời gian tự động xóa backup cũ:"
        echo "1. 3 ngày"
        echo "2. 7 ngày"
        echo "3. 11 ngày"
        read -p "Chọn option: " DELETE_OPTION
        case $DELETE_OPTION in
            1) DAYS=3 ;;
            2) DAYS=7 ;;
            3) DAYS=11 ;;
            *) echo "Invalid option!" && exit 1 ;;
        esac
        CRON_JOB="0 0 * * * find $BACKUP_DIR -type f -name '*.sql' -mtime +$DAYS -exec rm {} \;"
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "Đã thiết lập tự động xóa backup cũ sau $DAYS ngày."
        echo "Scheduled deletion of backups older than $DAYS days" >> /etc/bakavps/logs/bakavps.log
        ;;
    7) DATABASES=$(mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW DATABASES;" | grep -v "Database\|information_schema\|mysql\|performance_schema\|sys")
        echo "Danh sách database:"
        echo "$DATABASES"
        ;;
    0)
        exit 0
        ;;
    *)
        echo "Invalid option!"
        ;;
esac
