#!/bin/bash
clear
echo "=================================================="
echo "          SYSTEM SECURITY & LOG REPORT            "
echo "=================================================="

echo -e "\n[1] Top 5 IP truy cập hệ thống nhiều nhất:"
if [ -f /var/log/nginx/access.log ]; then
    awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head -n 5
else
    echo "Chưa có log truy cập Nginx."
fi

echo -e "\n[2] Số lượt gói tin bị Tường lửa UFW chặn (BLOCK):"
if [ -f /var/log/ufw.log ]; then
    grep -c "UFW BLOCK" /var/log/ufw.log || true
elif [ -f /var/log/syslog ]; then
    grep -c "UFW BLOCK" /var/log/syslog || true
else
    echo "0 (Chưa có log hoặc không phát hiện vi phạm)"
fi

echo -e "\n[3] Trạng thái hoạt động các tiến trình cốt lõi:"
for service in nginx backend1 backend2 ufw; do
    status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
    echo " - Dịch vụ $service: $status"
done

echo "=================================================="
