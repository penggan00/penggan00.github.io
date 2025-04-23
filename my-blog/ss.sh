#!/bin/bash

# ==============================================
# 无日志记录的进程监控脚本
# 使用 TELEGRAM_API_KEY 和 TELEGRAM_CHAT_ID 环境变量
# ==============================================

# 获取脚本所在目录
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# 加载 .env 文件（如果存在）
if [ -f "${SCRIPT_DIR}/.env" ]; then
    source "${SCRIPT_DIR}/.env"
fi

# 检查必要的环境变量
if [ -z "$TELEGRAM_API_KEY" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "错误：TELEGRAM_API_KEY 或 TELEGRAM_CHAT_ID 未定义" >&2
    exit 1
fi

# 获取系统信息
REPORT_DATE=$(date "+%Y-%m-%d %H:%M:%S")
HOSTNAME=$(hostname)
UPTIME=$(uptime -p)
LOAD_AVG=$(awk '{print $1,$2,$3}' /proc/loadavg)
MEMORY_FREE=$(free -m | awk '/Mem:/ {print $4}')

# 检测进程
PROCESS_REPORT=$(ps aux | awk '/[q]q.py|[g]pt.py/ {
    printf "🟢 PID: %s\n📛 命令: %s\n💻 CPU: %s%%\n🧠 内存: %s%% (%s KB)\n⏱️ 运行时间: %s\n------------------------\n", 
    $2, $11, $3, $4, $6, $9
}')

[ -z "$PROCESS_REPORT" ] && PROCESS_REPORT="⚠️ 未检测到目标进程"

# 发送到Telegram
curl -s -X POST \
    https://api.telegram.org/bot${TELEGRAM_API_KEY}/sendMessage \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="📊 *进程监控报告*
⏰ 时间: $REPORT_DATE
🖥️ 主机: $HOSTNAME
🔄 运行时间: $UPTIME
📈 负载: $LOAD_AVG
💾 可用内存: ${MEMORY_FREE}MB

*🔍 检测结果:*
$PROCESS_REPORT" \
    -d parse_mode="Markdown" \
    > /dev/null