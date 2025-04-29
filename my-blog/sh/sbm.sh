# 1. 安装Samba服务
sudo apt update && sudo apt install samba -y
# 2. 备份原配置文件
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
# 3. 生成新配置文件
sudo tee /etc/samba/smb.conf > /dev/null <<EOF
[global]
   workgroup = WORKGROUP
   server role = standalone server
   security = user
   map to guest = Bad User
   dns proxy = no

[dav]
   path = /mnt
   browseable = yes
   writable = yes
   guest ok = yes
   guest only = yes
   create mask = 0777
   directory mask = 0777
   force user = nobody
EOF
# 4. 设置目录权限
sudo chmod -R 777 /mnt
sudo chown -R nobody:nogroup /mnt
# 5. 重启服务
sudo systemctl restart smbd
sudo systemctl enable smbd
echo "SMB共享已启用：smb://$(hostname -I | awk '{print $1}')/dav/"