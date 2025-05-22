#!/bin/bash

source /etc/bakavps/config/settings.conf
source /etc/bakavps/modules/utils.sh

echo "=== Cài đặt Node Version Manager (NVM) và PNPM ==="

# Xóa NVM cũ nếu tồn tại
if [ -d "$HOME/.nvm" ]; then
    echo "NVM đã được cài tại $HOME/.nvm"
fi

# Lấy phiên bản NVM mới nhất từ GitHub
echo "Đang xác định phiên bản NVM mới nhất..."
LATEST_NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
if [ -z "$LATEST_NVM_VERSION" ]; then
    echo "Không thể lấy phiên bản NVM mới nhất. Dùng phiên bản mặc định v0.39.7."
    LATEST_NVM_VERSION="v0.39.7"
fi
echo "Phiên bản NVM mới nhất: $LATEST_NVM_VERSION"

# Cài đặt NVM bản mới nhất
echo "Đang cài đặt NVM $LATEST_NVM_VERSION..."
sudo dnf install -y curl
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$LATEST_NVM_VERSION/install.sh" | bash
if [ $? -eq 0 ] && [ -f "$HOME/.nvm/nvm.sh" ]; then
    echo "Cài đặt NVM $LATEST_NVM_VERSION thành công!"
    echo "Installed NVM $LATEST_NVM_VERSION" >> /etc/bakavps/logs/bakavps.log
    source "$HOME/.nvm/nvm.sh"
    nvm --version >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "NVM cài đặt nhưng không hoạt động đúng. Thoát..."
        echo "Failed to verify NVM functionality" >> /etc/bakavps/logs/bakavps.log
        exit 1
    fi
else
    echo "Cài đặt NVM $LATEST_NVM_VERSION thất bại!"
    echo "Failed to install NVM $LATEST_NVM_VERSION" >> /etc/bakavps/logs/bakavps.log
    exit 1
fi

# Menu quản lý NVM và PNPM
while true; do
    echo "1. Cài đặt phiên bản Node.js"
    echo "2. Danh sách phiên bản Node.js đã cài"
    echo "3. Sử dụng phiên bản Node.js"
    echo "4. Xóa phiên bản Node.js"
    echo "5. Cài đặt hoặc cập nhật PNPM"
    echo "6. Cài đặt hoặc cập nhật PM2"
    echo "0. Quay lại"
    read -p "Chọn option: " nvm_choice
    case $nvm_choice in
        1)
            echo "Danh sách một số phiên bản Node.js có sẵn (hoặc dùng 'nvm ls-remote' để xem đầy đủ):"
            nvm ls-remote | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | tail -n 10
            read -p "Nhập phiên bản Node.js (ví dụ: 20.11.1, để trống để cài mới nhất): " NODE_VERSION
            if [ -z "$NODE_VERSION" ]; then
                NODE_VERSION=$(nvm ls-remote | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | tail -n 1 | tr -d ' ')
                echo "Không nhập phiên bản, sẽ cài phiên bản mới nhất: $NODE_VERSION"
            fi
            if [[ "$NODE_VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "Đang cài đặt $NODE_VERSION..."
                nvm install "$NODE_VERSION"
                if [ $? -eq 0 ]; then
                    echo "Cài đặt $NODE_VERSION thành công!"
                    nvm use "$NODE_VERSION"
                    source "$HOME/.nvm/nvm.sh"  # Đảm bảo nguồn lại NVM
                    if command -v node >/dev/null 2>&1; then
                        echo "Đã đặt $NODE_VERSION làm phiên bản hiện hành!"
                        node --version
                        echo "Installed Node.js version $NODE_VERSION" >> /etc/bakavps/logs/bakavps.log
                    else
                        echo "Lỗi: Không thể tìm thấy lệnh 'node' sau khi cài đặt!"
                        echo "Failed to activate Node.js version $NODE_VERSION" >> /etc/bakavps/logs/bakavps.log
                    fi
                else
                    echo "Cài đặt $NODE_VERSION thất bại!"
                    echo "Failed to install Node.js version $NODE_VERSION" >> /etc/bakavps/logs/bakavps.log
                fi
            else
                echo "Phiên bản không hợp lệ! Vui lòng nhập dạng X.Y.Z (ví dụ: 20.11.1)."
                nvm ls-remote
            fi
            ;;
        2)
            echo "Danh sách phiên bản Node.js đã cài:"
            nvm ls
            ;;
        3)
            echo "Danh sách phiên bản Node.js đã cài:"
            nvm ls
            read -p "Nhập phiên bản Node.js muốn sử dụng (ví dụ: 20.11.1): " NODE_VERSION
            if nvm ls | grep -q "$NODE_VERSION"; then
                nvm use "$NODE_VERSION"
                source "$HOME/.nvm/nvm.sh"  # Đảm bảo nguồn lại NVM
                if command -v node >/dev/null 2>&1; then
                    echo "Đã chuyển sang sử dụng $NODE_VERSION!"
                    node --version
                    echo "Switched to Node.js version $NODE_VERSION" >> /etc/bakavps/logs/bakavps.log
                else
                    echo "Lỗi: Không thể tìm thấy lệnh 'node' sau khi chuyển phiên bản!"
                    echo "Failed to use Node.js version $NODE_VERSION" >> /etc/bakavps/logs/bakavps.log
                fi
            else
                echo "Phiên bản $NODE_VERSION chưa được cài đặt!"
            fi
            ;;
        4)
            echo "Danh sách phiên bản Node.js đã cài:"
            nvm ls
            read -p "Nhập phiên bản Node.js muốn xóa (ví dụ: 20.11.1): " NODE_VERSION
            if nvm ls | grep -q "$NODE_VERSION"; then
                read -p "Bạn chắc chắn muốn xóa $NODE_VERSION? (y/n): " CONFIRM
                if [ "$CONFIRM" == "y" ]; then
                    nvm uninstall "$NODE_VERSION"
                    if [ $? -eq 0 ]; then
                        echo "Đã xóa $NODE_VERSION thành công!"
                        echo "Uninstalled Node.js version $NODE_VERSION" >> /etc/bakavps/logs/bakavps.log
                    else
                        echo "Xóa $NODE_VERSION thất bại!"
                    fi
                else
                    echo "Hủy xóa $NODE_VERSION."
                fi
            else
                echo "Phiên bản $NODE_VERSION không tồn tại!"
            fi
            ;;
        5)
            if ! command -v node >/dev/null 2>&1; then
                echo "Chưa có phiên bản Node.js nào được kích hoạt. Hãy cài và sử dụng một phiên bản trước!"
            else
                echo "Đang cài đặt hoặc cập nhật PNPM..."
                npm install -g pnpm
                if [ $? -eq 0 ]; then
                    echo "Cài đặt PNPM thành công!"
                    pnpm --version
                    echo "Installed PNPM" >> /etc/bakavps/logs/bakavps.log
                else
                    echo "Cài đặt PNPM thất bại!"
                    echo "Failed to install PNPM" >> /etc/bakavps/logs/bakavps.log
                fi
            fi
            ;;
        6)
            if ! command -v node >/dev/null 2>&1; then
                echo "Chưa có phiên bản Node.js nào được kích hoạt. Hãy cài và sử dụng một phiên bản trước!"
            else
                echo "Đang cài đặt hoặc cập nhật PM2..."
                npm install -g pm2
                if [ $? -eq 0 ]; then
                    echo "Cài đặt PM2 thành công!"
                    pm2 --version
                    echo "Installed PM2" >> /etc/bakavps/logs/bakavps.log
                else
                    echo "Cài đặt PM2 thất bại!"
                    echo "Failed to install PM2" >> /etc/bakavps/logs/bakavps.log
                fi
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
