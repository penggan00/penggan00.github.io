#!/bin/bash
# bash <(curl -sL https://raw.githubusercontent.com/penggan00/penggan00.github.io/main/my-blog/sh/vps.sh) "ssh-rsa AAAAB3NzaC1yc2E... your_email@example.com"

SSH_PUBKEY="$1"

echo "修改SSH配置文件..."
sudo sed -i '/^#*PasswordAuthentication/c\PasswordAuthentication no' /etc/ssh/sshd_config
sudo sed -i '/^#*PubkeyAuthentication/c\PubkeyAuthentication yes' /etc/ssh/sshd_config
sudo sed -i '/^#*PermitRootLogin/c\PermitRootLogin prohibit-password' /etc/ssh/sshd_config
sudo sed -i '/^#*ChallengeResponseAuthentication/c\ChallengeResponseAuthentication no' /etc/ssh/sshd_config

# 确保222端口配置存在
echo "配置SSH端口..."
sudo sed -i 's/^#Port 22$/Port 222/; s/^Port 22$/Port 222/; s/^#Port 222$/Port 222/' /etc/ssh/sshd_config

# 设置SSH密钥目录
echo "配置SSH公钥..."
sudo mkdir -p /root/.ssh && sudo chmod 700 /root/.ssh
echo "$SSH_PUBKEY" | sudo tee /root/.ssh/authorized_keys > /dev/null
sudo chmod 600 /root/.ssh/authorized_keys

# 如果是普通用户，也配置当前用户（如果有sudo权限的话）
if [ "$EUID" -ne 0 ]; then
    echo "为当前用户配置SSH密钥..."
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    echo "$SSH_PUBKEY" > ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
fi

# 重启SSH服务
echo "重启SSH服务..."
sudo systemctl restart sshd

# 验证SSH配置
echo "当前SSH配置:"
sudo grep -E "^(PasswordAuthentication|PubkeyAuthentication|PermitRootLogin|Port)" /etc/ssh/sshd_config

echo ""
echo "✅ SSH公钥已成功配置！"
echo "重要提示: 请确保您在其他终端成功连接后再关闭当前会话！"

# 继续执行其他安装任务
echo "开始安装常用工具..."
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y curl wget git htop tmux nano tree jq fail2ban ufw 

# 配置fail2ban
echo "配置fail2ban..."
sudo systemctl stop fail2ban >/dev/null 2>&1
sudo tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
backend = systemd
maxretry = 3
EOF
sudo systemctl start fail2ban >/dev/null 2>&1

# 安装docker
echo "安装Docker..."
curl -fsSL https://get.docker.com | sh
sudo systemctl enable docker
sudo systemctl start docker

# 完整的时区设置
apt-get update && apt-get install -y systemd-timesyncd
sudo timedatectl set-timezone Asia/Singapore && \
sudo timedatectl set-local-rtc 0 && \
sudo timedatectl set-ntp true && \
echo "✅ 时区设置完成" && \
timedatectl status

# 配置SSH保活
echo "配置SSH保活..."
cat > ~/.ssh/config << 'EOF'
Host *
  ServerAliveInterval 60
  ServerAliveCountMax 3
  TCPKeepAlive yes
  ControlMaster auto
  ControlPath ~/.ssh/control/%r@%h:%p
  ControlPersist 168h
  Compression yes
  CompressionLevel 6
  IPQoS throughput
  ConnectTimeout 30
  ConnectionAttempts 3
  StrictHostKeyChecking no
EOF

mkdir -p ~/.ssh/control
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config
chmod 700 ~/.ssh/control

# 设置交换空间
echo "设置交换空间..."
sudo swapoff -a 2>/dev/null
sudo rm -f /swapfile
sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo sed -i '/swap/d' /etc/fstab
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swap.conf
sudo sysctl -p /etc/sysctl.d/99-swap.conf

# 安装BBR（可选）
echo "正在安装BBR加速..."
wget --no-check-certificate -O /opt/bbr.sh https://raw.githubusercontent.com/penggan00/penggan00.github.io/main/my-blog/sh/bbr.sh
chmod +x /opt/bbr.sh
/opt/bbr.sh

echo ""
echo "✅ 所有配置完成！"
echo "========================================="
echo "重要信息:"
echo "1. SSH端口: 222"
echo "2. 密码登录已禁用"
echo "3. 使用提供的公钥进行SSH认证"
echo "4. 请立即使用新配置测试连接:"
echo "   ssh -p 222 root@服务器IP"
echo "========================================="