#!/bin/bash

# ==========================================================
# setup_firewall.sh
# Cấu hình Firewall UFW cho hệ thống NGINX Reverse Proxy
# Phụ trách: SV3
# ==========================================================

set -euo pipefail

echo "=========================================================="
echo "       CẤU HÌNH FIREWALL UFW - SV3"
echo "=========================================================="

echo "[1/7] Cài đặt UFW..."
sudo apt-get update
sudo apt-get install -y ufw

echo "[2/7] Thiết lập chính sách mặc định..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "[3/7] Mở cổng SSH 22..."
sudo ufw allow 22/tcp comment 'SSH Port'

echo "[4/7] Mở cổng HTTP 80 và HTTPS 443..."
sudo ufw allow 80/tcp comment 'HTTP Proxy Port'
sudo ufw allow 443/tcp comment 'HTTPS Proxy Port'

echo "[5/7] Chặn truy cập trực tiếp Backend..."
sudo ufw deny log 8081/tcp comment 'Block Direct Backend 1'
sudo ufw deny log 8082/tcp comment 'Block Direct Backend 2'

echo "[6/7] Bật UFW Logging..."
sudo ufw logging medium

echo "[7/7] Kích hoạt UFW..."
sudo ufw --force enable

echo
echo "=========================================================="
echo "             TRẠNG THÁI FIREWALL"
echo "=========================================================="

sudo ufw status verbose

echo
echo "=========================================================="
echo "             DANH SÁCH RULE UFW"
echo "=========================================================="

sudo ufw status numbered

echo
echo "=========================================================="
echo "     TƯỜNG LỬA ĐÃ THIẾT LẬP THÀNH CÔNG"
echo "=========================================================="

echo
echo "Các cổng được phép:"
echo "  22   -> SSH"
echo "  80   -> HTTP"
echo "  443  -> HTTPS"
echo
echo "Các cổng Backend bị chặn:"
echo "  8081 -> Backend 1"
echo "  8082 -> Backend 2"
echo
