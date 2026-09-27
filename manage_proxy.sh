#!/bin/bash
CONF_FILE="/etc/nginx/conf.d/loadbalancer.conf"

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
    echo "6. Xem cấu hình hiện tại"
    echo "0. Thoát"
    echo "=================================================="
    read -p "Chọn chức năng [0-6]: " choice
}

write_config() {
    local upstream_content="$1"
    sudo tee $CONF_FILE > /dev/null << CONF
upstream backend_cluster {
    $upstream_content
}

server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;

    location / {
        limit_req zone=anti_dos burst=10 nodelay;
        proxy_pass http://backend_cluster;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Connection "";
    }
}
CONF
    sudo /usr/local/bin/nginx -t && sudo systemctl restart nginx
    echo "=> Cập nhật cấu hình thành công!"
    sleep 2
}

while true; do
    show_menu
    case $choice in
        1)
            write_config "server 127.0.0.1:8081;\n    server 127.0.0.1:8082;"
            ;;
        2)
            write_config "server 127.0.0.1:8081;\n    server 127.0.0.1:8082 down;"
            ;;
        3)
            write_config "server 127.0.0.1:8081 down;\n    server 127.0.0.1:8082;"
            ;;
        4)
            write_config "ip_hash;\n    server 127.0.0.1:8081;\n    server 127.0.0.1:8082;"
            ;;
        5)
            sudo /usr/local/bin/nginx -t
            read -p "Nhấn Enter tiếp tục..."
            ;;
        6)
            cat $CONF_FILE
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
