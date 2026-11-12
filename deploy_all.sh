#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "   BẮT ĐẦU TRIỂN KHAI HỆ THỐNG PROXY & FIREWALL (MASTER DEPLOY)"
echo "=================================================================="

[[ $EUID -eq 0 ]] || { echo "Vui lòng chạy bằng: sudo ./deploy_all.sh" >&2; exit 1; }

MODE="local"
BACKEND1=""
BACKEND2=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        --backend1) BACKEND1="$2"; shift 2 ;;
        --backend2) BACKEND2="$2"; shift 2 ;;
        *) echo "Tham số không xác định: $1"; exit 1 ;;
    esac
done

chmod +x *.sh

echo "--> BƯỚC 1: Biên dịch NGINX từ mã C..."
./01_build_nginx.sh

echo "--> BƯỚC 2: Cấu hình SSL và Upstream Cluster..."
if [[ "$MODE" == "cluster" ]]; then
    if [[ -z "$BACKEND1" || -z "$BACKEND2" ]]; then
        echo "Lỗi: Chế độ cluster bắt buộc phải cung cấp --backend1 <IP> và --backend2 <IP>" >&2
        exit 1
    fi
    ./02_setup_backends_and_ssl.sh --mode cluster --backend1 "$BACKEND1" --backend2 "$BACKEND2"
    ./03_setup_firewall.sh --mode cluster
else
    ./02_setup_backends_and_ssl.sh --mode local
    ./03_setup_firewall.sh --mode local
fi

echo
echo "=================================================================="
echo "   HỆ THỐNG ĐÃ TRIỂN KHAI XONG VÀ ĐẠT TRẠNG THÁI TỐI ƯU!"
echo "   CHẾ ĐỘ HOẠT ĐỘNG: [ $MODE ]"
echo "=================================================================="
