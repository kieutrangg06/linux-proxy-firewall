#!/bin/bash
clear
echo "=================================================="
echo "          SYSTEM SECURITY & LOG REPORT            "
echo "=================================================="

if [ "$EUID" -ne 0 ]; then
    echo -e "[!] CẢNH BÁO: Khuyến nghị chạy với quyền sudo để đọc log UFW đầy đủ!\n"
fi

# [1] Thống kê Top 5 IP truy cập NGINX
echo -e "[1] Thống kê truy cập NGINX:"
ACCESS_LOG="/var/log/nginx/access.log"
if [ -f "$ACCESS_LOG" ]; then
    total_req=$(wc -l < "$ACCESS_LOG")
    echo " - Tổng số lượt request đã ghi nhận: $total_req"
    echo " - Top IP gửi request nhiều nhất:"
    awk '{print "     * IP: " $1}' "$ACCESS_LOG" | sort | uniq -c | sort -nr | head -n 5
else
    echo " - Chưa có log truy cập Nginx tại $ACCESS_LOG."
fi

# [2] Thống kê số lượt gói tin bị Tường lửa UFW chặn (BLOCK)
echo -e "\n[2] Số lượt gói tin bị Tường lửa UFW chặn (BLOCK):"
BLOCK_COUNT=0
if [ -f /var/log/ufw.log ]; then
    BLOCK_COUNT=$(grep -c "UFW BLOCK" /var/log/ufw.log 2>/dev/null || true)
elif [ -f /var/log/syslog ]; then
    BLOCK_COUNT=$(grep -c "UFW BLOCK" /var/log/syslog 2>/dev/null || true)
fi

if [ -z "$BLOCK_COUNT" ] || [ "$BLOCK_COUNT" -eq 0 ]; then
    if command -v journalctl >/dev/null 2>&1; then
        BLOCK_COUNT=$(journalctl -k --grep="UFW BLOCK" -q 2>/dev/null | grep -c "UFW BLOCK" || true)
    fi
fi

if [ -n "$BLOCK_COUNT" ] && [ "$BLOCK_COUNT" -gt 0 ]; then
    echo " - Phát hiện: $BLOCK_COUNT lượt vi phạm đã bị tường lửa DROP/BLOCK."
else
    echo " - 0 (Chưa phát hiện gói tin vi phạm)."
fi

# [3] Trạng thái các dịch vụ cốt lõi
echo -e "\n[3] Trạng thái hoạt động các tiến trình cốt lõi:"
for service in nginx ufw; do
    status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
    echo " - Dịch vụ $service: [$status]"
done

for backend in backend1 backend2; do
    if systemctl list-unit-files | grep -q "$backend"; then
        status=$(systemctl is-active "$backend" 2>/dev/null || echo "inactive")
        echo " - Dịch vụ $backend (Local Mode): [$status]"
    fi
done

echo "=================================================="
