#!/bin/bash
set -e

echo "=== [1/5] Cài đặt công cụ lập trình và thư viện phụ thuộc ==="
sudo apt-get update
sudo apt-get install -y build-essential libpcre2-dev zlib1g-dev libssl-dev curl wget

NGINX_VER="1.26.1"
CUSTOM_SERVER_NAME="Custom-SecureGateway/1.0"

echo "=== [2/5] Tải mã nguồn NGINX ${NGINX_VER} ==="
cd /tmp
wget -q -c http://nginx.org/download/nginx-${NGINX_VER}.tar.gz
rm -rf nginx-${NGINX_VER}
tar -xzf nginx-${NGINX_VER}.tar.gz
cd nginx-${NGINX_VER}

echo "=== [3/5] Can thiệp mã nguồn C để đổi Server Signature ==="
sed -i "s/#define NGINX_VER          \"nginx\/\" NGINX_VERSION/#define NGINX_VER          \"${CUSTOM_SERVER_NAME}\"/" src/core/nginx.h
sed -i "s/#define NGINX_VAR          \"NGINX\"/#define NGINX_VAR          \"Custom-SecureGateway\"/" src/core/nginx.h

HEADER_FILE="src/http/ngx_http_header_filter_module.c"
sed -i "s/static u_char ngx_http_server_string\[\] = \"Server: nginx\" CRLF;/static u_char ngx_http_server_string\[\] = \"Server: ${CUSTOM_SERVER_NAME}\" CRLF;/" $HEADER_FILE
sed -i "s/static u_char ngx_http_server_full_string\[\] = \"Server: \" NGINX_VER CRLF;/static u_char ngx_http_server_full_string\[\] = \"Server: ${CUSTOM_SERVER_NAME}\" CRLF;/" $HEADER_FILE

echo "=== [4/5] Cấu hình và Biên dịch NGINX ==="
./configure \
   --prefix=/etc/nginx \
   --sbin-path=/usr/local/bin/nginx \
   --conf-path=/etc/nginx/nginx.conf \
   --error-log-path=/var/log/nginx/error.log \
   --http-log-path=/var/log/nginx/access.log \
   --pid-path=/var/run/nginx.pid \
   --with-pcre \
   --with-http_ssl_module \
   --with-http_realip_module \
   --with-http_stub_status_module

make -j$(nproc)
sudo make install

echo "=== [5/5] Cấu hình Dịch vụ Systemd và NGINX.conf ==="
sudo mkdir -p /var/log/nginx /etc/nginx/conf.d

sudo tee /etc/systemd/system/nginx.service << 'UNIT'
[Unit]
Description=The Custom NGINX HTTP and reverse proxy server
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

[Install]
WantedBy=multi-user.target
UNIT

sudo tee /etc/nginx/nginx.conf << 'CONF'
worker_processes auto;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;

    include /etc/nginx/conf.d/*.conf;
}
CONF

sudo systemctl daemon-reload
sudo systemctl enable --now nginx
echo "=== BIÊN DỊCH VÀ CÀI ĐẶT NGINX HOÀN TẤT ==="
