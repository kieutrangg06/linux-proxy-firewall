#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "   BẮT ĐẦU TRIỂN KHAI TOÀN BỘ HỆ THỐNG PROXY & FIREWALL"
echo "=================================================================="

[[ $EUID -eq 0 ]] || { echo "Vui lòng chạy bằng: sudo ./deploy_all.sh" >&2; exit 1; }

chmod +x 01_build_nginx.sh 02_setup_backends_and_ssl.sh 03_setup_firewall.sh manage_proxy.sh log_analyzer.sh

./01_build_nginx.sh
./02_setup_backends_and_ssl.sh
./03_setup_firewall.sh

echo
echo "=================================================================="
echo "   HỆ THỐNG ĐÃ TRIỂN KHAI XONG VÀ ĐẠT TRẠNG THÁI TỐI ƯU!"
echo "=================================================================="
