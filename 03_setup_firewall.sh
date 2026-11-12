#!/bin/bash
set -euo pipefail

MODE="local"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "=========================================================="
echo "   [SV3] THIẾT LẬP TƯỜNG LỬA UFW TRÊN GATEWAY (NODE 1)"
echo "=========================================================="

sudo apt-get update
sudo apt-get install -y ufw

echo "--> Thiết lập chính sách mặc định: Chặn toàn bộ Ingress, cho phép Egress..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "--> Mở cổng SSH quản trị (22), HTTP (80) và HTTPS (443)..."
sudo ufw allow 22/tcp comment 'SSH Management'
sudo ufw allow 80/tcp comment 'HTTP 301 Redirect'
sudo ufw allow 443/tcp comment 'HTTPS Reverse Proxy'

if [[ "$MODE" == "local" ]]; then
    echo "--> Chặn và ghi log truy cập trực tiếp tới các cổng Backend cục bộ..."
    sudo ufw deny log 8081/tcp comment 'Block Direct Local Backend 1'
    sudo ufw deny log 8082/tcp comment 'Block Direct Local Backend 2'
fi

echo "--> Bật UFW logging mức độ medium để trích xuất telemetry..."
sudo ufw logging medium
echo "y" | sudo ufw enable

echo
sudo ufw status verbose
echo "=== [SV3] HOÀN TẤT CẤU HÌNH TƯỜNG LỬA BẢO VỆ ==="
