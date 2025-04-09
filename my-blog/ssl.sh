#!/bin/bash

# ==============================================
# Certbot SSL证书自动化管理脚本 (Root用户专用版)
# 版本：2.1
# 最后更新：2024-05-01
# 项目地址：https://github.com/penggan00/my-blog
# ==============================================

# 初始化安全设置
set -o errexit
set -o nounset
set -o pipefail

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
        error_exit "此脚本需要Ubuntu 18.04或更高版本"
    fi
    
    log "INFO" "Ubuntu版本: $DISTRIB_DESCRIPTION"
}

# 安装依赖
install_dependencies() {
    log "INFO" "正在安装依赖..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get update > /dev/null 2>&1 || error_exit "apt更新失败"
    
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
            if ! apt-get install -y "$pkg" > /dev/null 2>&1; then
                log "ERROR" "安装 $pkg 失败，尝试从PPA安装..."
                add-apt-repository -y ppa:certbot/certbot > /dev/null 2>&1
                apt-get update > /dev/null 2>&1
                apt-get install -y "$pkg" || error_exit "安装 $pkg 失败"
            fi
            log "INFO" "已安装: $pkg"
        else
            log "INFO" "已存在: $pkg"
        fi
    done
}

# 加载配置
load_config() {
    log "INFO" "正在加载配置..."
    
    local env_file="/root/rss/.env"  # 修改为你的.env绝对路径
    
    if [ -f "$env_file" ]; then
        log "INFO" "检测到本地.env文件，加载环境变量"
        source "$env_file"
    else
        log "WARNING" "未找到配置文件，将使用手动输入"
    fi
    
    # 获取Cloudflare API Token
    while [ -z "${CFAPI:-}" ] || [ ${#CFAPI} -lt 40 ]; do
        read -sp "请输入Cloudflare API Token: " CFAPI
        echo ""
        [ ${#CFAPI} -lt 40 ] && log "WARNING" "Token长度不足40字符!"
    done
    
    # 获取邮箱
    while [[ ! "${EMAIL_USER:-}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
        read -p "请输入管理员邮箱: " EMAIL_USER
    done
    
    # 获取域名
    while [ -z "${DOMAINS:-}" ]; do
        read -p "请输入域名(多个用空格分隔): " DOMAINS
        [ -z "$DOMAINS" ] && log "WARNING" "域名不能为空!"
    done
}

# 备份配置
backup_config() {
    log "INFO" "正在备份现有证书配置..."
    
    mkdir -p "$BACKUP_DIR"
    local backup_name="letsencrypt_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    if [ -d "$CONFIG_DIR" ]; then
        if tar -czf "${BACKUP_DIR}/${backup_name}" -C /etc letsencrypt > /dev/null 2>&1; then
            log "SUCCESS" "配置已备份到: ${BACKUP_DIR}/${backup_name}"
        else
            log "WARNING" "配置备份失败"
        fi
    else
        log "INFO" "未找到现有证书配置，跳过备份"
    fi
}

# 申请证书
request_certificates() {
    log "INFO" "正在申请证书..."
    
    local cred_dir="/root/.secrets/certbot"
    local cred_file="${cred_dir}/cloudflare.ini"
    
    mkdir -p "$cred_dir"
    umask 077
    cat > "$cred_file" <<EOF
dns_cloudflare_api_token = ${CFAPI}
EOF
    
    IFS=' ' read -ra DOMAIN_ARRAY <<< "$DOMAINS"
    for domain in "${DOMAIN_ARRAY[@]}"; do
        log "INFO" "正在处理域名: $domain"
        
        if certbot certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials "$cred_file" \
            --email "$EMAIL_USER" \
            --agree-tos \
            --non-interactive \
            --keep-until-expiring \
            -d "$domain" > /dev/null 2>&1; then
            
            log "SUCCESS" "✓ $domain 证书申请成功"
            
            # 验证证书信息
            local cert_path="/etc/letsencrypt/live/$domain/cert.pem"
            if [ -f "$cert_path" ];then
                local expire_date=$(openssl x509 -in "$cert_path" -noout -enddate | cut -d= -f2)
                log "INFO" "证书有效期至: $expire_date"
            fi
        else
            log "ERROR" "✗ $domain 证书申请失败"
            continue
        fi
    done
    
    shred -u "$cred_file" 2>/dev/null || rm -f "$cred_file"
}

# 配置自动续签
setup_renewal() {
    log "INFO" "正在配置自动续签..."
    
    local renew_script="/usr/local/bin/certbot_renew.sh"
    
    cat > "$renew_script" <<EOF
#!/bin/bash
exec > >(tee -a "$LOG_FILE") 2>&1
if certbot renew --noninteractive --quiet; then
    echo "证书续签成功"
else
    echo "证书续签失败"
fi
EOF
    
    chmod 750 "$renew_script"
    local cron_job="0 3 */$CHECK_INTERVAL * * $renew_script"
    if ! crontab -l | grep -q "$renew_script"; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    fi
}

# 主执行流程
main() {
    init_log
    check_system
    install_dependencies
    load_config
    backup_config
    request_certificates
    setup_renewal
}

if [ "$(id -u)" = "0" ]; then
    main "$@"
else
    echo -e "${RED}错误：必须使用root用户执行此脚本${NC}" >&2
    exit 1
fi