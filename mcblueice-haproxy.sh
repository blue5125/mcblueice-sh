#!/bin/bash

# 確保以 root 權限運行
if [ "$(id -u)" -ne 0 ]; then
    echo "請以 root 權限運行此腳本！"
    exit 1
fi

echo "更新系統軟體包列表..."
apt update -y

# 安裝 HAProxy
echo "安裝 HAProxy..."
apt install -y haproxy

# 設置 HAProxy 配置
echo "設定 HAProxy 配置..."
cat <<EOF > /etc/haproxy/haproxy.cfg
global
    maxconnrate 100
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # Default SSL material locations
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

    # SSL Config
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
    log global
    mode tcp
    option httplog
    option dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

listen minecraft
    bind *:25565-25570
    mode tcp
    server mainserver 8.8.8.8 send-proxy-v2
EOF

# 重啟 HAProxy 使配置生效
echo "重啟 HAProxy..."
systemctl restart haproxy

# 啟用 HAProxy 開機自啟
echo "啟用 HAProxy 開機自啟..."
systemctl enable haproxy

echo "HAProxy 安裝與配置完成！"

# 顯示 HAProxy 狀態
systemctl status haproxy --no-pager
