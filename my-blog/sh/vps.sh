#!/bin/bash

# VPS 一键初始化脚本 (支持 sudo 用户执行)
set -e  # 遇到任何错误立即退出

echo "🚀 开始 VPS 初始化配置..."

# 1. 系统更新及基础工具安装 (使用 sudo)
echo "[1/6] 正在更新系统并安装基础工具..."
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y --no-install-recommends \
  curl wget git htop tmux zip unzip net-tools nano \
  python3-venv postgresql-client docker.io

echo "✅ 系统更新及基础工具安装完成"

# 2. Docker配置 (使用 sudo)
echo "[2/6] 正在配置Docker服务..."
sudo usermod -aG docker $USER  # 将当前用户加入docker组
sudo systemctl start docker
sudo systemctl enable docker
echo "✅ Docker 已安装并启动，用户 $USER 已加入 docker 组"

# 3. 设置新加坡时区 (使用 sudo)
echo "[3/6] 正在设置新加坡时区..."
sudo timedatectl set-timezone Asia/Singapore
sudo timedatectl set-local-rtc 0
sudo hwclock --systohc
echo "✅ 新加坡时间已永久设置（UTC+8）"

# 4. BBR加速 (需要 root 权限，使用 sudo)
echo "[4/6] 正在安装 BBR 加速..."
wget --no-check-certificate -O /tmp/bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh
chmod +x /tmp/bbr.sh
sudo /tmp/bbr.sh 2>&1 | tee /tmp/bbr-install.log
echo "✅ BBR 加速已安装，需要重启生效"

# 5. SSH保活设置 (使用 sudo)
echo "[5/6] 正在配置SSH保活..."
echo "net.ipv4.tcp_keepalive_time = 60" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_keepalive_intvl = 30" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_keepalive_probes = 3" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 为用户配置 SSH（不需要 sudo）
mkdir -p ~/.ssh
echo -e "Host *\n  ServerAliveInterval 50\n  ServerAliveCountMax 3\n  TCPKeepAlive yes" >> ~/.ssh/config
chmod 600 ~/.ssh/config
echo "✅ SSH 保活设置完成"

# 6. 创建1GB虚拟内存 (使用 sudo)
echo "[6/6] 正在创建1GB虚拟内存..."
if [ -f /swapfile ]; then
    echo "⚠️  发现已有 swapfile，跳过创建"
else
    sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
    echo "✅ 1GB 虚拟内存已创建并启用"
fi

echo -e "\n📊 内存状态："
free -h

# 7. 验证安装
echo -e "\n🎉 所有安装已完成！验证信息："
echo -e "Docker 版本: $(docker --version 2>/dev/null || echo '未安装成功')"
echo -e "PostgreSQL 客户端版本: $(psql --version 2>/dev/null || echo '未安装成功')"
echo -e "当前时区: $(timedatectl | grep 'Time zone' | cut -d':' -f2-)"
echo -e "BBR 状态: $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}' || echo '未启用')"

echo -e "\n⚠️  重要提示："
echo "1. 部分更改（如用户组更新）需要重新登录或重启才能生效"
echo "2. BBR 加速需要重启后生效"
echo "3. 建议执行: sudo reboot 重启系统"

echo -e "\n✨ 初始化脚本执行完毕！"