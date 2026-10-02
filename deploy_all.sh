#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "   BẮT ĐẦU TRIỂN KHAI TOÀN BỘ HỆ THỐNG PROXY & FIREWALL"
echo "=================================================================="

chmod +x 01_build_nginx.sh 02_setup_backends_and_ssl.sh 03_setup_firewall.sh manage_proxy.sh log_analyzer.sh

sudo ./01_build_nginx.sh
sudo ./02_setup_backends_and_ssl.sh
sudo ./03_setup_firewall.sh

echo
echo "=================================================================="
echo "   HỆ THỐNG ĐÃ TRIỂN KHAI XONG VÀ ĐẠT TRẠNG THÁI TỐI ƯU!"
echo "=================================================================="
