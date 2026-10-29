#!/bin/bash
set -euo pipefail
UPSTREAM_FILE="/etc/nginx/sv2/upstream.conf"

show_menu() {
    clear
    echo "=================================================="
    echo "        AUTOMATION PROXY MANAGEMENT SCRIPT         "
    echo "=================================================="
    echo "1. Load Balancing cả 2 Server (Xanh + Đỏ)"
    echo "2. Chuyển sang CHỈ DÙNG Server 1 (Xanh)"
    echo "3. Chuyển sang CHỈ DÙNG Server 2 (Đỏ)"
    echo "4. Đổi thuật toán sang IP Hash"
    echo "5. Kiểm tra cú pháp NGINX"
    echo "6. Xem file cấu hình upstream hiện tại"
    echo "0. Thoát"
    echo "=================================================="
    read -p "Chọn chức năng [0-6]: " choice
}

apply_config() {
    sudo /usr/local/bin/nginx -t
    sudo systemctl reload nginx
    echo "=> Cập nhật cấu hình thành công!"
    sleep 2
}

while true; do
    show_menu
    case "$choice" in
        1)
            sudo tee "$UPSTREAM_FILE" > /dev/null << 'UPSTREAM'
upstream backend_cluster {
    server 127.0.0.1:8081 max_fails=1 fail_timeout=10s;
    server 127.0.0.1:8082 max_fails=1 fail_timeout=10s;
}
UPSTREAM
            apply_config
            ;;
        2)
            sudo tee "$UPSTREAM_FILE" > /dev/null << 'UPSTREAM'
upstream backend_cluster {
    server 127.0.0.1:8081 max_fails=1 fail_timeout=10s;
    server 127.0.0.1:8082 down;
}
UPSTREAM
            apply_config
            ;;
        3)
            sudo tee "$UPSTREAM_FILE" > /dev/null << 'UPSTREAM'
upstream backend_cluster {
    server 127.0.0.1:8081 down;
    server 127.0.0.1:8082 max_fails=1 fail_timeout=10s;
}
UPSTREAM
            apply_config
            ;;
        4)
            sudo tee "$UPSTREAM_FILE" > /dev/null << 'UPSTREAM'
upstream backend_cluster {
    ip_hash;
    server 127.0.0.1:8081;
    server 127.0.0.1:8082;
}
UPSTREAM
            apply_config
            ;;
        5)
            sudo /usr/local/bin/nginx -t
            read -p "Nhấn Enter tiếp tục..."
            ;;
        6)
            echo "--- Nội dung $UPSTREAM_FILE ---"
            cat "$UPSTREAM_FILE"
            echo "-----------------------------------"
            read -p "Nhấn Enter tiếp tục..."
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Lựa chọn không hợp lệ!"; sleep 1
            ;;
    esac
done
