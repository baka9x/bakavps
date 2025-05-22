#!/bin/bash

source /etc/bakavps/config/settings.conf
source /etc/bakavps/modules/utils.sh

echo "=== Cài đặt và quản lý RabbitMQ bằng Docker ==="

# Định nghĩa INFO_FILE
INFO_FILE="/home/RabbitMQ-info.txt"
# Kiểm tra và cài đặt Docker nếu chưa có
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker chưa được cài đặt. Đang tiến hành cài đặt Docker..."
    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io
    if [ $? -eq 0 ]; then
        sudo systemctl enable docker
        sudo systemctl start docker
        echo "Cài đặt Docker thành công!"
        echo "Installed Docker" >> /etc/bakavps/logs/bakavps.log
    else
        echo "Cài đặt Docker thất bại!"
        echo "Failed to install Docker" >> /etc/bakavps/logs/bakavps.log
        exit 1
    fi
else
    echo "Docker đã được cài đặt."
fi

# Kiểm tra xem container RabbitMQ đã tồn tại chưa
CONTAINER_NAME="rabbitmq"
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container RabbitMQ đã tồn tại."
else
    echo "Đang cài đặt RabbitMQ bằng Docker..."
    docker run -d --restart unless-stopped --name "$CONTAINER_NAME" -p 5672:5672 -p 15672:15672 rabbitmq:management
    if [ $? -eq 0 ]; then
        echo "Cài đặt RabbitMQ thành công!"
        echo "Installed RabbitMQ via Docker" >> /etc/bakavps/logs/bakavps.log
        
        # Kiểm tra trạng thái container
        sleep 5  # Chờ 5 giây để container khởi động
        if docker ps --filter "name=$CONTAINER_NAME" --format '{{.Status}}' | grep -q "Up"; then
            echo "Container RabbitMQ đang chạy."
        else
            echo "Container RabbitMQ không chạy. Đang thử khởi động lại..."
            docker stop "$CONTAINER_NAME" >/dev/null 2>&1
            docker rm "$CONTAINER_NAME" >/dev/null 2>&1
            docker run -d --restart unless-stopped --name "$CONTAINER_NAME" -p 5672:5672 -p 15672:15672 rabbitmq:management
            sleep 5
            if ! docker ps --filter "name=$CONTAINER_NAME" --format '{{.Status}}' | grep -q "Up"; then
                echo "Lỗi: Không thể khởi động container RabbitMQ. Kiểm tra log Docker:"
                docker logs "$CONTAINER_NAME"
                echo "Failed to start RabbitMQ container" >> /etc/bakavps/logs/bakavps.log
                exit 1
            fi
        fi
        
        # Tạo user mới và xóa user guest
        echo "Đang cấu hình user và password cho RabbitMQ..."
        NEW_USER="admin"
        NEW_PASSWORD=$(openssl rand -base64 12)
        docker exec "$CONTAINER_NAME" rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbit@rabbitmq.pid --timeout 10
        docker exec "$CONTAINER_NAME" rabbitmqctl add_user "$NEW_USER" "$NEW_PASSWORD"
        docker exec "$CONTAINER_NAME" rabbitmqctl set_user_tags "$NEW_USER" administrator
        docker exec "$CONTAINER_NAME" rabbitmqctl set_permissions -p "/" "$NEW_USER" ".*" ".*" ".*"
        docker exec "$CONTAINER_NAME" rabbitmqctl delete_user guest
        if [ $? -eq 0 ]; then
            echo "Đã tạo user: $NEW_USER với password: $NEW_PASSWORD"
            echo "Truy cập UI tại http://localhost:15672 với $NEW_USER/$NEW_PASSWORD"
            echo "Configured RabbitMQ user $NEW_USER with password $NEW_PASSWORD" >> /etc/bakavps/logs/bakavps.log
            
            # Lưu thông tin vào INFO_FILE
            echo "Username: $NEW_USER" | sudo tee "$INFO_FILE" >/dev/null
            echo "Password: $NEW_PASSWORD" | sudo tee -a "$INFO_FILE" >/dev/null
            sudo chmod 600 "$INFO_FILE"
            echo "Thông tin đăng nhập đã được lưu vào $INFO_FILE"
        else
            echo "Cấu hình user RabbitMQ thất bại! Kiểm tra log Docker:"
            docker logs "$CONTAINER_NAME"
            echo "Failed to configure RabbitMQ user" >> /etc/bakavps/logs/bakavps.log
        fi
    else
        echo "Cài đặt RabbitMQ thất bại!"
        echo "Failed to install RabbitMQ via Docker" >> /etc/bakavps/logs/bakavps.log
        exit 1
    fi
fi

# Menu quản lý RabbitMQ
while true; do
    echo "1. Khởi động RabbitMQ"
    echo "2. Dừng RabbitMQ"
    echo "3. Kiểm tra trạng thái RabbitMQ"
    echo "4. Gỡ container RabbitMQ"
    echo "5. Cài đặt lại RabbitMQ"
    echo "0. Quay lại"
    read -p "Chọn option: " rabbitmq_choice
    case $rabbitmq_choice in
        1)
            echo "Đang khởi động RabbitMQ..."
            docker start "$CONTAINER_NAME"
            if [ $? -eq 0 ]; then
                echo "Khởi động RabbitMQ thành công!"
                echo "Started RabbitMQ" >> /etc/bakavps/logs/bakavps.log
            else
                echo "Khởi động RabbitMQ thất bại!"
                echo "Failed to start RabbitMQ" >> /etc/bakavps/logs/bakavps.log
            fi
            ;;
        2)
            echo "Đang dừng RabbitMQ..."
            docker stop "$CONTAINER_NAME"
            if [ $? -eq 0 ]; then
                echo "Dừng RabbitMQ thành công!"
                echo "Stopped RabbitMQ" >> /etc/bakavps/logs/bakavps.log
            else
                echo "Dừng RabbitMQ thất bại!"
                echo "Failed to stop RabbitMQ" >> /etc/bakavps/logs/bakavps.log
            fi
            ;;
        3)
            echo "Trạng thái RabbitMQ:"
            docker ps -a --filter "name=$CONTAINER_NAME" --format "Name: {{.Names}}\nStatus: {{.Status}}\nPorts: {{.Ports}}"
            ;;
        4)
            read -p "Bạn chắc chắn muốn gỡ container RabbitMQ? (y/n): " CONFIRM
            if [ "$CONFIRM" == "y" ]; then
                echo "Đang gỡ container RabbitMQ..."
                docker stop "$CONTAINER_NAME" >/dev/null 2>&1
                docker rm "$CONTAINER_NAME"
                if [ $? -eq 0 ]; then
                    echo "Gỡ container RabbitMQ thành công!"
                    echo "Uninstalled RabbitMQ container" >> /etc/bakavps/logs/bakavps.log
                    sudo rm -f "$INFO_FILE"
                    echo "Đã xóa thông tin đăng nhập tại $INFO_FILE"
                else
                    echo "Gỡ container RabbitMQ thất bại!"
                    echo "Failed to uninstall RabbitMQ container" >> /etc/bakavps/logs/bakavps.log
                fi
            else
                echo "Hủy gỡ container RabbitMQ."
            fi
            ;;
        5)
            echo "Đang cài đặt lại RabbitMQ..."
            docker stop "$CONTAINER_NAME" >/dev/null 2>&1
            docker rm "$CONTAINER_NAME" >/dev/null 2>&1
            docker run -d --restart unless-stopped --name "$CONTAINER_NAME" -p 5672:5672 -p 15672:15672 rabbitmq:management
            if [ $? -eq 0 ]; then
                echo "Cài đặt lại RabbitMQ thành công!"
                echo "Reinstalled RabbitMQ via Docker" >> /etc/bakavps/logs/bakavps.log
                
                # Kiểm tra trạng thái container
                sleep 5
                if docker ps --filter "name=$CONTAINER_NAME" --format '{{.Status}}' | grep -q "Up"; then
                    echo "Container RabbitMQ đang chạy."
                else
                    echo "Container RabbitMQ không chạy. Đang thử khởi động lại..."
                    docker stop "$CONTAINER_NAME" >/dev/null 2>&1
                    docker rm "$CONTAINER_NAME" >/dev/null 2>&1
                    docker run -d --restart unless-stopped --name "$CONTAINER_NAME" -p 5672:5672 -p 15672:15672 rabbitmq:management
                    sleep 5
                    if ! docker ps --filter "name=$CONTAINER_NAME" --format '{{.Status}}' | grep -q "Up"; then
                        echo "Lỗi: Không thể khởi động container RabbitMQ. Kiểm tra log Docker:"
                        docker logs "$CONTAINER_NAME"
                        echo "Failed to start RabbitMQ container" >> /etc/bakavps/logs/bakavps.log
                        exit 1
                    fi
                fi
                
                # Tạo lại user và password
                echo "Đang cấu hình lại user và password cho RabbitMQ..."
                NEW_USER="admin"
                NEW_PASSWORD=$(openssl rand -base64 12)
                docker exec "$CONTAINER_NAME" rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbit@rabbitmq.pid --timeout 30
                docker exec "$CONTAINER_NAME" rabbitmqctl add_user "$NEW_USER" "$NEW_PASSWORD"
                docker exec "$CONTAINER_NAME" rabbitmqctl set_user_tags "$NEW_USER" administrator
                docker exec "$CONTAINER_NAME" rabbitmqctl set_permissions -p "/" "$NEW_USER" ".*" ".*" ".*"
                docker exec "$CONTAINER_NAME" rabbitmqctl delete_user guest
                if [ $? -eq 0 ]; then
                    echo "Đã tạo user: $NEW_USER với password: $NEW_PASSWORD"
                    echo "Truy cập UI tại http://localhost:15672 với $NEW_USER/$NEW_PASSWORD"
                    echo "Configured RabbitMQ user $NEW_USER with password $NEW_PASSWORD" >> /etc/bakavps/logs/bakavps.log
                    
                    # Lưu thông tin vào INFO_FILE
                    echo "Username: $NEW_USER" | sudo tee "$INFO_FILE" >/dev/null
                    echo "Password: $NEW_PASSWORD" | sudo tee -a "$INFO_FILE" >/dev/null
                    sudo chmod 600 "$INFO_FILE"
                    echo "Thông tin đăng nhập đã được lưu vào $INFO_FILE"
                else
                    echo "Cấu hình lại user RabbitMQ thất bại! Kiểm tra log Docker:"
                    docker logs "$CONTAINER_NAME"
                    echo "Failed to reconfigure RabbitMQ user" >> /etc/bakavps/logs/bakavps.log
                fi
            else
                echo "Cài đặt lại RabbitMQ thất bại!"
                echo "Failed to reinstall RabbitMQ via Docker" >> /etc/bakavps/logs/bakavps.log
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
