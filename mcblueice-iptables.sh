#!/bin/bash

# 確保以 root 權限運行
if [ "$(id -u)" -ne 0 ]; then
    echo "此腳本需要以 root 權限運行"
    exit 1
fi

echo "===================="
echo "系統安全與防火牆設定"
echo "===================="

# 檢查是否已經配置過 sysctl
SYSCTL_CONFIGURED=$(grep -c "net.ipv4.tcp_syncookies = 1" /etc/sysctl.conf)

if [ "$SYSCTL_CONFIGURED" -eq 0 ]; then
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
    sysctl -p
else
    echo "sysctl.conf 已經配置，跳過此步驟。"
fi

# 更新系統
echo "更新系統..."
apt update -y

# 安裝 iptables 和 ipset
echo "安裝 iptables 和 ipset..."
apt install -y iptables ipset curl

# 創建或重置 ipset 列表
echo "檢查 ipset 列表..."
for SET in mcstormip twip cfip; do
    if ipset list $SET &>/dev/null; then
        echo "清空 $SET 列表..."
        ipset flush $SET
    else
        echo "創建 $SET 列表..."
        ipset create $SET hash:net
    fi
done

# 下載 IP 列表並匯入到 ipset
echo "下載 IP 列表..."
curl -sSL https://raw.githubusercontent.com/blue5125/mcblueice-sh/refs/heads/main/ipset/mcstorm-ip.txt -o /tmp/mcstorm-ip.txt
curl -sSL https://raw.githubusercontent.com/blue5125/mcblueice-sh/refs/heads/main/ipset/taiwan-ip.txt -o /tmp/taiwan-ip.txt
curl -sSL https://raw.githubusercontent.com/blue5125/mcblueice-sh/refs/heads/main/ipset/cloudflare-ip.txt -o /tmp/cloudflare-ip.txt

# 匯入到 ipset
for i in $(cat /tmp/mcstorm-ip.txt); do ipset -A mcstormip $i; done
for i in $(cat /tmp/taiwan-ip.txt); do ipset -A twip $i; done
for i in $(cat /tmp/cloudflare-ip.txt); do ipset -A cfip $i; done

# 刪除臨時檔案
rm -f /tmp/mcstorm-ip.txt /tmp/taiwan-ip.txt /tmp/cloudflare-ip.txt

echo "是否要啟用台灣IP限制？(y/n)"
read -r ENABLE_TWIP

if [[ "$ENABLE_TWIP" =~ ^[Yy]$ ]]; then
    echo "已啟用台灣IP限制"
    echo "配置 iptables..."
    iptables -F
    iptables -X
    iptables -N ipset
    iptables -A ipset -m set --match-set mcstormip src -j DROP
    iptables -A ipset -m set --match-set twip src -j RETURN
    iptables -A ipset -j DROP

    iptables -N port1
    iptables -A port1 -p tcp -m multiport --dports 25565:25570 -j RETURN
    iptables -A port1 -p udp --dport 19132 -j RETURN
    iptables -A port1 -j DROP

    iptables -N udp1
    iptables -A udp1 -p udp -m limit --limit 30/s --limit-burst 60 -j ACCEPT
    iptables -A udp1 -p udp -j DROP

    iptables -N syn-flood1
    iptables -A syn-flood1 -p tcp --syn -m recent --set --name syn_limit
    iptables -A syn-flood1 -p tcp --syn -m recent --update --name syn_limit --seconds 30 --hitcount 20 -j DROP
    iptables -A syn-flood1 -p tcp --syn -m recent --update --name syn_limit -j RETURN

    iptables -N syn-flood2
    iptables -A syn-flood2 -p tcp --syn -m limit --limit 30/s --limit-burst 60 -j ACCEPT
    iptables -A syn-flood2 -p tcp --syn -j DROP

    # 基本規則
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -m set --match-set cfip src -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -j port1
    iptables -A INPUT -j ipset
    iptables -A INPUT -p udp -j udp1
    iptables -A INPUT -p tcp --syn -j syn-flood1
    iptables -A INPUT -p tcp --syn -j syn-flood2

    # 默認規則
    iptables -A INPUT -j DROP
    iptables -A FORWARD -j DROP
    iptables -P OUTPUT ACCEPT
else
    echo "已關閉台灣IP限制"
    echo "配置 iptables..."
    iptables -F
    iptables -X

    iptables -N port1
    iptables -A port1 -p tcp -m multiport --dports 25565:25570 -j RETURN
    iptables -A port1 -p udp --dport 19132 -j RETURN
    iptables -A port1 -j DROP

    iptables -N udp1
    iptables -A udp1 -p udp -m limit --limit 30/s --limit-burst 60 -j ACCEPT
    iptables -A udp1 -p udp -j DROP

    iptables -N syn-flood1
    iptables -A syn-flood1 -p tcp --syn -m recent --set --name syn_limit
    iptables -A syn-flood1 -p tcp --syn -m recent --update --name syn_limit --seconds 30 --hitcount 20 -j DROP
    iptables -A syn-flood1 -p tcp --syn -m recent --update --name syn_limit -j RETURN

    iptables -N syn-flood2
    iptables -A syn-flood2 -p tcp --syn -m limit --limit 30/s --limit-burst 60 -j ACCEPT
    iptables -A syn-flood2 -p tcp --syn -j DROP

    # 基本規則
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -m set --match-set cfip src -j ACCEPT
    iptables -A INPUT -m set --match-set mcstormip src -j DROP
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -j port1
    iptables -A INPUT -p udp -j udp1
    iptables -A INPUT -p tcp --syn -j syn-flood1
    iptables -A INPUT -p tcp --syn -j syn-flood2

    # 默認規則
    iptables -A INPUT -j DROP
    iptables -A FORWARD -j DROP
    iptables -P OUTPUT ACCEPT
fi

# 創建自定義鏈


# 儲存 iptables 規則
echo "儲存規則..."
mkdir -p /etc/iptables/
touch /etc/iptables/ipset.conf
touch /etc/iptables/iptables.v4
ipset save > /etc/iptables/ipset.conf
iptables-save > /etc/iptables/iptables.v4

echo "是否要讓這些規則在重啟後自動載入？(y/n)"
read -r ENABLE_PERSISTENCE

if [[ "$ENABLE_PERSISTENCE" =~ ^[Yy]$ ]]; then
    echo "設置開機時自動載入 ipset 和 iptables 規則..."
    
    # 安裝 `iptables-persistent` 套件
    apt install -y iptables-persistent

    # 創建系統服務
    cat > /etc/systemd/system/ipset.service <<EOL
[Unit]
Description=Restore ipset rules
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c "ipset restore < /etc/iptables/ipset.conf"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

    cat > /etc/systemd/system/iptables.service <<EOL
[Unit]
Description=Restore iptables rules
After=network.target ipset.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c "iptables-restore < /etc/iptables/iptables.v4"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

    # 啟用並啟動服務
    systemctl daemon-reload
    systemctl enable ipset.service
    systemctl enable iptables.service

    echo "開機自動載入已啟用！"
else
    echo "已跳過開機自動載入設定。"
fi

echo "防火牆設置完成！"
