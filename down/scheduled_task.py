import paramiko
import schedule
import time
import telegram

# 配置你的 Telegram 机器人
telegram_token = '7422217982:AAGcyh0Do-RzggL8i61BksdVZModB6wfHzc'
chat_id = '7071127210'

# 创建一个 Telegram 机器人实例
bot = telegram.Bot(token=telegram_token)

# SSH 连接的配置
hostname = 's4.serv00.com'
port = 22
username = 'penggan00'
password = '6Bp#Ku$Y37yj62a#E9$S'

def ssh_task():
    try:
        # 创建 SSH 客户端
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        # 连接到远程服务器
        client.connect(hostname, port, username, password)
        
        # 停留 301 秒
        time.sleep(301)
        
        # 断开连接
        client.close()
        
        # 发送成功消息到 Telegram
        bot.send_message(chat_id=chat_id, text="SSH 任务成功完成。")
    except Exception as e:
        # 发送错误消息到 Telegram
        bot.send_message(chat_id=chat_id, text=f"SSH 任务失败：{e}")

# 每 11 天运行一次任务
schedule.every(11).days.do(ssh_task)

while True:
    schedule.run_pending()
    time.sleep(1)