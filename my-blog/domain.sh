#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
RENEW_THRESHOLD=30
CHECK_INTERVAL=7

# 获取脚本绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# 检查root
[ "$(id -u)" != "0" ] && echo -e "${RED}错误：必须使用root运行！${NC}" >&2 && exit 1

# 加载环境变量
if [ -f "${ENV_FILE}" ]; then
    echo -e "${BLUE}检测到.env文件，加载环境变量...${NC}"
    source "${ENV_FILE}"
else
    echo -e "${YELLOW}未找到.env文件，将使用手动输入${NC}"
fi

# 错误处理
function handle_error() {
    echo -e "${RED}错误: $1${NC}" >&2
    echo "$(date) - 错误: $1" >> /var/log/certbot_renew.log
    exit 1
}

# 清理函数
function cleanup() {
    [ -f "/root/.secrets/certbot/cloudflare.ini" ] && \
    shred -u /root/.secrets/certbot/cloudflare.ini 2>/dev/null || \
    rm -f /root/.secrets/certbot/cloudflare.ini
}

# 主函数
main() {
    # 安装依赖
    echo -e "\n${YELLOW}[1/4] 安装依赖...${NC}"
    apt-get update > /dev/null 2>&1
    apt-get install -y certbot python3-certbot-dns-cloudflare shred mailutils > /dev/null 2>&1 || {
        handle_error "依赖安装失败"
    }

    # 获取配置信息
    echo -e "\n${YELLOW}[2/4] 获取配置信息...${NC}"
    
    # Cloudflare API Token
    if [ -z "$CFAPI" ]; then
        while [ -z "$cf_token" ] || [ ${#cf_token} -lt 40 ]; do
            read -sp "请输入Cloudflare API Token: " cf_token
            echo ""
            [ ${#cf_token} -lt 40 ] && echo -e "${RED}Token长度不足40字符!${NC}"
        done
    else
        cf_token="$CFAPI"
        echo -e "${GREEN}使用环境变量中的Cloudflare Token${NC}"
    fi

    # 邮箱设置
    if [ -z "$EMAIL_USER" ]; then
        read -p "请输入管理员邮箱: " email
        while [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
            read -p "邮箱格式错误，请重新输入: " email
        done
    else
        email="$EMAIL_USER"
        echo -e "${GREEN}使用环境变量中的邮箱: ${email}${NC}"
    fi

    # 域名输入
    while [ -z "$domains" ]; do
        read -p "请输入域名(多个用空格分隔): " domains
        [ -z "$domains" ] && echo -e "${RED}域名不能为空!${NC}"
    done

    # 申请证书
    echo -e "\n${YELLOW}[3/4] 申请证书...${NC}"
    mkdir -p /root/.secrets/certbot
    cat > /root/.secrets/certbot/cloudflare.ini <<EOF
dns_cloudflare_api_token = ${cf_token}
EOF
    chmod 600 /root/.secrets/certbot/cloudflare.ini

    # 证书申请
    IFS=' ' read -ra DOMAIN_ARRAY <<< "$domains"
    for domain in "${DOMAIN_ARRAY[@]}"; do
        certbot certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials /root/.secrets/certbot/cloudflare.ini \
            --email "${email}" \
            --agree-tos \
            --non-interactive \
            -d "${domain}" && \
        echo -e "${GREEN}✓ ${domain} 申请成功${NC}" || \
        echo -e "${RED}✗ ${domain} 申请失败${NC}"
    done

    # 配置自动续签
    echo -e "\n${YELLOW}[4/4] 配置自动续签...${NC}"
    RENEW_SCRIPT="/usr/local/bin/certbot_renew.sh"
    cat > "$RENEW_SCRIPT" <<EOF
#!/bin/bash
certbot renew --quiet --deploy-hook "echo '证书续签成功' | mail -s '证书续签通知' ${email}"
EOF
    chmod +x "$RENEW_SCRIPT"
    (crontab -l 2>/dev/null; echo "0 3 */${CHECK_INTERVAL} * * ${RENEW_SCRIPT}") | crontab -
    
    echo -e "${GREEN}✓ 自动续签配置完成${NC}"
    echo -e "  检查频率: 每${CHECK_INTERVAL}天"
    echo -e "  续签阈值: 到期前${RENEW_THRESHOLD}天"
}

# 执行
trap cleanup EXIT
main