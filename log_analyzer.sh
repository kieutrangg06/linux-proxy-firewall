#!/bin/bash
clear
echo "=================================================="
echo "          SYSTEM SECURITY & LOG REPORT            "
echo "=================================================="

if [ "$EUID" -ne 0 ]; then
    echo -e "[!] WARNING: Running with sudo is recommended to read full UFW logs!\n"
fi

# [1] Top 5 IPs accessing NGINX
echo -e "[1] NGINX Access Statistics:"
ACCESS_LOG="/var/log/nginx/access.log"
if [ -f "$ACCESS_LOG" ]; then
    total_req=$(wc -l < "$ACCESS_LOG")
    echo " - Total recorded requests: $total_req"
    echo " - Top IPs by request count:"
    awk '{print "     * IP: " $1}' "$ACCESS_LOG" | sort | uniq -c | sort -nr | head -n 5
else
    echo " - No NGINX access log found at $ACCESS_LOG."
fi

# [2] Count packets blocked by UFW Firewall (BLOCK)
echo -e "\n[2] Packets Blocked by UFW Firewall (BLOCK):"
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
    echo " - Detected: $BLOCK_COUNT blocked/dropped violation attempts."
else
    echo " - 0 (No blocked packets detected)."
fi

# [3] Core services status
echo -e "\n[3] Core Services Status:"
for service in nginx ufw; do
    status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
    echo " - Service $service: [$status]"
done

for backend in backend1 backend2; do
    if systemctl list-unit-files | grep -q "$backend"; then
        status=$(systemctl is-active "$backend" 2>/dev/null || echo "inactive")
        echo " - Service $backend (Local Mode): [$status]"
    fi
done

echo "=================================================="
