cat << 'EOF' > /usr/ssh.sh
#!/bin/bash
# 配置参数
TOKEN="7422217982:AAGcyh0Do-RzggL8i61BksdVZModB6wfHzc"
CHAT_ID="7071127210"
LOG_FILE="/usr/ssh_telegram_alert.log"
LOCK_DIR="/usr/ssh_telegram"
LOCK_FILE="${LOCK_DIR}/alert.lock"
ALERT_INTERVAL=21600  # 6小时

# 确保锁目录存在
mkdir -p "$LOCK_DIR"

# 获取 PAM 用户
PAM_USER="${PAM_USER:-$USER}"

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# 使用健壮锁
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log "另一个实例正在运行，跳过"
    exit 1
fi

# 检查用户的上次报警时间
USER_LOCK_FILE="${LOCK_DIR}/user_${PAM_USER}.lock"
if [[ -f "$USER_LOCK_FILE" ]]; then
    last_alert=$(stat -c %Y "$USER_LOCK_FILE")
    current_time=$(date +%s)
    if (( current_time - last_alert < ALERT_INTERVAL )); then
        log "用户 $PAM_USER 的告警间隔未达到 ${ALERT_INTERVAL} 秒，跳过"
        exit 0
    fi
fi

# 获取客户端IP
CLIENT_IP=""
if [[ -n "$SSH_CONNECTION" ]]; then
    CLIENT_IP=$(echo "$SSH_CONNECTION" | awk '{print $1}')
elif [[ -n "$SSH_CLIENT" ]]; then
    CLIENT_IP=$(echo "$SSH_CLIENT" | awk '{print $1}')
else
    CLIENT_IP=$(who -m 2>/dev/null | awk '{print $NF}' | sed 's/[()]//g')
    [[ -z "$CLIENT_IP" ]] && CLIENT_IP="未知"
fi

# 生成唯一ID
UNIQUE_ID=$(echo -n "${PAM_USER}-$(hostname)-$(date +%s%N)" | md5sum | cut -d' ' -f1)

# 构建消息
MESSAGE="🚨 SSH登录告警 🚨
用户: $PAM_USER 
主机: $(hostname)
ip:($CLIENT_IP)
时间: $(date '+%Y-%m-%d %H:%M:%S')"
# 发送Telegram通知（关键修复：使用绝对路径）
TELEGRAM_RESPONSE=$(/usr/bin/curl -s -X POST \
    --retry 3 \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT_ID\",\"text\":\"$MESSAGE\"}" \
    "https://api.telegram.org/bot$TOKEN/sendMessage")

# 处理响应（关键修复：使用绝对路径）
if /usr/bin/jq -e '.ok' <<< "$TELEGRAM_RESPONSE" &>/dev/null; then
    touch "$USER_LOCK_FILE"
    log "用户 $PAM_USER 的告警发送成功 (ID: $UNIQUE_ID)"
else
    error_msg=$(/usr/bin/jq -r '.description' <<< "$TELEGRAM_RESPONSE")
    log "错误：Telegram API 返回 - ${error_msg:-未知错误}"
fi

flock -u 9
exit 0
EOF
echo "ssh.sh脚本成功:"
cat << 'EOF' >> /etc/pam.d/sshd
session optional pam_exec.so /usr/ssh.sh
EOF
echo "/etc/pam.d/sshd脚本成功:"
sudo apt update && sudo apt install -y curl jq
echo "依赖安装成功:"
sudo chmod +x /usr/ssh.sh
sudo systemctl restart sshd
echo "重启成功:"
