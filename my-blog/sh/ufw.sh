#!/bin/bash

# 更新系统并安装 ufw
echo "[1/6] 更新系统并安装 ufw..."
sudo apt update -y
sudo apt install ufw -y

# 检查当前开放的端口
echo "[2/6] 检查当前开放的端口 (ss -tulnp)..."
ss -tulnp

echo "[3/6] 允许 222 80 443 53 123 12000"
# sudo ufw allow 22
sudo ufw allow 222
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 53
sudo ufw allow 123
sudo ufw allow 12000

# 启用 ufw 并设置开机自启
echo "[4/6] 启用 ufw 并设置开机自启..."
sudo ufw enable
sudo systemctl enable ufw

# 检查 ufw 状态
echo "[5/6] 检查 ufw 状态..."
sudo ufw status

# 检查 ufw 是否开机自启
echo "[6/6] 检查 ufw 是否开机自启..."
systemctl is-enabled ufw

echo "✅ ufw 防火墙配置完成！"
echo "sudo ufw allow 222"