#!/bin/bash
CONF_FILE="/etc/nginx/conf.d/loadbalancer.conf"

show_menu() {
    clear
    echo "=================================================="
    echo "        AUTOMATION PROXY MANAGEMENT SCRIPT         "
    echo "=================================================="
    echo "1. Cấu hình Load Balancing cả 2 Server (Xanh + Đỏ)"
    echo "2. Chuyển sang CHỈ DÙNG Server 1 (Xanh)"
    echo "3. Chuyển sang CHỈ DÙNG Server 2 (Đỏ)"
    echo "4. Đổi thuật toán sang IP Hash"
    echo "5. Kiểm tra cú pháp cấu hình NGINX"
    echo "6. Xem file cấu hình hiện tại"
    echo "0. Thoát"
    echo "=================================================="
    read -p "Chọn chức năng [0-6]: " choice
}

while true; do
    show_menu
    case $choice in
        1)
            sudo tee $CONF_FILE > /dev/null << 'CONFIG'
upstream backend_cluster {
    server 127.0.0.1:8081;
    server 127.0.0.1:8082;
}
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://backend_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Connection "";
    }
}
CONFIG
            sudo /usr/local/bin/nginx -t && sudo systemctl restart nginx
            echo "=> Đã kích hoạt Load Balancing cả 2 Server!"; sleep 2
            ;;
        2)
            sudo tee $CONF_FILE > /dev/null << 'CONFIG'
upstream backend_cluster {
    server 127.0.0.1:8081;
    server 127.0.0.1:8082 down;
}
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://backend_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Connection "";
    }
}
CONFIG
            sudo /usr/local/bin/nginx -t && sudo systemctl restart nginx
            echo "=> Đã tắt Server 2, chỉ chạy Server 1 (Xanh)!"; sleep 2
            ;;
        3)
            sudo tee $CONF_FILE > /dev/null << 'CONFIG'
upstream backend_cluster {
    server 127.0.0.1:8081 down;
    server 127.0.0.1:8082;
}
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://backend_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Connection "";
    }
}
CONFIG
            sudo /usr/local/bin/nginx -t && sudo systemctl restart nginx
            echo "=> Đã tắt Server 1, chỉ chạy Server 2 (Đỏ)!"; sleep 2
            ;;
        4)
            sudo tee $CONF_FILE > /dev/null << 'CONFIG'
upstream backend_cluster {
    ip_hash;
    server 127.0.0.1:8081;
    server 127.0.0.1:8082;
}
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://backend_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
CONFIG
            sudo /usr/local/bin/nginx -t && sudo systemctl restart nginx
            echo "=> Đã chuyển sang thuật toán IP Hash!"; sleep 2
            ;;
        5)
            sudo /usr/local/bin/nginx -t
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        6)
            cat $CONF_FILE
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Lựa chọn không hợp lệ!"; sleep 1
            ;;
    esac
done
