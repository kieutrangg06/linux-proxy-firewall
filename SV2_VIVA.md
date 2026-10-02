# SV2 VIVA - Hiểu backend và HTTPS để vấn đáp

## 1. Em làm phần nào trong dự án?

Em dựng hai backend BLUE/RED, tạo certificate tự ký và cấu hình HTTP chuyển sang HTTPS. NGINX nhận HTTPS, kết thúc TLS rồi chuyển request đến backend. Em không build NGINX và không cấu hình UFW thay các bạn khác.

## 2. HTTPS khác HTTP thế nào?

HTTPS là HTTP chạy qua TLS. TLS cung cấp mã hóa, kiểm tra tính toàn vẹn và cơ chế xác thực server. Xác thực chỉ có ý nghĩa khi client kiểm tra certificate đúng cách và tin khóa/chứng chỉ được cung cấp. Cổng mặc định HTTP là 80, HTTPS là 443.

## 3. SSL và TLS có phải một không?

SSL là thế hệ giao thức cũ; TLS là giao thức kế nhiệm. Tên như `ssl_certificate` trong NGINX vẫn dùng chữ SSL, nhưng cấu hình của em cho phép TLS 1.2 và TLS 1.3, không bật giao thức SSL cũ.

## 4. Certificate là gì?

Certificate X.509 chứa public key, thông tin chủ thể, thời hạn, các extension như SAN và chữ ký. Client kiểm tra chuỗi tin cậy, thời hạn và hostname/IP để xác minh server. Trong lab, certificate tự ký chưa được trình duyệt tin mặc định.

## 5. SAN là gì, tại sao không chỉ dùng CN localhost?

SAN là Subject Alternative Name, liệt kê tên DNS và địa chỉ IP mà certificate đại diện. Script luôn có `DNS:localhost` và `IP:127.0.0.1`; `--server-ip` thêm IP máy ảo. Nếu client mở web bằng IP máy ảo thì certificate cần SAN IP tương ứng. SAN đúng không tự làm certificate tự ký được trình duyệt tin cậy.

## 6. Private key làm gì?

Private key phải được giữ bí mật. Với TLS 1.3, server dùng nó để ký/xác thực handshake, chứng minh quyền sở hữu khóa gắn với certificate. Dữ liệu HTTP sử dụng khóa phiên đối xứng, không phải toàn bộ nội dung được mã hóa trực tiếp bằng RSA public key rồi giải mã bằng private key. File `server.key` thuộc root và có quyền `600`.

## 7. Vì sao dùng self-signed certificate?

Đề yêu cầu certificate tự ký và đây là môi trường lab. Cách này giúp tự tạo certificate và học cấu hình TLS mà không phụ thuộc một CA công cộng. Không nên giải thích rằng mọi server không công khai trên Internet đều không thể dùng certificate CA; cách xác minh còn phụ thuộc loại chứng chỉ và phương thức xác minh quyền sở hữu.

## 8. Vì sao trình duyệt cảnh báo?

Vì chưa có quan hệ tin cậy với certificate tự ký. Nếu SAN sai IP hoặc chứng chỉ hết hạn thì đó là lỗi bổ sung, không chỉ lỗi CA. Có thể chấp nhận certificate thủ công cho lab. Chỉ chép `server.crt` cho client, không chép `server.key`.

## 9. curl -k và --cacert khác nhau thế nào?

`-k` bỏ kiểm tra certificate nên có thể che cả lỗi SAN, lỗi thời hạn và lỗi tin cậy. `--cacert server.crt` đặt certificate lab làm nguồn tin cậy cho lần gọi đó nhưng vẫn kiểm tra hostname/IP. Script tự kiểm thử bằng `--cacert`, không dùng `-k` để báo thành công.

## 10. Vì sao backend chỉ bind 127.0.0.1?

Để backend chỉ lắng nghe trên loopback của máy, không nhận kết nối trực tiếp từ máy bên ngoài. Các tiến trình khác trên cùng máy vẫn có thể gọi backend; không phải chỉ riêng NGINX có quyền truy cập. Chỉ bind loopback và dùng thêm UFW là hai lớp bảo vệ khác nhau.

## 11. Reverse proxy làm gì?

Nó đứng trước backend, nhận request của client rồi chuyển tiếp đến backend. Client truy cập địa chỉ gateway thay vì cổng backend. Trong bài này NGINX vừa reverse proxy, vừa thực hiện TLS termination, cân bằng tải và giới hạn request.

## 12. Cân bằng tải Round Robin là gì?

Là phân phối request luân phiên theo trọng số giữa các backend sẵn sàng. Hai backend của em có trọng số bằng nhau. `zone backend_cluster 64k;` chia sẻ trạng thái upstream giữa các worker. Khi kiểm tra, em chứng minh xuất hiện cả BLUE và RED; không khẳng định mọi lần F5 đều đổi màu đúng thứ tự, vì browser tạo thêm request và backend có thể lỗi/retry.

## 13. SSL termination là gì?

Kết nối TLS từ client kết thúc tại NGINX. NGINX xử lý nội dung HTTP rồi tạo kết nối HTTP riêng đến backend.

```text
Client -- HTTPS --> NGINX -- HTTP qua loopback --> BLUE hoặc RED
```

## 14. Vì sao phía backend dùng HTTP?

Trong lab, backend nằm cùng máy và chỉ dùng loopback nên không truyền plaintext qua LAN. Đây là lựa chọn phù hợp với phạm vi bài. Không nên kết luận mọi mạng nội bộ đều an toàn hoặc TLS nội bộ luôn vô ích; hệ thống thực tế có thể dùng TLS/mTLS đến backend tùy mô hình đe dọa.

## 15. Một backend dừng thì sao?

NGINX phát hiện lỗi thụ động khi gửi request. Cấu hình có `max_fails=1 fail_timeout=10s` và thử upstream khác khi lỗi kết nối/timeout. Với GET trong demo, backend còn lại có thể tiếp tục phục vụ. Đây không phải cam kết mọi loại request sẽ không bao giờ lỗi.

Để minh họa, dừng backend1, kiểm tra nhiều request mới thấy RED, rồi **khởi động lại backend1**. Chờ khoảng 10 giây hoặc hơn trước khi kiểm tra lại cả hai màu. `systemctl stop` là dừng có chủ đích nên `Restart=on-failure` không tự bật lại dịch vụ.

## 16. Lệnh tạo certificate có ý nghĩa gì?

- `openssl req -x509`: tạo certificate tự ký thay vì chỉ tạo CSR.
- `-newkey rsa:2048`: tạo cặp khóa RSA mới.
- `-nodes`: không đặt passphrase cho private key để dịch vụ tự khởi động; vì vậy cần bảo vệ file key.
- `-sha256`: dùng SHA-256 cho chữ ký certificate.
- `-days 365`: hiệu lực một năm kể từ khi tạo.
- `-subj`: khai báo subject, không thay thế SAN.
- `-addext subjectAltName=...`: thêm các tên/IP mà certificate đại diện.

## 17. return 301 https://$host$request_uri làm gì?

Trả redirect vĩnh viễn sang HTTPS, giữ host, đường dẫn và query string. Request HTTP đầu tiên vẫn là plaintext; redirect không mã hóa ngược request đó. Script chưa triển khai HSTS. Với bài demo GET, 301 là phù hợp; ứng dụng có POST cần xem xét hành vi đổi method khi dùng redirect.

## 18. proxy_pass http://backend_cluster làm gì?

NGINX chọn một server trong upstream `backend_cluster` và chuyển request đến đó. Đây là HTTP phía nội bộ; kết nối client vẫn là HTTPS. `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto` truyền thông tin kết nối gốc cho backend. Backend thật chỉ nên tin các header này khi chúng đến từ proxy tin cậy.

## 19. systemd có vai trò gì?

Ubuntu dùng systemd quản lý dịch vụ. `enable` đăng ký khởi động cùng máy; `restart` áp dụng lệnh chạy mới cho tiến trình. `daemon-reload` chỉ nạp lại unit, không tự thay tiến trình đang chạy. `Restart=on-failure` khởi động lại khi dịch vụ lỗi; `journalctl` giúp xem log.

## 20. Rate limiting ở đâu và có chống mọi DDoS không?

`limit_req_zone` và `limit_req` nằm trong vhost do script SV2 sinh, được include bên trong khối `http` của NGINX. Zone `sv2_per_ip` giới hạn theo IP ở mức `5r/s`, burst 10, phản hồi 503 khi vượt mức. Nó hạn chế request HTTP đến ứng dụng, không phải giải pháp chống mọi DDoS hoặc chống nghẽn băng thông. Không cần SV1 khai báo lại zone này trong `nginx.conf`.

## 21. Vì sao chạy script nhiều lần không tạo lại key mỗi lần?

Script giữ certificate/key còn hợp lệ, khớp nhau, đúng SAN và còn hạn hơn một ngày. Nếu thiếu hoặc sai, nó báo lỗi và yêu cầu `--renew-cert` thay vì báo thành công giả. Khi chủ động tạo lại certificate, bản cũ được backup; client đã tin certificate cũ cần nhận bản mới.

## 22. Em cần gì từ các thành viên khác?

- SV1: NGINX có module TLS, service `nginx.service`, include `conf.d/*.conf` trong khối `http`.
- SV3: mở 80/443 và giữ backend bị chặn với client bên ngoài; không mở 8081/8082 để sửa lỗi kết nối HTTPS.
- SV4: chỉ cập nhật `/etc/nginx/sv2/upstream.conf`, chạy `nginx -t` rồi reload. Không ghi đè vhost HTTPS.
- Khi chưa có SV1: chạy `--prepare-only`; có thể diễn tập cả HTTPS với NGINX Ubuntu trên VM riêng, không cài chồng lên NGINX custom của nhóm.

## 23. Vì sao localhost chạy được nhưng máy khác không vào được?

Kiểm tra IP/network mode của máy ảo, cổng 80/443 có listener hay không, UFW có cho phép hay không và SAN có khớp IP hay không. Loopback test không chứng minh UFW hoặc mạng từ client đã đúng. Chỉ xác nhận tích hợp hoàn tất sau khi kiểm thử từ client thực tế.

## 24. Script tự kiểm tra những gì?

Nội dung từng backend, service active, socket chỉ bind loopback, certificate còn hạn và đúng SAN/key, cú pháp NGINX, HTTP 301, HTTPS xác minh được và có cả hai backend. Khi lỗi cấu hình/reload hoặc kiểm tra gateway thất bại, nó trả lỗi và khôi phục hai file cấu hình NGINX. Các backend đã tạo và certificate hợp lệ vẫn được giữ để kiểm tra, không gọi đây là rollback toàn bộ máy.
