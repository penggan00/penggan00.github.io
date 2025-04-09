# 在 request_certificates() 函数中修改如下：
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
    
    # 添加证书申请结果总览
    local success_count=0
    local fail_count=0
    
    for domain in "${DOMAIN_ARRAY[@]}"; do
        log "INFO" "正在处理域名: $domain"
        
        # 移除静默模式，记录详细日志
        if certbot certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials "$cred_file" \
            --email "$EMAIL_USER" \
            --agree-tos \
            --non-interactive \
            --keep-until-expiring \
            -d "$domain" >> "$LOG_FILE" 2>&1; then
            
            log "SUCCESS" "✓ $domain 证书申请成功"
            ((success_count++))
            
            # 验证证书信息
            local cert_path="/etc/letsencrypt/live/$domain/cert.pem"
            if [ -f "$cert_path" ];then
                local expire_date=$(openssl x509 -in "$cert_path" -noout -enddate | cut -d= -f2)
                log "INFO" "证书有效期至: $expire_date"
            else
                log "WARNING" "未找到证书文件: $cert_path"
            fi
        else
            log "ERROR" "✗ $domain 证书申请失败 (详见日志: tail -n 50 $LOG_FILE)"
            ((fail_count++))
            continue
        fi
    done
    
    shred -u "$cred_file" 2>/dev/null || rm -f "$cred_file"
    
    # 添加申请结果汇总
    log "INFO" "--------------------------------------------"
    log "SUCCESS" "成功申请证书域名数: $success_count"
    [ $fail_count -gt 0 ] && log "ERROR" "失败域名数: $fail_count"
    log "INFO" "详细日志请查看: $LOG_FILE"
}

# 在主流程中添加最终状态检查
main() {
    init_log
    check_system
    install_dependencies
    load_config
    backup_config
    request_certificates
    setup_renewal
    
    # 最终成功提示
    log "SUCCESS" "SSL证书自动化部署完成！"
    echo -e "\n${GREEN}=== 操作已完成 ===${NC}"
    echo -e "请检查上方日志确认最终状态"
    echo -e "证书路径: /etc/letsencrypt/live/YOUR_DOMAIN/"
}