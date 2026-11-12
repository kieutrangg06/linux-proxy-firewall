#!/bin/bash
set -euo pipefail
UPSTREAM_FILE="/etc/nginx/sv2/upstream.conf"

get_current_backends() {
    # Tự động trích xuất 2 node backend đang có trong upstream.conf
    SERVERS=($(grep -E '^[[:space:]]*server[[:space:]]+' "$UPSTREAM_FILE" | awk '{print $2}' | tr -d ';' || true))
    NODE1="${SERVERS[0]:-127.0.0.1:8081}"
    NODE2="${SERVERS[1]:-127.0.0.1:8082}"
}

apply_config() {
    sudo /usr/local/bin/nginx -t
    sudo systemctl reload nginx
    echo "=> Cập nhật cấu hình thành công! (Zero-Downtime Reload)"
    sleep 2
}

show_menu() {
    clear
    get_current_backends
    echo "=================================================="
    echo "         AUTOMATION PROXY MANAGEMENT SCRIPT         "
    echo "=================================================="
    echo " Node 1 hiện tại: $NODE1"
    echo " Node 2 hiện tại: $NODE2"
    echo "--------------------------------------------------"
    echo "1. Cân bằng tải Round Robin (Bật cả 2 Server)"
    echo "2. Chuyển sang CHỈ DÙNG Server 1"
    echo "3. Chuyển sang CHỈ DÙNG Server 2"
    echo "4. Đổi thuật toán sang IP Hash (Session Persistence)"
    echo "5. Nhập IP cụm 3 Máy (Chuyển sang phân tán)"
    echo "6. Chuyển về cụm Local (127.0.0.1:8081/8082)"
    echo "7. Kiểm tra cú pháp NGINX (nginx -t)"
    echo "8. Xem nội dung file upstream.conf"
    echo "0. Thoát"
    echo "=================================================="
    read -p "Chọn chức năng [0-8]: " choice
}

while true; do
    show_menu
    case "$choice" in
        1)
            sudo tee "$UPSTREAM_FILE" > /dev/null <<UPSTREAM
upstream backend_cluster {
    server $NODE1 max_fails=1 fail_timeout=10s;
    server $NODE2 max_fails=1 fail_timeout=10s;
}
UPSTREAM
            apply_config
            ;;
        2)
            sudo tee "$UPSTREAM_FILE" > /dev/null <<UPSTREAM
upstream backend_cluster {
    server $NODE1 max_fails=1 fail_timeout=10s;
    server $NODE2 down;
}
UPSTREAM
            apply_config
            ;;
        3)
            sudo tee "$UPSTREAM_FILE" > /dev/null <<UPSTREAM
upstream backend_cluster {
    server $NODE1 down;
    server $NODE2 max_fails=1 fail_timeout=10s;
}
UPSTREAM
            apply_config
            ;;
        4)
            sudo tee "$UPSTREAM_FILE" > /dev/null <<UPSTREAM
upstream backend_cluster {
    ip_hash;
    server $NODE1;
    server $NODE2;
}
UPSTREAM
            apply_config
            ;;
        5)
            echo "--- THIẾT LẬP IP MÔ HÌNH 3 MÁY PHÂN TÁN ---"
            read -p "Nhập IP Máy 2 (Backend 1 - BLUE): " IP2
            read -p "Nhập IP Máy 3 (Backend 2 - RED): " IP3
            [[ "$IP2" =~ : ]] || IP2="${IP2}:80"
            [[ "$IP3" =~ : ]] || IP3="${IP3}:80"
            sudo tee "$UPSTREAM_FILE" > /dev/null <<UPSTREAM
upstream backend_cluster {
    server $IP2 max_fails=1 fail_timeout=10s;
    server $IP3 max_fails=1 fail_timeout=10s;
}
UPSTREAM
            apply_config
            ;;
        6)
            sudo systemctl restart backend1.service backend2.service 2>/dev/null || true
            sudo tee "$UPSTREAM_FILE" > /dev/null <<UPSTREAM
upstream backend_cluster {
    server 127.0.0.1:8081 max_fails=1 fail_timeout=10s;
    server 127.0.0.1:8082 max_fails=1 fail_timeout=10s;
}
UPSTREAM
            apply_config
            ;;
        7)
            sudo /usr/local/bin/nginx -t
            read -p "Nhấn Enter tiếp tục..."
            ;;
        8)
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
