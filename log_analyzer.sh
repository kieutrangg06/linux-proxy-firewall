#!/bin/bash
# ==============================================================================
# ĐỒ ÁN: FIREWALL VÀ PROXY TRÊN UBUNTU
# FILE: log_analyzer.sh - PHỤ TRÁCH: SINH VIÊN 4 (LÊ THỊ KIỀU TRANG)
# ==============================================================================

clear
echo "=================================================="
echo "          SYSTEM SECURITY & LOG REPORT            "
echo "=================================================="

# Cảnh báo nếu không chạy bằng sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "[!] CẢNH BÁO: Bạn chưa chạy với quyền sudo. Một số log Kernel/UFW có thể bị hạn chế!"
    echo -e "    Khuyến nghị: sudo ./log_analyzer.sh\n"
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
        JOURNAL_COUNT=$( (journalctl -k --grep="UFW BLOCK" -q 2>/dev/null || sudo journalctl -k --grep="UFW BLOCK" -q 2>/dev/null) | grep -c "UFW BLOCK" || true )
        if [ -n "$JOURNAL_COUNT" ] && [ "$JOURNAL_COUNT" -gt 0 ]; then
            BLOCK_COUNT=$JOURNAL_COUNT
        fi
    fi
fi

if [ -n "$BLOCK_COUNT" ] && [ "$BLOCK_COUNT" -gt 0 ]; then
    echo " - Phát hiện: $BLOCK_COUNT lượt vi phạm đã bị tường lửa DROP/BLOCK."
else
    echo " - 0 (Chưa có vi phạm từ mạng ngoài). "
    echo "   * Mẹo test: Lấy điện thoại cùng Wi-Fi mở trình duyệt gõ: http://$(hostname -I | awk '{print $1}'):8081 để kích hoạt UFW BLOCK!"
fi

# [3] Trạng thái hoạt động các tiến trình cốt lõi
echo -e "\n[3] Trạng thái hoạt động các tiến trình cốt lõi:"
for service in nginx backend1 backend2 ufw; do
    status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
    if [ "$status" == "active" ]; then
        echo " - Dịch vụ $service: [ĐANG CHẠY] (active)"
    else
        echo " - Dịch vụ $service: [DỪNG] ($status)"
    fi
done

echo "=================================================="
