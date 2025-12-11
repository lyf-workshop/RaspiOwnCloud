#!/bin/bash
#
# 阿里云DNS自动更新脚本（Shell包装）
# 用于动态IP（VPN）环境下自动更新DNS记录
#
# 使用方法：
#   1. 配置环境变量（见下方）
#   2. 设置定时任务：crontab -e
#      添加: */5 * * * * /path/to/update_aliyun_dns.sh
#

# 配置信息（请修改为你的实际值）
export ALIYUN_ACCESS_KEY_ID="你的AccessKey ID"
export ALIYUN_ACCESS_KEY_SECRET="你的AccessKey Secret"
export ALIYUN_DOMAIN="你的域名.com"  # 例如: example.com
export ALIYUN_SUBDOMAIN="@"  # @ 表示主域名，www 表示www子域名

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/update_aliyun_dns.py"

# 检查Python脚本是否存在
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "[ERROR] Python脚本不存在: $PYTHON_SCRIPT"
    exit 1
fi

# 检查Python3
if ! command -v python3 &> /dev/null; then
    echo "[ERROR] 未找到 python3，请先安装"
    exit 1
fi

# 记录日志（可选）
LOG_FILE="/var/log/aliyun_dns_update.log"
if [ -w "$LOG_FILE" ] || [ -w "$(dirname "$LOG_FILE")" ]; then
    # 有写权限，记录到日志文件
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行DNS更新脚本" >> "$LOG_FILE"
    python3 "$PYTHON_SCRIPT" >> "$LOG_FILE" 2>&1
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DNS更新完成（退出码: $EXIT_CODE）" >> "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DNS更新失败（退出码: $EXIT_CODE）" >> "$LOG_FILE"
    fi
    exit $EXIT_CODE
else
    # 如果没有写权限，直接输出到控制台
    python3 "$PYTHON_SCRIPT"
    exit $?
fi



