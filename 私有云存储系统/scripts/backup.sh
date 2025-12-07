#!/bin/bash
#
# RaspberryCloud 备份脚本
# 备份数据库和用户文件
#

set -e

# 配置
BACKUP_DIR="/mnt/cloud_storage/backups"
DB_PATH="/opt/raspberrycloud/backend/raspberrycloud.db"
DATA_DIR="/mnt/cloud_storage/users"
DATE=$(date +%Y%m%d_%H%M%S)
KEEP_DAYS=7  # 保留最近7天的备份

# 颜色输出
GREEN='\033[0;32m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# 创建备份目录
mkdir -p "$BACKUP_DIR"

print_info "开始备份..."

# 备份数据库
if [ -f "$DB_PATH" ]; then
    print_info "备份数据库..."
    DB_BACKUP="$BACKUP_DIR/database_$DATE.db"
    cp "$DB_PATH" "$DB_BACKUP"
    gzip "$DB_BACKUP"
    print_info "数据库备份完成: ${DB_BACKUP}.gz"
fi

# 备份用户文件（增量备份）
if [ -d "$DATA_DIR" ]; then
    print_info "备份用户文件..."
    DATA_BACKUP="$BACKUP_DIR/userdata_$DATE.tar.gz"
    tar -czf "$DATA_BACKUP" -C "$(dirname $DATA_DIR)" "$(basename $DATA_DIR)"
    print_info "用户文件备份完成: $DATA_BACKUP"
fi

# 清理旧备份
print_info "清理${KEEP_DAYS}天前的旧备份..."
find "$BACKUP_DIR" -name "database_*.gz" -mtime +$KEEP_DAYS -delete
find "$BACKUP_DIR" -name "userdata_*.tar.gz" -mtime +$KEEP_DAYS -delete

print_info "备份完成！"

