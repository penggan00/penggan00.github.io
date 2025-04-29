#!/bin/bash

# Ubuntu 全自动配置脚本 (支持 x86/ARM)
# 功能：系统更新、基础工具、Docker、虚拟内存、时区、SSH保活、BBR加速
# 优化：自动适配官方仓库、安装错误重试、架构检测优化

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 非交互式环境变量
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# 错误重试函数
function retry() {
    local n=1
    local max=3
    while true; do
        "$@" && break || {
            echo -e "${YELLOW}命令失败，重试 $n/$max...${NC}"
            ((n++))
            sleep 2
            if [[ $n -ge $max ]]; then
                echo -e "${RED}最终重试失败，请检查日志${NC}"
                return 1
            fi
        }
    done
}

# 检查系统
if ! grep -qi 'ubuntu' /etc/os-release; then
    echo -e "${RED}错误：仅支持 Ubuntu 系统${NC}"
    exit 1
fi

# 1. 系统更新
echo -e "${GREEN}[1/7] 系统更新...${NC}"
retry sudo apt-get -qq update
retry sudo apt-get -y -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    upgrade
sudo apt-get -y autoremove

# 2. 安装基础工具（增加必要依赖）
echo -e "${GREEN}[2/7] 安装基础工具...${NC}"
retry sudo apt-get -y install --no-install-recommends \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    curl wget git htop \
    gnupg2 jq tmux \
    zip unzip net-tools > /dev/null

# 3. 安装Docker（优化架构检测和源配置）
echo -e "${GREEN}[3/7] 安装Docker...${NC}"
if ! command -v docker &> /dev/null; then
    # 精确架构检测
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  DOCKER_ARCH="amd64" ;;
        aarch64) DOCKER_ARCH="arm64" ;;
        *)       echo -e "${RED}不支持的架构: $ARCH${NC}"; exit 1 ;;
    esac

    # 安装Docker官方源（带重试和证书验证）
    sudo mkdir -p /etc/apt/keyrings
    retry curl -fsSL --retry 3 https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$DOCKER_ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    retry sudo apt-get -qq update
    retry sudo apt-get -y install \
        docker-ce docker-ce-cli \
        containerd.io docker-buildx-plugin \
        docker-compose-plugin > /dev/null

    sudo usermod -aG docker "$USER"
    sudo systemctl enable --now docker
fi

# 4. 配置虚拟内存（优化内存分配）
echo -e "${GREEN}[4/7] 配置虚拟内存...${NC}"
[ -f /swapfile ] || {
    sudo fallocate -l 1G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
}

# 5. 设置新加坡时区（增加NTP同步）
echo -e "${GREEN}[5/7] 设置时区...${NC}"
retry sudo apt-get -y install chrony > /dev/null
sudo timedatectl set-timezone Asia/Singapore
sudo timedatectl set-ntp true
sudo systemctl restart chrony
sudo hwclock --systohc

# 6. 配置SSH保活（优化参数）
echo -e "${GREEN}[6/7] 配置SSH...${NC}"
sudo sed -i '/ClientAliveInterval/d;/ClientAliveCountMax/d' /etc/ssh/sshd_config
echo "ClientAliveInterval 30" | sudo tee -a /etc/ssh/sshd_config
echo "ClientAliveCountMax 5" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd

# 7. 安装BBR（优化内核检测）
echo -e "${GREEN}[7/7] 启用BBR加速...${NC}"
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    retry wget --no-check-certificate -qO /tmp/bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh
    chmod +x /tmp/bbr.sh
    echo -e "1\n" | sudo /tmp/bbr.sh > /dev/null
    rm -f /tmp/bbr.sh
else
    echo -e "${YELLOW}BBR 已启用，跳过安装${NC}"
fi

echo -e "\n${GREEN}全自动配置完成！${NC}"
echo -e "建议执行 ${YELLOW}reboot${NC} 重启系统"