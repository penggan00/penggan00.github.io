#!/bin/bash

set -e  # 有错误立即退出

echo "========================================"
echo "开始配置UFW防火墙"
echo "========================================"

# [1] 更新系统
echo "[1/6] 更新系统并安装ufw..."
sudo apt update -y
sudo apt install ufw -y

# [3] 设置默认策略
echo "[3/6] 设置默认策略..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# [4] 开放必要端口
echo "[4/6] 配置防火墙规则..."
echo "允许端口: 222/tcp (SSH), 80/tcp, 443/tcp, 53/udp, 12000/tcp"

sudo ufw allow 222/tcp comment 'SSH alternative port'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw allow 53/udp comment 'DNS'
sudo ufw allow 123/udp comment 'NTP'
#sudo ufw allow 12000/tcp comment 'Custom port 12000'

# [5] 检查当前监听的端口
echo "[5/6] 当前系统监听的端口:"
sudo ss -tulnp | head -20

# [6] 启用UFW（会有交互提示）
echo "[6/6] 启用UFW防火墙..."
echo "注意：如果当前通过SSH连接，请确保已允许SSH端口！"
read -p "是否继续启用UFW？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo ufw enable
    sudo systemctl enable ufw --now
    
    echo "✅ UFW配置完成！"
    echo "========================================"
    sudo ufw status numbered
    echo "========================================"
    echo "重要提醒："
    echo "1. 确保端口222可以访问，否则可能丢失SSH连接"
    echo "2. 如需修改规则：sudo ufw delete [规则号]"
    echo "3. 查看详细日志：sudo ufw status verbose"
else
    echo "❌ 用户取消操作"
    exit 1
fi