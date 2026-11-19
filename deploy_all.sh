#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "   STARTING PROXY & FIREWALL SYSTEM DEPLOYMENT (MASTER DEPLOY)"
echo "=================================================================="

[[ $EUID -eq 0 ]] || { echo "Please run as root: sudo ./deploy_all.sh" >&2; exit 1; }

MODE="local"
BACKEND1=""
BACKEND2=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        --backend1) BACKEND1="$2"; shift 2 ;;
        --backend2) BACKEND2="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

chmod +x *.sh

echo "--> STEP 1: Building NGINX from C source..."
./01_build_nginx.sh

echo "--> STEP 2: Configuring SSL and Upstream Cluster..."
if [[ "$MODE" == "cluster" ]]; then
    if [[ -z "$BACKEND1" || -z "$BACKEND2" ]]; then
        echo "Error: Cluster mode requires --backend1 <IP> and --backend2 <IP>" >&2
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
echo "   SYSTEM DEPLOYMENT COMPLETED AND RUNNING OPTIMALLY!"
echo "   ACTIVE MODE: [ $MODE ]"
echo "=================================================================="
