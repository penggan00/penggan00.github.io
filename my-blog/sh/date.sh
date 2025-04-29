bash -c '
timedatectl set-timezone Asia/Singapore && \
timedatectl set-local-rtc 0 && \
hwclock --systohc
echo "新加坡时间已永久设置，重启后生效。"
'