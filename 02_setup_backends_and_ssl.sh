#!/usr/bin/env bash
set -euo pipefail

NGINX_BIN="/usr/local/bin/nginx"
SSL_DIR="/etc/nginx/ssl"
CONF_FILE="/etc/nginx/conf.d/loadbalancer.conf"
UPSTREAM_FILE="/etc/nginx/sv2/upstream.conf"

MODE="local"
BACKEND1_IP="127.0.0.1:8081"
BACKEND2_IP="127.0.0.1:8082"
GATEWAY_IP=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        --backend1) BACKEND1_IP="$2"; shift 2 ;;
        --backend2) BACKEND2_IP="$2"; shift 2 ;;
        --gateway-ip) GATEWAY_IP="$2"; shift 2 ;;
        *) echo "Error: Invalid argument: $1" >&2; exit 1 ;;
    esac
done

[[ $EUID -eq 0 ]] || { echo "Please run with sudo!" >&2; exit 1; }

# Auto-detect Gateway IP if not provided
if [[ -z "$GATEWAY_IP" ]]; then
    GATEWAY_IP=$(hostname -I | awk '{print $1}')
fi

echo "=========================================================="
echo "   [SV2] SETUP BACKEND CLUSTER AND HTTPS SECURITY ($MODE)"
echo "=========================================================="

# 1. Manage Backend Services
if [[ "$MODE" == "local" ]]; then
    echo "--> [1/4] Initializing 2 local Web Backends (Python Loopback)..."
    for b in 1 2; do
        port=$((8080 + b))
        color=$([[ $b -eq 1 ]] && echo "BLUE" || echo "RED")
        bg=$([[ $b -eq 1 ]] && echo "#007bff" || echo "#dc3545")
        
        install -d -m 0755 "/var/www/backend$b"
        cat > "/var/www/backend$b/index.html" <<HTML
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Backend $b - $color</title></head>
<body style="background:$bg;color:white;text-align:center;font-family:sans-serif;padding-top:100px">
    <h1>SERVER BACKEND 0$b - $color (Local Host)</h1>
    <p>Defense-in-Depth HTTPS Gateway Active</p>
</body>
</html>
HTML
        cat > "/etc/systemd/system/backend$b.service" <<UNIT
[Unit]
Description=Backend $b - Python HTTP
After=network.target

[Service]
Type=simple
User=nobody
WorkingDirectory=/var/www/backend$b
ExecStart=/usr/bin/python3 -m http.server $port --bind 127.0.0.1 --directory /var/www/backend$b
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
    done
    systemctl daemon-reload
    systemctl restart backend1.service backend2.service
    BACKEND1_TARGET="127.0.0.1:8081"
    BACKEND2_TARGET="127.0.0.1:8082"
else
    echo "--> [1/4] Distributed Mode (3-Machine Cluster): Stopping local backends (if any) and pointing to 2 remote nodes..."
    systemctl stop backend1.service backend2.service 2>/dev/null || true
    systemctl disable backend1.service backend2.service 2>/dev/null || true
    # Default to port :80 if the user only provides an IP
    [[ "$BACKEND1_IP" =~ : ]] && BACKEND1_TARGET="$BACKEND1_IP" || BACKEND1_TARGET="${BACKEND1_IP}:80"
    [[ "$BACKEND2_IP" =~ : ]] && BACKEND2_TARGET="$BACKEND2_IP" || BACKEND2_TARGET="${BACKEND2_IP}:80"
fi

# 2. Generate X.509 SSL certificate with RFC 5280 SAN support
echo "--> [2/4] Generating SSL/TLS certificate with SAN extension..."
mkdir -p "$SSL_DIR"
SAN_CONFIG="DNS:localhost,IP:127.0.0.1"
if [[ -n "$GATEWAY_IP" && "$GATEWAY_IP" != "127.0.0.1" ]]; then
    SAN_CONFIG="${SAN_CONFIG},IP:${GATEWAY_IP}"
fi

openssl req -x509 -nodes -sha256 -days 365 -newkey rsa:2048 \
    -keyout "$SSL_DIR/server.key" -out "$SSL_DIR/server.crt" \
    -subj "/C=VN/ST=DaNang/O=VKU/OU=NetworkDefense/CN=${GATEWAY_IP:-localhost}" \
    -addext "subjectAltName=${SAN_CONFIG}" >/dev/null 2>&1
chmod 600 "$SSL_DIR/server.key"
chmod 644 "$SSL_DIR/server.crt"

# 3. Create NGINX Upstream and VirtualHost configurations
echo "--> [3/4] Configuring separate Upstream and HTTPS Gateway VirtualHost..."
mkdir -p /etc/nginx/sv2 /etc/nginx/conf.d

cat > "$UPSTREAM_FILE" <<UPSTREAM
upstream backend_cluster {
    server $BACKEND1_TARGET max_fails=1 fail_timeout=10s;
    server $BACKEND2_TARGET max_fails=1 fail_timeout=10s;
}
UPSTREAM

cat > "$CONF_FILE" <<NGINX_CONF
include $UPSTREAM_FILE;

limit_req_zone \$binary_remote_addr zone=sv2_per_ip:10m rate=5r/s;

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate $SSL_DIR/server.crt;
    ssl_certificate_key $SSL_DIR/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        limit_req zone=sv2_per_ip burst=10 nodelay;
        limit_req_status 503;

        proxy_pass http://backend_cluster;
        proxy_connect_timeout 3s;
        proxy_read_timeout 10s;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        add_header Cache-Control "no-store" always;
    }
}
NGINX_CONF

# 4. Test configuration syntax and enable NGINX
echo "--> [4/4] Testing NGINX configuration and starting service..."
"$NGINX_BIN" -t
systemctl restart nginx.service
systemctl enable nginx.service

echo "=== [SV2] BACKEND CLUSTER AND HTTPS SECURITY SETUP COMPLETED ==="
