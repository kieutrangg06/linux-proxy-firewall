# SV2 DEMO - Backend Blue Red và HTTPS

## 1. Phần SV2 bàn giao

File chính: `02_setup_backends_and_ssl.sh`.

Sau khi hoàn thành, hệ thống phải có:

- Backend BLUE tại `127.0.0.1:8081`.
- Backend RED tại `127.0.0.1:8082`.
- Hai dịch vụ `backend1.service` và `backend2.service` tự khởi động.
- Certificate tự ký có SAN cho `localhost`, `127.0.0.1` và IP máy ảo dùng demo.
- HTTP cổng 80 trả `301` sang HTTPS cổng 443.
- HTTPS proxy đến cả BLUE và RED, giới hạn `5 request/giây`, `burst=10`.
- Backup dưới `/var/backups/linux-proxy-firewall/` trước khi thay certificate hoặc cấu hình NGINX.

Script không cài package, không build NGINX và không sửa UFW.

## 2. Bạn có thể làm ngay, không cần chờ SV1

Chạy trên Ubuntu VM, không chạy trực tiếp trong PowerShell Windows.

```bash
cd ~/linux-proxy-firewall

# Công cụ thuộc phần SV2. Không cài nginx từ apt trên máy tích hợp của nhóm.
sudo apt update
sudo apt install -y python3 curl openssl iproute2

# Chọn IP mà máy client sẽ dùng để mở web.
VM_IP=$(hostname -I | awk '{print $1}')
echo "$VM_IP"

# Lần đầu chuyển từ bản Antigravity cũ: tạo lại cert để có SAN đúng.
sudo bash 02_setup_backends_and_ssl.sh \
  --prepare-only \
  --server-ip "$VM_IP" \
  --renew-cert
```

`--prepare-only` chỉ hoàn thành backend và certificate. Nó không cần NGINX của SV1 và không thay đổi service/cấu hình NGINX.

Nếu máy có nhiều card mạng, `hostname -I` có thể trả nhiều IP. Hãy chọn IP mà client truy cập được và đặt lại `VM_IP` nếu cần. NAT mặc định của VirtualBox không tự cho máy host truy cập IP guest; dùng Host-only/Bridged phù hợp hoặc thống nhất port forwarding với nhóm.

Các lần chạy lại sau đó không cần `--renew-cert`:

```bash
sudo bash 02_setup_backends_and_ssl.sh --prepare-only --server-ip "$VM_IP"
```

## 3. Tự kiểm tra phần độc lập

```bash
systemctl is-active backend1 backend2
curl --noproxy '*' http://127.0.0.1:8081 | grep 'SERVER BACKEND 01 - BLUE'
curl --noproxy '*' http://127.0.0.1:8082 | grep 'SERVER BACKEND 02 - RED'
sudo ss -lnt 'sport = :8081 or sport = :8082'
```

Kết quả đúng:

- Hai service đều trả `active`.
- Hai lệnh `curl` tìm thấy đúng BLUE và RED.
- `ss` chỉ hiện `127.0.0.1:8081` và `127.0.0.1:8082`, không có `0.0.0.0` hoặc IP LAN.

Kiểm tra certificate:

```bash
openssl verify \
  -CAfile /etc/nginx/ssl/server.crt \
  -verify_hostname localhost \
  /etc/nginx/ssl/server.crt

openssl verify \
  -CAfile /etc/nginx/ssl/server.crt \
  -verify_ip "$VM_IP" \
  /etc/nginx/ssl/server.crt

openssl x509 -in /etc/nginx/ssl/server.crt \
  -noout -dates -ext subjectAltName
```

Hai lệnh `verify` phải trả `OK`. SAN phải có IP máy ảo dùng demo.

## 4. Hoàn tất tích hợp sau khi SV1 bàn giao NGINX

### Muốn thử cả HTTPS ngay mà chưa có SV1

Chỉ thực hiện trên **VM thực hành riêng chưa cài NGINX custom**. Không dùng lệnh này trên VM tích hợp của nhóm, tránh ghi đè service/cấu hình NGINX do SV1 quản lý.

```bash
sudo apt install -y nginx
sudo env NGINX_BIN=/usr/sbin/nginx \
  bash 02_setup_backends_and_ssl.sh --server-ip "$VM_IP"
```

Đây là NGINX đóng gói của Ubuntu để tự diễn tập phần SV2: vẫn test được redirect, TLS, cân bằng tải và giới hạn request. Header `Server` chưa phải `Custom-SecureGateway/1.0` vì sửa mã nguồn nhận diện là phần SV1. Khi chạy lại trên VM riêng này, tiếp tục truyền `NGINX_BIN=/usr/sbin/nginx`.

### Khi ghép vào máy của nhóm

SV1 phải bàn giao đủ:

- Binary `/usr/local/bin/nginx`.
- Build option `--with-http_ssl_module`.
- `nginx.service`.
- `nginx.conf` có `http { include /etc/nginx/conf.d/*.conf; }`.

Sau đó chạy:

```bash
VM_IP=$(hostname -I | awk '{print $1}')
sudo bash 02_setup_backends_and_ssl.sh --server-ip "$VM_IP"
```

Script sẽ tự chạy `nginx -t`, reload/start NGINX và kiểm tra:

- HTTP trả 301.
- HTTPS xác minh được bằng certificate, không dùng `-k` trong self-test.
- Qua HTTPS đã thấy cả BLUE và RED.
- Nếu cấu hình hoặc reload lỗi, script khôi phục hai file NGINX cũ.

## 5. Kiểm tra HTTPS để demo

```bash
curl --noproxy '*' -I http://127.0.0.1/
curl --noproxy '*' --cacert /etc/nginx/ssl/server.crt https://127.0.0.1/

for i in {1..8}; do
  curl --noproxy '*' --cacert /etc/nginx/ssl/server.crt -s https://127.0.0.1/ \
    | grep -oE 'BLUE|RED'
  sleep 0.3
done
```

Kết quả đúng:

- HTTP có `301 Moved Permanently` và `Location: https://...`.
- Tám request có xuất hiện cả `BLUE` và `RED`. Không cần cam kết tuyệt đối chuỗi BLUE-RED-BLUE-RED nếu có retry hoặc backend lỗi.

Kiểm tra rate limiting:

```bash
seq 1 30 | xargs -P30 -I{} \
  curl --noproxy '*' --cacert /etc/nginx/ssl/server.crt \
  -s -o /dev/null -w '%{http_code}\n' https://127.0.0.1/
```

Khi gửi đồng thời đủ nhanh, sẽ có request nhận `503` ngoài các request `200`.

## 6. Hợp đồng tích hợp với các thành viên

### Cần từ SV1

- Build NGINX thành công và sửa lỗi `sed` với chuỗi `Custom-SecureGateway/1.0`.
- Không xóa include `/etc/nginx/conf.d/*.conf`.
- Không định nghĩa trùng `upstream backend_cluster`.

### Cần từ SV3

- Cho phép inbound `80/tcp` và `443/tcp`.
- Giữ inbound `8081/tcp` và `8082/tcp` bị chặn.
- Không reset UFW hoặc bật UFW từ xa trước khi chắc chắn SSH vẫn được phép.

### Cần từ SV4

- Chỉ thay nội dung `/etc/nginx/sv2/upstream.conf` khi chọn BLUE, RED, Round Robin hoặc IP Hash.
- Luôn chạy `nginx -t` trước khi reload.
- Không ghi đè `/etc/nginx/conf.d/loadbalancer.conf`, vì file này chứa HTTP redirect, HTTPS, certificate và rate limit của SV2.

### Không chạy các file cũ sau SV2

- `setup_backends.sh` hiện là phiên bản HTTP cũ.
- `manage_proxy.sh` hiện là phiên bản ghi đè toàn bộ vhost HTTP cũ.

Chỉ chạy lại hai file trên sau khi người phụ trách cập nhật chúng theo hợp đồng tích hợp.

## 7. Kiểm tra từ máy client

Sau khi SV3 mở cổng 80 và 443:

```bash
# Trên client, đặt biến này thành IP thực tế của máy ảo.
VM_IP=192.168.56.10
curl -I "http://$VM_IP/"

# Nếu đã chép server.crt sang client:
curl --cacert ./server.crt "https://$VM_IP/"
```

Trình duyệt vẫn cảnh báo vì certificate tự ký không thuộc CA tin cậy. SAN đúng IP chỉ giải quyết lỗi hostname/IP không khớp; khi demo trình duyệt cần chấp nhận certificate tự ký thủ công.

## 8. Kịch bản nói 30 giây

> Phần em phụ trách gồm hai backend nội bộ BLUE và RED, chỉ bind vào loopback nên máy ngoài không thể truy cập trực tiếp. Em tạo certificate tự ký có SAN cho localhost và IP máy ảo. NGINX nhận HTTP cổng 80 rồi chuyển sang HTTPS 443, kết thúc TLS tại reverse proxy và phân phối request đến hai backend. Phần của em phối hợp với NGINX do SV1 build, rule cổng 80 và 443 của SV3, còn menu SV4 chỉ được thay file upstream riêng để không làm mất HTTPS.

## 9. Chẩn đoán nhanh

```bash
sudo systemctl --no-pager --full status backend1 backend2 nginx
sudo journalctl --no-pager -u backend1 -u backend2 -u nginx -n 50
sudo /usr/local/bin/nginx -t
sudo ss -lntp | grep -E ':80|:443|:8081|:8082'
```

Mỗi lần chạy script, đường dẫn backup được in ở cuối. Không xóa backup cho đến khi demo hoàn tất.
