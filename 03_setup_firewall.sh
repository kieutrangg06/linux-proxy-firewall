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
echo "   [SV3] CONFIGURE UFW FIREWALL ON GATEWAY (NODE 1)"
echo "=========================================================="

sudo apt-get update
sudo apt-get install -y ufw

echo "--> Setting default policies: Deny all incoming (Ingress), allow outgoing (Egress)..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "--> Allowing SSH management (22), HTTP (80), and HTTPS (443)..."
sudo ufw allow 22/tcp comment 'SSH Management'
sudo ufw allow 80/tcp comment 'HTTP 301 Redirect'
sudo ufw allow 443/tcp comment 'HTTPS Reverse Proxy'

if [[ "$MODE" == "local" ]]; then
    echo "--> Blocking and logging direct access to local Backend ports..."
    sudo ufw deny log 8081/tcp comment 'Block Direct Local Backend 1'
    sudo ufw deny log 8082/tcp comment 'Block Direct Local Backend 2'
fi

echo "--> Enabling UFW logging at medium level for telemetry collection..."
sudo ufw logging medium
echo "y" | sudo ufw enable

echo
sudo ufw status verbose
echo "=== [SV3] FIREWALL CONFIGURATION COMPLETED ==="
