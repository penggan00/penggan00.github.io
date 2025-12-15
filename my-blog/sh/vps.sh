# 一键安装所有常用工具（包含UFW防火墙）
sudo apt update -y && \
sudo apt upgrade -y && \
sudo apt install -y --no-install-recommends \
  curl wget git htop tmux zip unzip net-tools nano vim \
  python3-venv python3-pip postgresql-client mysql-client \
  tree ncdu screen jq pv rsync dstat iftop iotop \
  ca-certificates apt-transport-https software-properties-common \
  ufw fail2ban \
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