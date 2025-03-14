#!/bin/bash

# 更新系統並安裝必要的工具
sudo apt update -y
sudo apt install -y wget curl unzip tar

# 創建 JDK 安裝目錄
JDK_DIR="/JDK"
JDK_VERSION="jdk-21.0.2"
JDK_PATH="${JDK_DIR}/${JDK_VERSION}"

echo "創建 JDK 目錄：$JDK_DIR"
sudo mkdir -p $JDK_DIR
sudo chmod 777 $JDK_DIR

# 下載 OpenJDK 21.0.2（官方提供的 tar.gz 版本）
echo "下載 OpenJDK 21.0.2..."
wget -O /tmp/openjdk21.tar.gz https://download.oracle.com/java/21/archive/jdk-21.0.5_linux-x64_bin.tar.gz

# 解壓到指定目錄
echo "解壓 JDK..."
sudo tar -xzf /tmp/openjdk21.tar.gz -C $JDK_DIR

# 刪除下載的安裝包
rm -f /tmp/openjdk21.tar.gz

# 配置 Java 環境變數到 /root/.bashrc
echo "配置 Java 環境變數..."
echo "export JAVA_HOME=$JDK_PATH" | sudo tee -a /root/.bashrc
echo "export PATH=\$PATH:\$JAVA_HOME/bin" | sudo tee -a /root/.bashrc
echo "export PATH=\$PATH:/usr/sbin:/usr/bin" | sudo tee -a /root/.bashrc

# 讓變數立即生效
source /root/.bashrc

# 驗證 Java 安裝
java -version
javac -version

# 安裝 Node.js 與 npm
echo "安裝 Node.js 與 npm..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 安裝 pm2
echo "安裝 PM2..."
sudo npm install -g pm2

# 設置 pm2 為開機啟動
echo "配置 PM2 為開機啟動..."
pm2 startup systemd -u root --hp /root

echo "安裝完成！請手動運行 'source /root/.bashrc' 以應用變數"
