#!/bin/bash
set -e
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH Port'
sudo ufw allow 80/tcp comment 'HTTP Proxy Port'
sudo ufw deny 8081/tcp comment 'Block Direct Backend 1'
sudo ufw deny 8082/tcp comment 'Block Direct Backend 2'
echo "y" | sudo ufw enable
sudo ufw status verbose
echo "=== TƯỜNG LỬA ĐÃ THIẾT LẬP AN TOÀN ==="
