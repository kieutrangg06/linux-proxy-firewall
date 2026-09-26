#!/bin/bash
set -e

sudo mkdir -p /var/www/backend1 /var/www/backend2

sudo tee /var/www/backend1/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head><title>Backend 1</title></head>
<body style="background-color: #007bff; color: white; text-align: center; font-family: sans-serif; padding-top: 100px;">
    <h1>SERVER BACKEND 01 - BLUE</h1>
    <p>Handled by Custom Gateway</p>
</body>
</html>
HTML

sudo tee /var/www/backend2/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head><title>Backend 2</title></head>
<body style="background-color: #dc3545; color: white; text-align: center; font-family: sans-serif; padding-top: 100px;">
    <h1>SERVER BACKEND 02 - RED</h1>
    <p>Handled by Custom Gateway</p>
</body>
</html>
HTML

sudo tee /etc/systemd/system/backend1.service << 'UNIT'
[Unit]
Description=Backend 1 Blue
After=network.target
[Service]
ExecStart=/usr/bin/python3 -m http.server 8081 --bind 127.0.0.1 --directory /var/www/backend1
Restart=always
User=nobody
[Install]
WantedBy=multi-user.target
UNIT

sudo tee /etc/systemd/system/backend2.service << 'UNIT'
[Unit]
Description=Backend 2 Red
After=network.target
[Service]
ExecStart=/usr/bin/python3 -m http.server 8082 --bind 127.0.0.1 --directory /var/www/backend2
Restart=always
User=nobody
[Install]
WantedBy=multi-user.target
UNIT

sudo tee /etc/nginx/conf.d/loadbalancer.conf << 'LB'
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
LB

sudo systemctl daemon-reload
sudo systemctl enable --now backend1 backend2
echo "=== DỰNG BACKEND HOÀN TẤT ==="
