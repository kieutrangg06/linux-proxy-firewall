#!/usr/bin/env bash
set -euo pipefail

NGINX_BIN="${NGINX_BIN:-/usr/local/bin/nginx}"
SSL_DIR=/etc/nginx/ssl
CONF_FILE=/etc/nginx/conf.d/loadbalancer.conf
UPSTREAM_FILE=/etc/nginx/sv2/upstream.conf
PREPARE_ONLY=false
RENEW_CERT=false
SERVER_IP=""
WORK_DIR=""
BACKUP_DIR=""
CONFIG_INSTALLED=false
NGINX_CHANGED=false
NGINX_WAS_ACTIVE=false

usage() {
    cat <<'USAGE'
SV2 - Backend BLUE/RED va HTTPS

sudo bash 02_setup_backends_and_ssl.sh [--prepare-only] [--server-ip IPV4] [--renew-cert]

  --prepare-only    Dung backend va certificate, khong can/cham vao NGINX.
  --server-ip IPV4  Them IP may ao vao SAN cua certificate va server_name.
  --renew-cert      Tao lai certificate/key, sao luu ban cu truoc khi thay.
  --help            Xem huong dan, khong can root.
USAGE
}

fail() {
    echo "LOI: $*" >&2
    exit 1
}

restore_config() {
    local target
    for target in "$CONF_FILE" "$UPSTREAM_FILE"; do
        if [[ -f "$BACKUP_DIR/$(basename "$target")" ]]; then
            cp -p -- "$BACKUP_DIR/$(basename "$target")" "$target" || return 1
        else
            rm -f -- "$target" || return 1
        fi
    done
}

finish() {
    local result=$?
    trap - EXIT
    set +e
    if [[ $result -ne 0 && "$CONFIG_INSTALLED" == true ]]; then
        echo "Khoi phuc cau hinh NGINX tu $BACKUP_DIR" >&2
        if restore_config && [[ "$NGINX_CHANGED" == true ]]; then
            if [[ "$NGINX_WAS_ACTIVE" == true ]]; then
                "$NGINX_BIN" -t && systemctl reload nginx.service
            else
                systemctl stop nginx.service
            fi
        fi
    fi
    if [[ -n "$WORK_DIR" ]]; then
        rm -f -- "$WORK_DIR/backend1.service" "$WORK_DIR/backend2.service" \
            "$WORK_DIR/server.key" "$WORK_DIR/server.crt" \
            "$WORK_DIR/loadbalancer.conf" "$WORK_DIR/upstream.conf"
        rmdir -- "$WORK_DIR"
    fi
    exit "$result"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prepare-only) PREPARE_ONLY=true; shift ;;
        --renew-cert) RENEW_CERT=true; shift ;;
        --server-ip)
            [[ $# -ge 2 ]] || fail "--server-ip can mot dia chi IPv4."
            SERVER_IP="$2"
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; fail "Tham so khong hop le: $1" ;;
    esac
done

[[ $EUID -eq 0 ]] || fail "Chay bang sudo bash $0"
[[ "$(uname -s)" == Linux ]] || fail "Script can Linux/Ubuntu."
[[ -d /run/systemd/system ]] || fail "Can systemd."
for command_name in curl openssl python3 systemctl ss install mktemp; do
    command -v "$command_name" > /dev/null || fail "Thieu $command_name."
done
[[ -x /usr/bin/python3 ]] || fail "Can /usr/bin/python3 cho backend services."

if [[ -n "$SERVER_IP" ]]; then
    SERVER_IP="$(python3 -c 'import ipaddress,sys; print(ipaddress.IPv4Address(sys.argv[1]))' "$SERVER_IP")" \
        || fail "--server-ip phai la IPv4 hop le."
fi

if [[ "$PREPARE_ONLY" == false ]]; then
    [[ -x "$NGINX_BIN" ]] || fail "Chua co $NGINX_BIN. Can chay SV1 truoc."
    nginx_build="$("$NGINX_BIN" -V 2>&1)"
    [[ "$nginx_build" == *--with-http_ssl_module* ]] || fail "NGINX thieu --with-http_ssl_module."
    systemctl cat nginx.service > /dev/null 2>&1 || fail "Chua co nginx.service."
    if systemctl is-active --quiet nginx.service; then
        NGINX_WAS_ACTIVE=true
    fi
fi

for target in "$SSL_DIR/server.crt" "$SSL_DIR/server.key" "$CONF_FILE" "$UPSTREAM_FILE"; do
    [[ ! -L "$target" ]] || fail "Tu choi ghi de symbolic link: $target"
    [[ ! -e "$target" || -f "$target" ]] || fail "Duong dan khong phai file thuong: $target"
done

WORK_DIR="$(mktemp -d /tmp/sv2-setup.XXXXXX)"
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
install -d -o root -g root -m 0700 /var/backups/linux-proxy-firewall
BACKUP_DIR="$(mktemp -d /var/backups/linux-proxy-firewall/sv2.XXXXXX)"

echo "=== [1/6] Dung hai trang BLUE / RED ==="
install -d -o root -g root -m 0755 /var/www/backend1 /var/www/backend2
for backend in 1 2; do
    if [[ $backend -eq 1 ]]; then
        color=BLUE; background='#007bff'
    else
        color=RED; background='#dc3545'
    fi
    cat > "/var/www/backend$backend/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Backend $backend - $color</title></head>
<body style="background:$background;color:white;text-align:center;font-family:sans-serif;padding-top:100px">
    <h1>SERVER BACKEND 0$backend - $color</h1>
    <p>HTTPS gateway demo - internal backend</p>
</body>
</html>
HTML
    chown root:root "/var/www/backend$backend/index.html"
    chmod 0644 "/var/www/backend$backend/index.html"
done

echo "=== [2/6] Cai dat va restart backend services ==="
for backend in 1 2; do
    port=$((8080 + backend))
    cat > "$WORK_DIR/backend$backend.service" <<UNIT
[Unit]
Description=SV2 Backend $backend - Python HTTP Server
After=network.target

[Service]
Type=simple
User=nobody
WorkingDirectory=/var/www/backend$backend
ExecStart=/usr/bin/python3 -m http.server $port --bind 127.0.0.1 --directory /var/www/backend$backend
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
UNIT
    install -o root -g root -m 0644 "$WORK_DIR/backend$backend.service" "/etc/systemd/system/backend$backend.service"
done
systemctl daemon-reload
systemctl enable backend1.service backend2.service
systemctl restart backend1.service backend2.service

echo "=== [3/6] Kiem tra backend va socket loopback ==="
for backend in 1 2; do
    port=$((8080 + backend))
    marker="SERVER BACKEND 0$backend"
    ready=false
    for attempt in {1..10}; do
        if response="$(curl --noproxy '*' -fsS --connect-timeout 1 --max-time 2 "http://127.0.0.1:$port")" \
            && [[ "$response" == *"$marker"* ]]; then
            ready=true
            break
        fi
        sleep 1
    done
    [[ "$ready" == true ]] || fail "Backend $backend khong dap ung sau 10 lan thu."
    systemctl is-active --quiet "backend$backend.service" || fail "Backend $backend khong active."
    listeners="$(ss -H -ltn "sport = :$port")"
    [[ -n "$listeners" ]] || fail "Khong tim thay socket $port."
    while read -r state receive_queue send_queue local_address peer remainder; do
        [[ "$local_address" == "127.0.0.1:$port" ]] || fail "Backend dang lo ra ngoai: $local_address"
    done <<< "$listeners"
    echo "PASS: backend$backend hoat dong dung, chi listen 127.0.0.1:$port"
done

echo "=== [4/6] Kiem tra / tao certificate tu ky ==="
install -d -o root -g root -m 0755 "$SSL_DIR"
san='DNS:localhost,IP:127.0.0.1'
[[ -z "$SERVER_IP" || "$SERVER_IP" == 127.0.0.1 ]] || san+=",IP:$SERVER_IP"

certificate_ok() {
    local cert="$1" key="$2"
    openssl x509 -in "$cert" -noout -checkend 86400 > /dev/null 2>&1 || return 1
    openssl verify -CAfile "$cert" -verify_hostname localhost "$cert" > /dev/null 2>&1 || return 1
    openssl verify -CAfile "$cert" -verify_ip 127.0.0.1 "$cert" > /dev/null 2>&1 || return 1
    if [[ -n "$SERVER_IP" ]]; then
        openssl verify -CAfile "$cert" -verify_ip "$SERVER_IP" "$cert" > /dev/null 2>&1 || return 1
    fi
    local c_pub k_pub
    c_pub="$(openssl x509 -in "$cert" -pubkey -noout 2>/dev/null)" || return 1
    k_pub="$(openssl pkey -in "$key" -passin pass: -pubout 2>/dev/null)" || return 1
    [[ "$c_pub" == "$k_pub" ]]
}

if [[ "$RENEW_CERT" == false && -f "$SSL_DIR/server.crt" && -f "$SSL_DIR/server.key" ]] && certificate_ok "$SSL_DIR/server.crt" "$SSL_DIR/server.key"; then
    echo "Giu certificate/key cu: hop le va dung SAN."
else
    for target in "$SSL_DIR/server.crt" "$SSL_DIR/server.key"; do
        [[ ! -f "$target" ]] || cp -p -- "$target" "$BACKUP_DIR/"
    done
    openssl req -x509 -nodes -sha256 -days 365 -newkey rsa:2048 \
        -keyout "$WORK_DIR/server.key" -out "$WORK_DIR/server.crt" \
        -subj '/C=VN/O=VKU-Lab/OU=SV2/CN=localhost' -addext "subjectAltName=$san"
    certificate_ok "$WORK_DIR/server.crt" "$WORK_DIR/server.key" || fail "Certificate moi khong hop le."
    install -o root -g root -m 0600 "$WORK_DIR/server.key" "$SSL_DIR/server.key"
    install -o root -g root -m 0644 "$WORK_DIR/server.crt" "$SSL_DIR/server.crt"
fi
chown root:root "$SSL_DIR/server.crt" "$SSL_DIR/server.key"
chmod 0600 "$SSL_DIR/server.key"
chmod 0644 "$SSL_DIR/server.crt"

if [[ "$PREPARE_ONLY" == true ]]; then
    echo "PASS: Backend + certificate san sang (--prepare-only)."
    exit 0
fi

echo "=== [5/6] Tao upstream rieng va vhost HTTP/HTTPS ==="
install -d -o root -g root -m 0755 /etc/nginx/conf.d /etc/nginx/sv2
cat > "$WORK_DIR/upstream.conf" <<'UPSTREAM'
upstream backend_cluster {
    server 127.0.0.1:8081 max_fails=1 fail_timeout=10s;
    server 127.0.0.1:8082 max_fails=1 fail_timeout=10s;
}
UPSTREAM

cat > "$WORK_DIR/loadbalancer.conf" <<NGINX_CONF
include $UPSTREAM_FILE;
limit_req_zone \$binary_remote_addr zone=sv2_per_ip:10m rate=5r/s;

server {
    listen 80;
    server_name localhost 127.0.0.1 ${SERVER_IP:-_};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name localhost 127.0.0.1 ${SERVER_IP:-_};
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
        proxy_next_upstream error timeout;
        proxy_next_upstream_tries 2;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Connection "";
        add_header Cache-Control "no-store" always;
    }
}
NGINX_CONF

for target in "$CONF_FILE" "$UPSTREAM_FILE"; do
    [[ ! -f "$target" ]] || cp -p -- "$target" "$BACKUP_DIR/"
done
CONFIG_INSTALLED=true
install -o root -g root -m 0644 "$WORK_DIR/upstream.conf" "$UPSTREAM_FILE"
install -o root -g root -m 0644 "$WORK_DIR/loadbalancer.conf" "$CONF_FILE"

echo "=== [6/6] Kiem tra NGINX, redirect, TLS va can bang tai ==="
"$NGINX_BIN" -t || fail "nginx -t that bai; he thong se rollback."
NGINX_CHANGED=true
if [[ "$NGINX_WAS_ACTIVE" == true ]]; then
    systemctl reload nginx.service
else
    systemctl restart nginx.service
fi

ready=false
for attempt in {1..10}; do
    if redirect="$(curl --noproxy '*' -sS --max-time 5 -o /dev/null \
        -w '%{http_code} %{redirect_url}' 'http://127.0.0.1/?sv2=1')" \
        && [[ "$redirect" == '301 https://127.0.0.1/?sv2=1' ]] \
        && curl --noproxy '*' --cacert "$SSL_DIR/server.crt" -fsS --max-time 5 \
            https://127.0.0.1/ > /dev/null; then
        ready=true
        break
    fi
    sleep 1
done
[[ "$ready" == true ]] || fail "HTTP redirect / HTTPS chua san sang."

seen_blue=false; seen_red=false
for attempt in {1..12}; do
    response="$(curl --noproxy '*' --cacert "$SSL_DIR/server.crt" -fsS \
        --connect-timeout 2 --max-time 5 'https://127.0.0.1/')"
    if [[ "$response" == *'SERVER BACKEND 01 - BLUE'* ]]; then
        seen_blue=true
    elif [[ "$response" == *'SERVER BACKEND 02 - RED'* ]]; then
        seen_red=true
    fi
    sleep 0.2
done
[[ "$seen_blue" == true && "$seen_red" == true ]] || fail "Chua thay du ca BLUE va RED qua HTTPS."
systemctl enable nginx.service

echo "PASS: HTTP 301, HTTPS xac minh certificate (khong can -k), ca BLUE va RED."
echo "=== [SV2] HOÀN TẤT DỰNG CỤM BACKENDS VÀ BẢO MẬT HTTPS ==="
