1. Cập nhật và cài đặt thư viện

sudo apt-get update

sudo apt-get install -y build-essential libpcre2-dev zlib1g-dev libssl-dev curl wget

2. Tải NGINX 1.26.1

cd /tmp

wget -q -c http://nginx.org/download/nginx-1.26.1.tar.gz

rm -rf nginx-1.26.1

tar -xzf nginx-1.26.1.tar.gz

cd nginx-1.26.1

3. Sửa Server Signature

CUSTOM_SERVER_NAME="Custom-SecureGateway/1.0"

sed -i '14c\#define NGINX_VER          "Custom-SecureGateway/1.0"' src/core/nginx.h

sed -i 's|#define NGINX_VAR          "NGINX"|#define NGINX_VAR          "Custom-SecureGateway"|' src/core/nginx.h

sed -i '49c\static u_char ngx_http_server_string[] = "Server: Custom-SecureGateway/1.0" CRLF;' src/http/ngx_http_header_filter_module.c

sed -i '50c\static u_char ngx_http_server_full_string[] = "Server: Custom-SecureGateway/1.0" CRLF;' src/http/ngx_http_header_filter_module.c

grep -n "NGINX_" src/core/nginx.h

sed -n '49,50p' src/http/ngx_http_header_filter_module.c

4. Configure NGINX

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

5. Build và cài đặt

make -j$(nproc)

sudo make install

6. Tạo thư mục cấu hình và log

sudo mkdir -p /var/log/nginx /etc/nginx/conf.d

7. Tạo systemd service

sudo tee /etc/systemd/system/nginx.service > /dev/null << 'EOF'
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
EOF

8. Tạo nginx.conf

sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
worker_processes auto;

pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;
    sendfile on;

    include /etc/nginx/conf.d/*.conf;
}
EOF

9. Kiểm tra và khởi động NGINX

sudo /usr/local/bin/nginx -t

sudo systemctl daemon-reload

sudo systemctl enable --now nginx

sudo systemctl status nginx --no-pager

curl -I http://localhost
