#!/bin/bash

# 更新系統
echo "更新系統..."
apt update -y

# 安裝 iptables 和 ipset
echo "安裝 iptables 和 ipset..."
apt install -y iptables ipset curl

# 配置 sysctl.conf
echo "配置 sysctl.conf..."
cat >> /etc/sysctl.conf <<EOL
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 1
net.ipv4.conf.default.secure_redirects = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_max_orphans = 32768
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOL

# 重新載入 sysctl 配置
sysctl -p

# 創建 ipset 列表
echo "創建 ipset 列表..."

# 創建 ipset
ipset create mcstormip hash:net
ipset create cfip hash:net

# 下載 IP 列表並匯入到 ipset
echo "下載 IP 列表..."
curl -sSL https://raw.githubusercontent.com/blue5125/mcblueice-sh/refs/heads/main/ipset/mcstorm-ip.txt -o /tmp/mcstorm-ip.txt
curl -sSL https://raw.githubusercontent.com/blue5125/mcblueice-sh/refs/heads/main/ipset/cloudflare-ip.txt -o /tmp/cloudflare-ip.txt

# 匯入到 ipset
for i in $(cat /tmp/mcstorm-ip.txt ); do ipset -A mcstormip $i; done
for i in $(cat /tmp/cloudflare-ip.txt ); do ipset -A cfip $i; done


# 刪除臨時檔案
rm /tmp/mcstorm-ip.txt
rm /tmp/cloudflare-ip.txt

# 配置 iptables 規則
echo "配置 iptables..."

# 清除現有規則
iptables -F
iptables -X

# 創建自定義鏈
iptables -N port1
iptables -A port1 -p tcp -m multiport --dports 25565:25570 -j RETURN
iptables -A port1 -p udp --dport 19132 -j RETURN
iptables -A port1 -j DROP

iptables -N udp1
iptables -A udp1 -p udp -m limit --limit 10/s --limit-burst 20 -j ACCEPT
iptables -A udp1 -p udp -j DROP

iptables -N syn-flood1
iptables -A syn-flood1 -p tcp --syn -m recent --set --name syn_limit
iptables -A syn-flood1 -p tcp --syn -m recent --update --name syn_limit --seconds 60 --hitcount 20 -j DROP
iptables -A syn-flood1 -p tcp --syn -m recent --update --name syn_limit -j RETURN

iptables -N syn-flood2
iptables -A syn-flood2 -p tcp --syn -m limit --limit 20/s --limit-burst 40 -j ACCEPT
iptables -A syn-flood2 -p tcp --syn -j DROP

# 基本規則
iptables -A INPUT -m set --match-set mcstormip src -j DROP
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -m set --match-set cfip src -j ACCEPT
iptables -A INPUT -j port1
iptables -A INPUT -p udp -j udp1
iptables -A INPUT -p tcp --syn -j syn-flood1
iptables -A INPUT -p tcp --syn -j syn-flood2

# 默認規則
iptables -A INPUT -j DROP
iptables -A FORWARD -j DROP
iptables -P OUTPUT ACCEPT

# 儲存 iptables 規則
echo "儲存規則..."
ipset save > /etc/ipset.conf
iptables-save > /etc/iptables/rules.v4

echo "完成!"
