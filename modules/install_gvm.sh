#!/bin/bash

source /etc/bakavps/config/settings.conf
source /etc/bakavps/modules/utils.sh

echo "=== Cài đặt Go Version Manager (GVM) ==="

# Kiểm tra xem GVM đã được cài đặt chưa
if [ -d "$HOME/.gvm" ]; then
    echo "GVM đã được cài đặt tại $HOME/.gvm"
else
    echo "Đang cài đặt GVM..."
    # Cài đặt các gói cần thiết
    dnf install -y curl git mercurial make bison gcc gcc-c++ glibc-devel \
               binutils autoconf automake golang tar wget patch
    # Tải và cài đặt GVM
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    if [ $? -eq 0 ]; then
        echo "Cài đặt GVM thành công!"
        echo "Installed GVM" >> /etc/bakavps/logs/bakavps.log
        # Nguồn GVM vào bash profile
        echo '[ -s "$HOME/.gvm/scripts/gvm" ] && source "$HOME/.gvm/scripts/gvm"' >> "$HOME/.bashrc"
        source "$HOME/.gvm/scripts/gvm"
    else
        echo "Cài đặt GVM thất bại!"
        echo "Failed to install GVM" >> /etc/bakavps/logs/bakavps.log
        exit 1
    fi
fi

# Menu quản lý GVM
while true; do
    echo "1. Cài đặt phiên bản Go"
    echo "2. Danh sách phiên bản Go đã cài"
    echo "3. Sử dụng phiên bản Go"
    echo "4. Xóa phiên bản Go"
    echo "0. Quay lại"
    read -p "Chọn option: " gvm_choice
    case $gvm_choice in
        1)
            read -p "Nhập phiên bản Go (ví dụ: go1.21.9 hoặc để trống để xem danh sách): " GO_VERSION
            if [ -z "$GO_VERSION" ]; then
                gvm listall
                read -p "Nhập phiên bản Go cần cài: " GO_VERSION
            fi
            if [[ "$GO_VERSION" =~ ^go[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$GO_VERSION" =~ ^go[0-9]+\.[0-9]+$ ]]; then
                echo "Đang cài đặt $GO_VERSION..."
                gvm install "$GO_VERSION" -B  # -B để cài từ binary nếu có
                if [ $? -eq 0 ]; then
                    echo "Cài đặt $GO_VERSION thành công!"
                    echo "Installed Go version $GO_VERSION" >> /etc/bakavps/logs/bakavps.log
                else
                    echo "Cài đặt $GO_VERSION thất bại!"
                    echo "Failed to install Go version $GO_VERSION" >> /etc/bakavps/logs/bakavps.log
                fi
            else
                echo "Phiên bản không hợp lệ! Vui lòng nhập dạng goX.Y.Z (ví dụ: go1.21.9)."
            fi
            ;;
        2)
            echo "Danh sách phiên bản Go đã cài:"
            gvm list
            ;;
        3)
            echo "Danh sách phiên bản Go đã cài:"
            gvm list
            read -p "Nhập phiên bản Go muốn sử dụng (ví dụ: go1.21.9): " GO_VERSION

            if gvm list | grep -q "$GO_VERSION"; then
                gvm use "$GO_VERSION" --default
                if [ $? -eq 0 ]; then
                    echo "Đã chuyển sang sử dụng $GO_VERSION và đặt làm mặc định!"
                    echo "Switched to Go version $GO_VERSION" >> /etc/bakavps/logs/bakavps.log
                    echo "Mở terminal mới hoặc chạy: source ~/.bashrc"
                else
                    echo "Chuyển sang $GO_VERSION thất bại!"
                fi
            else
                echo "Phiên bản $GO_VERSION chưa được cài đặt!"
            fi
            ;;

        4)
            echo "Danh sách phiên bản Go đã cài:"
            gvm list
            read -p "Nhập phiên bản Go muốn xóa (ví dụ: go1.21.9): " GO_VERSION
            if gvm list | grep -q "$GO_VERSION"; then
                read -p "Bạn chắc chắn muốn xóa $GO_VERSION? (y/n): " CONFIRM
                if [ "$CONFIRM" == "y" ]; then
                    gvm uninstall "$GO_VERSION"
                    if [ $? -eq 0 ]; then
                        echo "Đã xóa $GO_VERSION thành công!"
                        echo "Uninstalled Go version $GO_VERSION" >> /etc/bakavps/logs/bakavps.log
                    else
                        echo "Xóa $GO_VERSION thất bại!"
                    fi
                else
                    echo "Hủy xóa $GO_VERSION."
                fi
            else
                echo "Phiên bản $GO_VERSION không tồn tại!"
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
