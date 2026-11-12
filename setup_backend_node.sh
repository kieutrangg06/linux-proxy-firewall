#!/bin/bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Chạy bằng quyền root: sudo bash $0" >&2; exit 1; }

echo "=========================================================="
echo "   CẤU HÌNH NODE BACKEND TẬP TRUNG (DÀNH CHO MÁY 2 / MÁY 3)"
echo "=========================================================="

read -p "Nhập số thứ tự Backend (1 cho BLUE, 2 cho RED): " NODE_NUM
read -p "Nhập địa chỉ IP của Máy 1 (Gateway): " GATEWAY_IP

if [[ "$NODE_NUM" != "1" && "$NODE_NUM" != "2" ]]; then
    echo "Lựa chọn chỉ có thể là 1 hoặc 2!" >&2; exit 1
fi

COLOR=$([[ "$NODE_NUM" == "1" ]] && echo "BLUE" || echo "RED")
BG=$([[ "$NODE_NUM" == "1" ]] && echo "#007bff" || echo "#dc3545")
APP_DIR="/var/www/backend$NODE_NUM"

# 1. Tạo giao diện Web
mkdir -p "$APP_DIR"
cat > "$APP_DIR/index.html" <<HTML
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Node 0$NODE_NUM - $COLOR</title></head>
<body style="background:$BG;color:white;text-align:center;font-family:sans-serif;padding-top:120px">
    <h1>SERVER BACKEND 0$NODE_NUM - $COLOR (DISTRIBUTED NODE)</h1>
    <p>Connected via Gateway: $GATEWAY_IP</p>
</body>
</html>
HTML

# 2. Tạo Service Systemd chạy trên cổng 80
cat > "/etc/systemd/system/backend.service" <<UNIT
[Unit]
Description=Backend Distributed Node $NODE_NUM
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 -m http.server 80 --directory $APP_DIR
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable backend.service
systemctl restart backend.service

# 3. Khóa Firewall Zero-Trust: CHỈ DUY NHẤT GATEWAY ĐƯỢC KẾT NỐI CỔNG 80
apt-get update && apt-get install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow from "$GATEWAY_IP" to any port 80 proto tcp comment 'Allow Gateway Only'
ufw logging medium
echo "y" | ufw enable

echo "=== HOÀN TẤT CẤU HÌNH NODE BACKEND $NODE_NUM ($COLOR) ==="
ufw status verbose
