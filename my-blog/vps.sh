#!/bin/bash

# Ubuntu 全自动配置脚本 (支持 x86/ARM)
# 功能：系统更新、基础工具、Docker、虚拟内存、时区、SSH保活、Zsh
# 使用：curl -sSL https://example.com/ubuntu-auto.sh | bash

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 非交互式环境变量
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# 检查系统
if ! grep -qi 'ubuntu' /etc/os-release; then
    echo -e "${RED}错误：仅支持 Ubuntu 系统${NC}"
    exit 1
fi

# 1. 系统更新
echo -e "${GREEN}[1/7] 系统更新...${NC}"
sudo apt-get -qq update
sudo apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    upgrade
sudo apt-get -y autoremove

# 2. 安装基础工具
echo -e "${GREEN}[2/7] 安装基础工具...${NC}"
sudo apt-get -y install \
    curl wget git htop tmux \
    zip unzip net-tools nginx \
    python3-venv ca-certificates \
    gnupg jq > /dev/null

# 3. 安装Docker (官方源)
echo -e "${GREEN}[3/7] 安装Docker...${NC}"
if ! command -v docker &> /dev/null; then
    # 检测架构 (x86/ARM)
    ARCH=$(dpkg --print-architecture)
    [ "$ARCH" = "amd64" ] && DOCKER_ARCH="x86_64" || DOCKER_ARCH="aarch64"

    # 安装Docker官方源
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$ARCH] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get -qq update
    sudo apt-get -y install \
        docker-ce docker-ce-cli \
        containerd.io docker-compose-plugin > /dev/null

    sudo usermod -aG docker $USER
    sudo systemctl enable --now docker
fi

# 4. 配置虚拟内存
echo -e "${GREEN}[4/7] 配置虚拟内存...${NC}"
[ -f /swapfile ] || {
    sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo 'vm.swappiness=60' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
}

# 5. 设置香港时区
echo -e "${GREEN}[5/7] 设置时区...${NC}"
sudo timedatectl set-timezone Asia/Hong_Kong
sudo timedatectl set-local-rtc 0
sudo hwclock --systohc

# 6. 配置SSH保活
echo -e "${GREEN}[6/7] 配置SSH...${NC}"
sudo sed -i '/ClientAliveInterval/d;/ClientAliveCountMax/d' /etc/ssh/sshd_config
echo "ClientAliveInterval 60" | sudo tee -a /etc/ssh/sshd_config
echo "ClientAliveCountMax 3" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd

# 7. 安装Zsh

echo -e "\n${GREEN}全自动配置完成！${NC}"
echo -e "执行 ${YELLOW}exec zsh${NC} 立即生效"