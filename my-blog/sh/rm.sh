sudo apt autoremove -y && \
sudo apt autoclean -y && \
sudo journalctl --vacuum-time=7d && \
sudo rm -rf /var/log/*.gz /var/log/*.old /var/log/apt/*.log && \
rm -rf ~/.cache/* ~/.thumbnails/* ~/.local/share/Trash/* && \
sudo find /var/lib/apt/lists/ -type f -delete && \
echo "✅ 清理完成！释放空间: $(df -h / | awk 'NR==2 {print $4}')"