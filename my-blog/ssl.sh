#!/bin/bash

# ==============================================
# 优化版Certbot自动证书管理脚本
# 功能：使用Cloudflare DNS API申请和自动续签SSL证书
# 特点：
# 1. 支持x86/ARM架构
# 2. 支持Ubuntu 16.04+
# 3. 完善的错误处理和日志记录
# 4. 配置自动备份
# 5. 邮件通知功能
# ==============================================

# 初始化设置
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

# 配置变量
RENEW_THRESHOLD=30
CHECK_INTERVAL=7
LOG_FILE="/var/log/certbot_renew.log"
BACKUP_DIR="/etc/letsencrypt_backup"
CONFIG_DIR="/etc/letsencrypt"

# 获取脚本绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

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
    
    # 检查root权限
    [ "$(id -u)" != "0" ] && error_exit "必须使用root用户运行此脚本"
    
    # 检查架构
    ARCH=$(uname -m)
    log "INFO" "系统架构: $ARCH"
    
    # 检查Ubuntu版本
    if [ ! -f /etc/lsb-release ]; then
        error_exit "此脚本仅支持Ubuntu系统"
    fi
    
    source /etc/lsb-release
    UBUNTU_VERSION=${DISTRIB_RELEASE}
    
    if [[ $(echo "$UBUNTU_VERSION < 16.04" | bc) -eq 1 ]]; then
        error_exit "此脚本需要Ubuntu 16.04或更高版本"
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
        "shred"
        "mailutils"
        "bc"
        "jq"
    )
    
    for pkg in "${dependencies[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            apt-get install -y "$pkg" > /dev/null 2>&1 || error_exit "安装 $pkg 失败"
            log "INFO" "已安装: $pkg"
        else
            log "INFO" "已存在: $pkg"
        fi
    done
    
    # 添加Certbot官方PPA确保最新版本
    add-apt-repository -y ppa:certbot/certbot > /dev/null 2>&1
    apt-get update > /dev/null 2>&1
}

# 加载配置
load_config() {
    log "INFO" "正在加载配置..."
    
    if [ -f "${ENV_FILE}" ]; then
        log "INFO" "检测到.env文件，加载环境变量"
        source "${ENV_FILE}"
        
        # 验证必需变量
        [ -z "${CFAPI:-}" ] && error_exit ".env中缺少CFAPI变量"
        [ -z "${EMAIL_USER:-}" ] && error_exit ".env中缺少EMAIL_USER变量"
        [ -z "${DOMAINS:-}" ] && error_exit ".env中缺少DOMAINS变量"
        
        cf_token="$CFAPI"
        email="$EMAIL_USER"
        domains="$DOMAINS"
    else
        log "WARNING" "未找到.env文件，将使用手动输入"
        
        # 获取Cloudflare API Token
        while [ -z "$cf_token" ] || [ ${#cf_token} -lt 40 ]; do
            read -sp "请输入Cloudflare API Token: " cf_token
            echo ""
            [ ${#cf_token} -lt 40 ] && log "WARNING" "Token长度不足40字符!"
        done
        
        # 获取邮箱
        while [[ ! "${email:-}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
            read -p "请输入管理员邮箱: " email
        done
        
        # 获取域名
        while [ -z "${domains:-}" ]; do
            read -p "请输入域名(多个用空格分隔): " domains
            [ -z "$domains" ] && log "WARNING" "域名不能为空!"
        done
    fi
}

# 备份配置
backup_config() {
    log "INFO" "正在备份现有证书配置..."
    
    mkdir -p "$BACKUP_DIR"
    local backup_name="letsencrypt_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    if [ -d "$CONFIG_DIR" ]; then
        tar -czf "${BACKUP_DIR}/${backup_name}" -C /etc letsencrypt && \
        log "SUCCESS" "配置已备份到: ${BACKUP_DIR}/${backup_name}" || \
        log "WARNING" "配置备份失败"
    else
        log "INFO" "未找到现有证书配置，跳过备份"
    fi
}

# 申请证书
request_certificates() {
    log "INFO" "正在申请证书..."
    
    mkdir -p /root/.secrets/certbot
    local cred_file="/root/.secrets/certbot/cloudflare.ini"
    
    # 安全创建凭据文件
    umask 077
    cat > "$cred_file" <<EOF
dns_cloudflare_api_token = ${cf_token}
EOF
    
    # 申请每个域名的证书
    IFS=' ' read -ra DOMAIN_ARRAY <<< "$domains"
    for domain in "${DOMAIN_ARRAY[@]}"; do
        log "INFO" "正在处理域名: $domain"
        
        if certbot certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials "$cred_file" \
            --email "$email" \
            --agree-tos \
            --non-interactive \
            --keep-until-expiring \
            -d "$domain" > /dev/null 2>&1; then
            
            log "SUCCESS" "✓ $domain 证书申请成功"
            
            # 获取证书信息
            local cert_info=$(openssl x509 -in "/etc/letsencrypt/live/$domain/cert.pem" -noout -dates)
            log "INFO" "证书有效期:\n$cert_info"
        else
            log "ERROR" "✗ $domain 证书申请失败"
            continue
        fi
    done
    
    # 安全清理凭据文件
    shred -u "$cred_file" 2>/dev/null || rm -f "$cred_file"
}

# 配置自动续签
setup_renewal() {
    log "INFO" "正在配置自动续签..."
    
    local renew_script="/usr/local/bin/certbot_renew.sh"
    
    # 创建续签脚本
    cat > "$renew_script" <<EOF
#!/bin/bash

# 日志设置
LOG="$LOG_FILE"
exec >> "\$LOG" 2>&1

echo -e "\n\$(date '+%Y-%m-%d %H:%M:%S') - 开始证书续签检查"

# 续签证书
if certbot renew --noninteractive --quiet --deploy-hook "echo '证书续签成功' | mail -s '证书续签通知' $email"; then
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - 证书续签成功"
else
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - 证书续签失败"
    echo "证书续签失败" | mail -s "证书续签错误警报" $email
fi
EOF
    
    chmod 750 "$renew_script"
    
    # 添加到crontab
    local cron_job="0 3 */$CHECK_INTERVAL * * $renew_script"
    if ! crontab -l | grep -q "$renew_script"; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab - && \
        log "SUCCESS" "自动续签配置成功" || \
        error_exit "添加cron任务失败"
    else
        log "INFO" "自动续签任务已存在，跳过添加"
    fi
    
    log "INFO" "检查频率: 每${CHECK_INTERVAL}天"
    log "INFO" "续签阈值: 到期前${RENEW_THRESHOLD}天"
}

# 显示总结信息
show_summary() {
    echo -e "\n${CYAN}=== 安装摘要 ===${NC}"
    echo -e "${GREEN}✓ 所有操作已完成${NC}"
    echo -e "  - 系统架构: ${ARCH}"
    echo -e "  - Ubuntu版本: ${DISTRIB_DESCRIPTION}"
    echo -e "  - 管理邮箱: ${email}"
    echo -e "  - 域名列表: ${domains}"
    echo -e "  - 日志文件: ${LOG_FILE}"
    echo -e "  - 备份目录: ${BACKUP_DIR}"
    echo -e "  - 自动续签: 已启用 (每${CHECK_INTERVAL}天检查)"
    echo -e "${CYAN}================${NC}\n"
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
    show_summary
    
    log "SUCCESS" "脚本执行完成"
}

# 执行主函数
main "$@"