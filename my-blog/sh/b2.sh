#!/bin/bash
set -e  # Exit immediately if any command fails

# 安装必要依赖（包括 unzip）
echo "正在安装系统依赖..."
sudo apt-get update
sudo apt-get install -y curl gnupg2 unzip  # 明确添加 unzip

# 安装rclone（如果未安装）
if ! command -v rclone &> /dev/null; then
    echo "正在安装rclone..."
    curl -sS https://rclone.org/install.sh | sudo bash
fi

# 检查并加载环境变量文件
ENV_FILE="~/rss/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "错误: 环境变量文件 $ENV_FILE 不存在" >&2
    exit 1
fi

# 安全加载环境变量（限制变量范围）
echo "正在加载环境变量..."
B2_ACCOUNT=""
B2_KEY=""
source "$ENV_FILE"

if [ -z "$B2_ACCOUNT" ] || [ -z "$B2_KEY" ]; then
    echo "错误: 必须设置 B2_ACCOUNT 和 B2_KEY 环境变量" >&2
    exit 1
fi

# 创建配置文件
echo "正在创建rclone配置文件..."
mkdir -p ~/.config/rclone
cat > ~/.config/rclone/rclone.conf <<EOF
[penggan]
type = b2
account = $B2_ACCOUNT
key = $B2_KEY
EOF
chmod 600 ~/.config/rclone/rclone.conf

# 验证安装和配置
echo -e "\n验证安装结果："
rclone --version && echo "rclone 安装成功!" || echo "rclone 安装失败!"
echo "配置文件路径： ~/.config/rclone/rclone.conf"
echo "无需重启系统，但如果是首次安装，请重新打开终端或运行 'source ~/.bashrc'"