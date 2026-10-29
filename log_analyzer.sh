#!/bin/bash
# ==============================================================================
# ĐỒ ÁN: FIREWALL VÀ PROXY TRÊN UBUNTU
# FILE: log_analyzer.sh - PHỤ TRÁCH: SINH VIÊN 4 (LÊ THỊ KIỀU TRANG)
# CHỨC NĂNG: Phân tích nhật ký NGINX và UFW, trích xuất báo cáo an ninh tự động
# HỖ TRỢ: Ubuntu Server/Desktop 20.04, 22.04, 24.04 LTS (kể cả bản Minimal)
# ==============================================================================

clear
echo "=================================================="
echo "          SYSTEM SECURITY & LOG REPORT            "
echo "=================================================="

# [1] Thống kê Top 5 IP truy cập NGINX
echo -e "\n[1] Top 5 IP truy cập hệ thống nhiều nhất:"
ACCESS_LOG="/var/log/nginx/access.log"
if [ -f "$ACCESS_LOG" ]; then
    awk '{print $1}' "$ACCESS_LOG" | sort | uniq -c | sort -nr | head -n 5
else
    echo "Chưa có log truy cập Nginx tại $ACCESS_LOG."
fi

# [2] Thống kê số lượt gói tin bị Tường lửa UFW chặn (BLOCK)
echo -e "\n[2] Số lượt gói tin bị Tường lửa UFW chặn (BLOCK):"
BLOCK_COUNT=0

# Ưu tiên 1: Đọc từ file log riêng của UFW nếu hệ thống có rsyslog
if [ -f /var/log/ufw.log ]; then
    BLOCK_COUNT=$(grep -c "UFW BLOCK" /var/log/ufw.log 2>/dev/null || true)
# Ưu tiên 2: Đọc từ syslog chung của hệ thống
elif [ -f /var/log/syslog ]; then
    BLOCK_COUNT=$(grep -c "UFW BLOCK" /var/log/syslog 2>/dev/null || true)
fi

# Ưu tiên 3 (Dành riêng cho Ubuntu 22.04 / 24.04 Minimal):
# Đọc trực tiếp từ bộ đệm Kernel của systemd-journald
if [ -z "$BLOCK_COUNT" ] || [ "$BLOCK_COUNT" -eq 0 ]; then
    if command -v journalctl >/dev/null 2>&1; then
        # Thử đọc trực tiếp hoặc qua sudo nếu cần quyền đọc kernel log
        JOURNAL_COUNT=$( (journalctl -k --grep="UFW BLOCK" -q 2>/dev/null || sudo journalctl -k --grep="UFW BLOCK" -q 2>/dev/null) | grep -c "UFW BLOCK" || true )
        if [ -n "$JOURNAL_COUNT" ] && [ "$JOURNAL_COUNT" -gt 0 ]; then
            BLOCK_COUNT=$JOURNAL_COUNT
        fi
    fi
fi

if [ -n "$BLOCK_COUNT" ] && [ "$BLOCK_COUNT" -gt 0 ]; then
    echo "$BLOCK_COUNT"
else
    echo "0 (Chưa có log hoặc không phát hiện vi phạm)"
fi

# [3] Trạng thái hoạt động các tiến trình cốt lõi
echo -e "\n[3] Trạng thái hoạt động các tiến trình cốt lõi:"
for service in nginx backend1 backend2 ufw; do
    status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
    echo " - Dịch vụ $service: $status"
done

echo "=================================================="
