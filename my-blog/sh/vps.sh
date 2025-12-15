#!/bin/bash
# 一键安装所有常用工具（包含UFW防火墙）
sudo apt update -y && \
sudo apt upgrade -y && \
sudo apt install -y --no-install-recommends \
  curl wget git htop tmux zip unzip nano \
  tree ncdu jq rsync ca-certificates ufw \
  && echo "✅ 所有工具安装完成！"
# 在 Ubuntu 上，你可以使用以下命令安装 Docker：
apt install -y docker.io
apt install docker-compose -y
# 1.2 启动 Docker 服务
usermod -aG docker $USER
systemctl start docker
systemctl enable docker
# 1.3 验证安装
docker --version
# 一键新加坡时间
bash -c '
timedatectl set-timezone Asia/Singapore && \
timedatectl set-local-rtc 0 && \
hwclock --systohc
echo "新加坡时间已永久设置，重启后生效。"
'
# BBR 加速脚本
wget --no-check-certificate -O /opt/bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh
chmod +x /opt/bbr.sh
/opt/bbr.sh
# 一键ssh保活不断线
echo "net.ipv4.tcp_keepalive_time = 60" | sudo tee -a /etc/sysctl.conf && \
echo "net.ipv4.tcp_keepalive_intvl = 30" | sudo tee -a /etc/sysctl.conf && \
echo "net.ipv4.tcp_keepalive_probes = 3" | sudo tee -a /etc/sysctl.conf && \
sudo sysctl -p
echo -e "Host *\n  ServerAliveInterval 50\n  ServerAliveCountMax 3\n  TCPKeepAlive yes" >> ~/.ssh/config

# 一键1g虚拟内存
sudo bash -c 'dd if=/dev/zero of=/swapfile bs=1M count=1024 && \
chmod 600 /swapfile && \
mkswap /swapfile && \
swapon /swapfile && \
echo "/swapfile none swap sw 0 0" >> /etc/fstab && \
echo "1GB Swap 已启用！当前内存状态：" && \
free -h'

# 修改SSH配置文件
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/; s/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/; s/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/; s/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# 确保222端口配置存在
sed -i 's/^#Port 22$/Port 222/; s/^Port 22$/Port 222/; s/^#Port 222$/Port 222/' /etc/ssh/sshd_config

# 设置SSH密钥目录
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7CSx0TIrYmnc6X9BNi/vRd2BbNDhobptIrMPzC1P2t2V10qvhlJEoxmcOxZPqrqZHBXdOCCnyJJIB3lF6aLAWqPlHoWyfH0SY//PTJUTX2udlteCVkNunI8Ew0rUy0XN2dNBETCrER2Gfo0N6sYzHbaMlIV/IPb5HzksrgnsJm6R+j2TJwlcu5eXa49nzdAChSuYePjLe6Yfm8tsfhAMfuJrdPTIcn6m8WRW8rrk9wH3Vu8fPvvno/f744fnm4b/uwO7LQSiYKIx1AfFEkKdJjTYP0+aU1i2J+rvNRUct5gX/m/sevsSeApcj6gjZ/ZtMtWKCl+BuLdH3caigLKGX" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

sudo ufw allow 222
# 重启SSH服务
sudo systemctl restart ssh
sudo systemctl restart sshd

# 检查当前开放的端口
echo "[2/6] 检查当前开放的端口 (ss -tulnp)..."
ss -tulnp

# 允许 SSH (22)、HTTP (80)、HTTPS (443)
echo "[3/6] 允许 SSH (22，222)、HTTP (80)、HTTPS (443)..."
sudo ufw allow 22
sudo ufw allow 222
sudo ufw allow 80
sudo ufw allow 443

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
# 查看所有认证相关配置
grep -E "^(PasswordAuthentication|PubkeyAuthentication|ChallengeResponseAuthentication|PermitRootLogin)" /etc/ssh/sshd_config

