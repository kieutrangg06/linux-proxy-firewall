#!/bin/bash
set -euo pipefail
UPSTREAM_FILE="/etc/nginx/sv2/upstream.conf"

get_current_backends() {
    # Automatically extract the 2 backend nodes currently in upstream.conf
    SERVERS=($(grep -E '^[[:space:]]*server[[:space:]]+' "$UPSTREAM_FILE" | awk '{print $2}' | tr -d ';' || true))
    NODE1="${SERVERS[0]:-127.0.0.1:8081}"
    NODE2="${SERVERS[1]:-127.0.0.1:8082}"
}

apply_config() {
    sudo /usr/local/bin/nginx -t
    sudo systemctl reload nginx
    echo "=> Configuration updated successfully! (Zero-Downtime Reload)"
    sleep 2
}

show_menu() {
    clear
    get_current_backends
    echo "=================================================="
    echo "         AUTOMATION PROXY MANAGEMENT SCRIPT         "
    echo "=================================================="
    echo " Current Node 1: $NODE1"
    echo " Current Node 2: $NODE2"
    echo "--------------------------------------------------"
    echo "1. Round Robin Load Balancing (Enable Both Servers)"
    echo "2. Switch to Server 1 ONLY"
    echo "3. Switch to Server 2 ONLY"
    echo "4. Switch Algorithm to IP Hash (Session Persistence)"
    echo "5. Enter 3-Machine Cluster IPs (Switch to Distributed Mode)"
    echo "6. Switch to Local Cluster (127.0.0.1:8081/8082)"
    echo "7. Test NGINX Configuration (nginx -t)"
    echo "8. View upstream.conf Contents"
    echo "0. Exit"
    echo "=================================================="
    read -p "Select an option [0-8]: " choice
}

while true; do
    show_menu
    case "$choice" in
        1)
            sudo tee "$UPSTREAM_FILE" > /dev/null <<UPSTREAM
upstream backend_cluster {
    server $NODE1 max_fails=1 fail_timeout=10s;
    server $NODE2 max_fails=1 fail_timeout=10s;
}
UPSTREAM
            apply_config
            ;;
        2)
            sudo tee "$UPSTREAM_FILE" > /dev/null <<UPSTREAM
upstream backend_cluster {
    server $NODE1 max_fails=1 fail_timeout=10s;
    server $NODE2 down;
}
UPSTREAM
            apply_config
            ;;
        3)
            sudo tee "$UPSTREAM_FILE" > /dev/null <<UPSTREAM
upstream backend_cluster {
    server $NODE1 down;
    server $NODE2 max_fails=1 fail_timeout=10s;
}
UPSTREAM
            apply_config
            ;;
        4)
            sudo tee "$UPSTREAM_FILE" > /dev/null <<UPSTREAM
upstream backend_cluster {
    ip_hash;
    server $NODE1;
    server $NODE2;
}
UPSTREAM
            apply_config
            ;;
        5)
            echo "--- CONFIGURE 3-MACHINE DISTRIBUTED CLUSTER IPs ---"
            read -p "Enter Machine 2 IP (Backend 1 - BLUE): " IP2
            read -p "Enter Machine 3 IP (Backend 2 - RED): " IP3
            [[ "$IP2" =~ : ]] || IP2="${IP2}:80"
            [[ "$IP3" =~ : ]] || IP3="${IP3}:80"
            sudo tee "$UPSTREAM_FILE" > /dev/null <<UPSTREAM
upstream backend_cluster {
    server $IP2 max_fails=1 fail_timeout=10s;
    server $IP3 max_fails=1 fail_timeout=10s;
}
UPSTREAM
            apply_config
            ;;
        6)
            sudo systemctl restart backend1.service backend2.service 2>/dev/null || true
            sudo tee "$UPSTREAM_FILE" > /dev/null <<UPSTREAM
upstream backend_cluster {
    server 127.0.0.1:8081 max_fails=1 fail_timeout=10s;
    server 127.0.0.1:8082 max_fails=1 fail_timeout=10s;
}
UPSTREAM
            apply_config
            ;;
        7)
            sudo /usr/local/bin/nginx -t
            read -p "Press Enter to continue..."
            ;;
        8)
            echo "--- Contents of $UPSTREAM_FILE ---"
            cat "$UPSTREAM_FILE"
            echo "-----------------------------------"
            read -p "Press Enter to continue..."
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Invalid option!"; sleep 1
            ;;
    esac
done
