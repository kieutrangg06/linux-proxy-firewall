#!/bin/bash
set -euo pipefail

echo "=========================================================="
echo "   [SV1] INSTALL DEPENDENCIES, PATCH C SOURCE & BUILD NGINX"
echo "=========================================================="

# 1. Stop existing Ubuntu Nginx if running
sudo systemctl stop nginx 2>/dev/null || true

# 2. Install build dependencies
sudo apt-get update
sudo apt-get install -y build-essential libpcre2-dev zlib1g-dev libssl-dev curl wget

NGINX_VER="1.26.1"
CUSTOM_SIG="Custom-SecureGateway/1.0"
CUSTOM_VAR="Custom-SecureGateway"

cd /tmp
wget -q -c "http://nginx.org/download/nginx-${NGINX_VER}.tar.gz"
rm -rf "nginx-${NGINX_VER}"
tar -xzf "nginx-${NGINX_VER}.tar.gz"
cd "nginx-${NGINX_VER}"

echo "--> Patching C source code to customize Server Signature at binary level..."
sed -i -E "s|#define NGINX_VER[[:space:]]+.*|#define NGINX_VER          \"${CUSTOM_SIG}\"|" src/core/nginx.h
sed -i -E "s|#define NGINX_VAR[[:space:]]+.*|#define NGINX_VAR          \"${CUSTOM_VAR}\"|" src/core/nginx.h
sed -i -E "s|static u_char ngx_http_server_string\[\] = \"Server: nginx\" CRLF;|static u_char ngx_http_server_string[] = \"Server: ${CUSTOM_SIG}\" CRLF;|" src/http/ngx_http_header_filter_module.c
sed -i -E "s|static u_char ngx_http_server_full_string\[\] = \"Server: \" NGINX_VER CRLF;|static u_char ngx_http_server_full_string[] = \"Server: ${CUSTOM_SIG}\" CRLF;|" src/http/ngx_http_header_filter_module.c

echo "--> Configuring build flags with security hardening options..."
./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/local/bin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --with-pcre \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-cc-opt='-O2 -fstack-protector-strong -Wformat -Werror=format-security -Wno-error'

make -j"$(nproc)"
sudo make install

echo "--> Creating Systemd service configuration and system directories..."
sudo mkdir -p /var/log/nginx /etc/nginx/conf.d /etc/nginx/sv2 /etc/nginx/ssl

sudo tee /etc/systemd/system/nginx.service > /dev/null << 'UNIT'
[Unit]
Description=The Custom NGINX HTTP and Reverse Proxy Gateway
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/local/bin/nginx -t
ExecStart=/usr/local/bin/nginx
ExecReload=/usr/local/bin/nginx -s reload
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
UNIT

sudo tee /etc/nginx/nginx.conf > /dev/null << 'CONF'
worker_processes auto;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    server_tokens off;

    include /etc/nginx/conf.d/*.conf;
}
CONF

sudo systemctl daemon-reload
echo "=== [SV1] NGINX BUILD AND INSTALLATION COMPLETED ==="
