#!/bin/bash
set -euo pipefail

REPO_DIR="/root/my/MTProxy"
INSTALL_DIR="/opt/mtproxy"

cd "$REPO_DIR"

echo "=== Pulling latest changes ==="
git pull

echo "=== Building ==="
make clean
make
systemctl stop mtproxy.service

echo "=== Updating binary ==="
cp objs/bin/mtproto-proxy "$INSTALL_DIR/"

echo "=== Updating systemd units ==="
cp mtproxy.service /etc/systemd/system/
cp mtproxy-config-update.service /etc/systemd/system/
cp mtproxy-config-update.timer /etc/systemd/system/
systemctl daemon-reload

echo "=== Updating Telegram configs ==="
curl -sfo "$INSTALL_DIR/proxy-secret" https://core.telegram.org/getProxySecret
curl -sfo "$INSTALL_DIR/proxy-multi.conf" https://core.telegram.org/getProxyConfig

echo "=== Restarting service ==="
systemctl restart mtproxy.service

echo "=== Status ==="
systemctl status mtproxy.service --no-pager
SECRET=$(grep PROXY_SECRET /opt/mtproxy/env | cut -d= -f2)
IP=$(curl -s ifconfig.me)
echo "tg://proxy?server=${IP}&port=443&secret=${SECRET}"
echo "=== Done ==="
