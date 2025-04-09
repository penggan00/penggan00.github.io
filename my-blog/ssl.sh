#!/bin/bash
# ==============================================
# Certbot SSL证书自动化管理脚本 (修复版)
# 最后更新：2024-05-01
# 修复内容：
# 1. 解决BASH_SOURCE报错问题
# 2. 修复shred依赖问题
# 3. 增强错误处理
# ==============================================

# 安全设置
set -o errexit
set -o nounset
set -o pipefail

# 检查执行方式（修复BASH_SOURCE问题）
if [[ -z "${BASH_SOURCE[0]:-}" ]]; then
    echo -e "\033[0;31m错误：请保存脚本到本地后执行\033[0m" >&2
    echo "正确用法：curl -sSL https://example.com/ssl.sh -o ssl.sh && sudo bash ssl.sh"
    exit 1
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置参数
RENEW_THRESHOLD=30
CHECK_INTERVAL=7
LOG_FILE="/var/log/certbot_renew.log"
BACKUP_DIR="/etc/letsencrypt_backup"
CONFIG_DIR="/etc/letsencrypt"

# 初始化日志
init_log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
    echo -e "\n$(date '+%Y-%m-%d %H:%M:%S') - 脚本启动" >> "$LOG_FILE"
}

# 日志记录函数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO") color="${BLUE}" ;;
        "SUCCESS") color="${GREEN}" ;;
        "WARNING") color="${YELLOW}" ;;
        "ERROR") color="${RED}" ;;
        *) color="${NC}" ;;
    esac
    
    echo -e "${color}[${timestamp}] [${level}] ${message}${NC}" | tee -a "$LOG_FILE"
}

# 错误处理函数
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# 系统检查
check_system() {
    log "INFO" "正在检查系统环境..."
    
    # 检查root权限
    [ "$(id -u)" != "0" ] && error_exit "必须使用root用户运行"
    
    # 检查架构
    ARCH=$(uname -m)
    log "INFO" "系统架构: $ARCH"
    
    # 检查Ubuntu版本
    if [ ! -f /etc/lsb-release ]; then
        error_exit "此脚本仅支持Ubuntu系统"
    fi
    
    source /etc/lsb-release
    UBUNTU_VERSION=${DISTRIB_RELEASE}
    
    if [[ $(echo "$UBUNTU_VERSION < 18.04" | bc) -eq 1 ]]; then
        error_exit "需要Ubuntu 18.04或更高版本"
    fi
    
    log "INFO" "Ubuntu版本: $DISTRIB_DESCRIPTION"
}

# 安装依赖
install_dependencies() {
    log "INFO" "正在安装依赖..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get update > /dev/null 2>&1 || error_exit "apt更新失败"
    
    # 修改后的依赖列表（使用coreutils替代shred）
    local dependencies=(
        "certbot"
        "python3-certbot-dns-cloudflare"
        "coreutils"
        "mailutils"
        "bc"
        "jq"
    )
    
    for pkg in "${dependencies[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            log "INFO" "正在安装: $pkg"
            if ! apt-get install -y "$pkg" > /dev/null 2>&1; then
                log "WARNING" "标准安装失败，尝试从PPA安装..."
                add-apt-repository -y ppa:certbot/certbot > /dev/null 2>&1
                apt-get update > /dev/null 2>&1
                apt-get install -y "$pkg" || error_exit "安装 $pkg 失败"
            fi
        fi
    done
}

# 加载配置
load_config() {
    log "INFO" "正在加载配置..."
    
    # 尝试从环境变量获取配置
    if [ -n "${CFAPI:-}" ] && [ -n "${EMAIL_USER:-}" ] && [ -n "${DOMAINS:-}" ]; then
        log "INFO" "检测到环境变量配置"
    else
        # 交互式输入
        while [ -z "${CFAPI:-}" ] || [ ${#CFAPI} -lt 40 ]; do
            read -sp "请输入Cloudflare API Token: " CFAPI
            echo ""
            [ ${#CFAPI} -lt 40 ] && log "WARNING" "Token长度不足40字符!"
        done
        
        while [[ ! "${EMAIL_USER:-}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
            read -p "请输入管理员邮箱: " EMAIL_USER
        done
        
        while [ -z "${DOMAINS:-}" ]; do
            read -p "请输入域名(多个用空格分隔): " DOMAINS
            [ -z "$DOMAINS" ] && log "WARNING" "域名不能为空!"
        done
    fi
}

# 主执行流程
main() {
    init_log
    check_system
    install_dependencies
    load_config
    
    # 证书申请流程
    local cred_file="/root/.secrets/certbot/cloudflare.ini"
    mkdir -p "$(dirname "$cred_file")"
    umask 077
    echo "dns_cloudflare_api_token = ${CFAPI}" > "$cred_file"
    
    IFS=' ' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    for domain in "${DOMAIN_ARRAY[@]}"; do
        log "INFO" "正在处理域名: $domain"
        if certbot certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials "$cred_file" \
            --email "$EMAIL_USER" \
            --agree-tos \
            --non-interactive \
            -d "$domain"; then
            log "SUCCESS" "✓ $domain 证书申请成功"
        else
            log "ERROR" "✗ $domain 证书申请失败"
        fi
    done
    
    # 安全清理
    shred -u "$cred_file" 2>/dev/null || rm -f "$cred_file"
    
    # 配置自动续签
    local renew_script="/usr/local/bin/certbot_renew.sh"
    cat > "$renew_script" <<EOF
#!/bin/bash
# 自动续签脚本
certbot renew --quiet --deploy-hook "echo '证书续签通知' | mail -s '证书续签结果' $EMAIL_USER"
EOF
    chmod +x "$renew_script"
    (crontab -l 2>/dev/null; echo "0 3 */$CHECK_INTERVAL * * $renew_script") | crontab -
    
    log "SUCCESS" "脚本执行完成"
    echo -e "\n${GREEN}=== 安装摘要 ==="
    echo -e "域名: ${DOMAINS}"
    echo -e "续签检查: 每${CHECK_INTERVAL}天"
    echo -e "日志文件: ${LOG_FILE}${NC}"
}

# 执行入口
main "$@"