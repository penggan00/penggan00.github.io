cat <<"EOF" > /etc/init.d/mount_hp
#!/bin/sh /etc/rc.common
# 一键式双硬盘挂载脚本
START=99
STOP=15

boot() {
    logger -t mount_hp "开始挂载硬盘..."
    
    # 等待USB设备初始化
    sleep 5
    
    # 挂载第一块硬盘
    if [ -b /dev/sda1 ]; then
        mkdir -p /mnt/hp
        if ! mount UUID=e0280430-4e37-471a-b784-ad948d7e48f4 /mnt/hp; then
            logger -t mount_hp "sda1挂载失败，尝试修复..."
            fsck -y /dev/sda1
            mount UUID=e0280430-4e37-471a-b784-ad948d7e48f4 /mnt/hp || {
                logger -t mount_hp "sda1最终挂载失败"
            }
        fi
    fi
    
    # 挂载第二块硬盘
    if [ -b /dev/sdb1 ]; then
        mkdir -p /mnt/hp1
        if ! mount UUID=0da13076-ccf7-4bd3-8d54-0b51bb4b33f5 /mnt/hp1; then
            logger -t mount_hp "sdb1挂载失败，尝试修复..."
            fsck -y /dev/sdb1
            mount UUID=0da13076-ccf7-4bd3-8d54-0b51bb4b33f5 /mnt/hp1 || {
                logger -t mount_hp "sdb1最终挂载失败"
            }
        fi
    fi
    
    # 验证结果
    df -h | grep -E 'hp|Filesystem' | logger -t mount_hp
}

start() { boot; }
EOF

chmod +x /etc/init.d/mount_hp
/etc/init.d/mount_hp enable

# 配置fstab备份
cat <<EOF >> /etc/fstab
UUID=e0280430-4e37-471a-b784-ad948d7e48f4 /mnt/hp  ext4  rw,nofail,noatime  0 1
UUID=0da13076-ccf7-4bd3-8d54-0b51bb4b33f5 /mnt/hp1 ext4  rw,nofail,noatime  0 1
EOF

# 创建挂载点
mkdir -p /mnt/{hp,hp1}
chmod 777 /mnt/{hp,hp1}

echo "✅ 一键配置完成！即将测试挂载..."
sleep 2
/etc/init.d/mount_hp start
logread | grep mount_hp
df -h | grep hp