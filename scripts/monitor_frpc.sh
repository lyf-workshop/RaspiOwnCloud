#!/bin/bash
# FRP客户端监控和自动重启脚本（树莓派）
# 建议添加到crontab，每5分钟运行一次

# 配置
LOG_FILE="/var/log/frpc_monitor.log"
MAX_LOG_SIZE=10485760  # 10MB

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 日志轮转
rotate_log() {
    if [ -f "$LOG_FILE" ]; then
        LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
        if [ "$LOG_SIZE" -gt "$MAX_LOG_SIZE" ]; then
            mv "$LOG_FILE" "$LOG_FILE.old"
            touch "$LOG_FILE"
            log "日志文件已轮转"
        fi
    fi
}

# 检查FRP服务状态
check_frpc() {
    if systemctl is-active --quiet frpc; then
        return 0
    else
        return 1
    fi
}

# 检查FRP连接状态
check_connection() {
    # 检查最近5分钟的日志中是否有成功连接的记录
    if journalctl -u frpc --since "5 minutes ago" | grep -q "login to server success"; then
        return 0
    fi
    
    # 检查是否有错误
    if journalctl -u frpc --since "5 minutes ago" | grep -qE "login to server failed|connection refused|EOF"; then
        return 1
    fi
    
    # 如果没有最新日志，认为连接正常
    return 0
}

# 主逻辑
rotate_log

if ! check_frpc; then
    log "❌ FRP客户端未运行，正在重启..."
    systemctl restart frpc
    sleep 5
    
    if check_frpc; then
        log "✅ FRP客户端重启成功"
    else
        log "❌ FRP客户端重启失败！"
    fi
else
    # 服务运行中，检查连接状态
    if ! check_connection; then
        log "⚠️  FRP连接异常，正在重启..."
        systemctl restart frpc
        sleep 5
        log "✅ FRP客户端已重启"
    else
        # 每小时记录一次正常状态
        MINUTE=$(date +%M)
        if [ "$MINUTE" = "00" ]; then
            log "✅ FRP客户端运行正常"
        fi
    fi
fi























