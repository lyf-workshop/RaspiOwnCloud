#!/bin/bash
#
# RaspberryCloud 更新脚本
# 更新应用代码和依赖
#

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo "此脚本需要root权限运行"
    echo "请使用: sudo bash update.sh"
    exit 1
fi

print_info "========================================="
print_info "RaspberryCloud 更新脚本"
print_info "========================================="
echo ""

# 停止服务
print_info "停止服务..."
systemctl stop raspberrycloud

# 备份当前版本
print_info "备份当前版本..."
BACKUP_DIR="/opt/raspberrycloud_backup_$(date +%Y%m%d_%H%M%S)"
cp -r /opt/raspberrycloud "$BACKUP_DIR"
print_info "备份保存在: $BACKUP_DIR"

# 更新代码（如果使用Git）
if [ -d "/opt/raspberrycloud/.git" ]; then
    print_info "从Git拉取最新代码..."
    cd /opt/raspberrycloud
    sudo -u www-data git pull
else
    print_warn "未检测到Git仓库，请手动更新代码文件"
    read -p "按回车键继续..."
fi

# 更新Python依赖
print_info "更新Python依赖..."
cd /opt/raspberrycloud
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt --upgrade

# 数据库迁移（如果需要）
if [ -f "alembic/versions/*.py" ]; then
    print_info "执行数据库迁移..."
    alembic upgrade head
fi

# 更新前端文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -d "$SCRIPT_DIR/frontend" ]; then
    print_info "更新前端文件..."
    cp -r "$SCRIPT_DIR/frontend"/* /var/www/raspberrycloud/
    chown -R www-data:www-data /var/www/raspberrycloud
fi

# 重启服务
print_info "重启服务..."
systemctl start raspberrycloud
systemctl restart nginx

# 检查服务状态
sleep 3
if systemctl is-active --quiet raspberrycloud; then
    print_info "✅ 服务启动成功"
else
    print_warn "❌ 服务启动失败"
    echo "查看日志: sudo journalctl -u raspberrycloud -n 50"
    echo "如需回滚，运行: sudo cp -r $BACKUP_DIR/* /opt/raspberrycloud/"
    exit 1
fi

echo ""
print_info "========================================="
print_info "更新完成！"
print_info "========================================="
echo ""


