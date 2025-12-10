#!/bin/bash
#
# RaspberryCloud 清理脚本
# 删除之前的部署内容，为重新部署做准备
#

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    print_error "此脚本需要root权限运行"
    echo "请使用: sudo bash cleanup.sh"
    exit 1
fi

print_info "========================================="
print_info "RaspberryCloud 清理脚本"
print_info "========================================="
echo ""

# 检查脚本位置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/cleanup.sh" ]; then
    print_info "脚本位置: $SCRIPT_DIR"
fi
echo ""

# 确认操作
print_warn "⚠️  警告：此操作将删除以下内容："
echo "  - 系统服务 (raspberrycloud.service)"
echo "  - 项目目录 (/opt/raspberrycloud)"
echo "  - 前端文件 (/var/www/raspberrycloud)"
echo "  - Nginx配置"
echo "  - 日志目录 (/var/log/raspberrycloud)"
echo ""
print_warn "⚠️  注意：以下内容将被保留："
echo "  - 用户数据 (/mnt/cloud_storage)"
echo "  - 数据库文件 (如果存在)"
echo ""

read -p "确认继续？(yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    print_info "操作已取消"
    exit 0
fi

# 1. 停止并禁用服务
print_info "1. 停止并禁用系统服务..."
if systemctl is-active --quiet raspberrycloud 2>/dev/null; then
    systemctl stop raspberrycloud
    print_info "   服务已停止"
else
    print_warn "   服务未运行"
fi

if systemctl is-enabled --quiet raspberrycloud 2>/dev/null; then
    systemctl disable raspberrycloud
    print_info "   服务已禁用"
fi

# 2. 删除服务文件
print_info "2. 删除systemd服务文件..."
if [ -f "/etc/systemd/system/raspberrycloud.service" ]; then
    rm /etc/systemd/system/raspberrycloud.service
    systemctl daemon-reload
    print_info "   服务文件已删除"
else
    print_warn "   服务文件不存在"
fi

# 3. 删除Nginx配置
print_info "3. 删除Nginx配置..."
if [ -L "/etc/nginx/sites-enabled/raspberrycloud" ]; then
    rm /etc/nginx/sites-enabled/raspberrycloud
    print_info "   已删除软链接"
fi

if [ -f "/etc/nginx/sites-available/raspberrycloud" ]; then
    rm /etc/nginx/sites-available/raspberrycloud
    print_info "   已删除配置文件"
fi

# 恢复默认配置（如果存在备份）
if [ -f "/etc/nginx/sites-available/default.backup" ]; then
    print_info "   恢复默认Nginx配置..."
    cp /etc/nginx/sites-available/default.backup /etc/nginx/sites-available/default
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
fi

# 测试并重启Nginx
if command -v nginx &> /dev/null; then
    nginx -t && systemctl restart nginx
    print_info "   Nginx已重启"
fi

# 4. 删除项目目录
print_info "4. 删除项目目录..."
if [ -d "/opt/raspberrycloud" ]; then
    rm -rf /opt/raspberrycloud
    print_info "   项目目录已删除"
else
    print_warn "   项目目录不存在"
fi

# 5. 删除前端文件
print_info "5. 删除前端文件..."
if [ -d "/var/www/raspberrycloud" ]; then
    rm -rf /var/www/raspberrycloud
    print_info "   前端文件已删除"
else
    print_warn "   前端目录不存在"
fi

# 6. 删除日志目录
print_info "6. 删除日志目录..."
if [ -d "/var/log/raspberrycloud" ]; then
    rm -rf /var/log/raspberrycloud
    print_info "   日志目录已删除"
else
    print_warn "   日志目录不存在"
fi

# 7. 清理crontab任务（可选）
print_info "7. 检查crontab任务..."
if crontab -l 2>/dev/null | grep -q "raspberrycloud\|cloud_storage"; then
    print_warn "   发现相关定时任务，请手动清理："
    echo "   运行: crontab -e"
    echo "   删除包含 raspberrycloud 或 cloud_storage 的行"
else
    print_info "   未发现相关定时任务"
fi

# 8. 清理Samba配置（可选，仅提示）
print_info "8. 检查Samba配置..."
if [ -f "/etc/samba/smb.conf" ] && grep -q "\[cloud\]" /etc/samba/smb.conf 2>/dev/null; then
    print_warn "   发现Samba配置，如需清理请手动编辑："
    echo "   sudo nano /etc/samba/smb.conf"
    echo "   删除 [cloud] 部分"
else
    print_info "   未发现Samba配置"
fi

# 9. 检查端口占用
print_info "9. 检查端口占用..."
if lsof -i :8000 &>/dev/null; then
    print_warn "   端口8000仍被占用，可能需要手动清理："
    lsof -i :8000
else
    print_info "   端口8000未被占用"
fi

echo ""
print_info "========================================="
print_info "✅ 清理完成！"
print_info "========================================="
echo ""
print_info "保留的内容："
echo "  - 用户数据: /mnt/cloud_storage"
echo "  - 数据库文件: /opt/raspberrycloud/backend/raspberrycloud.db (如果存在)"
echo ""
print_info "现在可以重新部署了："
echo "  1. 按照部署教程重新执行步骤2-6"
echo "  2. 或运行: sudo bash install.sh"
echo ""

