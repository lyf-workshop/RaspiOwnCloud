#!/bin/bash
# 修复Nginx配置文件
# 解决登录时返回HTML而非JSON的问题

set -e

echo "======================================"
echo "修复RaspberryCloud Nginx配置"
echo "======================================"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用root权限运行此脚本"
    echo "   运行: sudo bash scripts/fix_nginx.sh"
    exit 1
fi

# 获取项目根目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "📂 项目目录: $PROJECT_ROOT"

# 备份当前Nginx配置
NGINX_CONFIG="/etc/nginx/sites-available/raspberrycloud"
if [ -f "$NGINX_CONFIG" ]; then
    echo "📦 备份当前Nginx配置..."
    cp "$NGINX_CONFIG" "$NGINX_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✅ 备份完成"
else
    echo "⚠️  未找到现有Nginx配置，将创建新配置"
fi

# 复制新配置文件
echo "📝 更新Nginx配置..."
cp "$PROJECT_ROOT/config/nginx.conf" "$NGINX_CONFIG"

# 测试Nginx配置
echo "🔍 测试Nginx配置..."
if nginx -t; then
    echo "✅ Nginx配置测试通过"
else
    echo "❌ Nginx配置测试失败"
    echo "   正在恢复备份..."
    if [ -f "$NGINX_CONFIG.backup.$(date +%Y%m%d_%H%M%S)" ]; then
        mv "$NGINX_CONFIG.backup.$(date +%Y%m%d_%H%M%S)" "$NGINX_CONFIG"
        echo "✅ 已恢复备份"
    fi
    exit 1
fi

# 重启Nginx
echo "🔄 重启Nginx服务..."
systemctl restart nginx

# 检查Nginx状态
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx服务运行正常"
else
    echo "❌ Nginx服务启动失败"
    systemctl status nginx
    exit 1
fi

# 检查后端服务
echo ""
echo "🔍 检查后端服务状态..."
if systemctl is-active --quiet raspberrycloud; then
    echo "✅ RaspberryCloud后端服务运行正常"
else
    echo "⚠️  RaspberryCloud后端服务未运行"
    echo "   启动服务: sudo systemctl start raspberrycloud"
fi

echo ""
echo "======================================"
echo "✨ Nginx配置修复完成！"
echo "======================================"
echo ""
echo "现在请在笔记本浏览器中刷新页面，然后重新尝试登录。"
echo ""
echo "如果仍然有问题，可以查看日志："
echo "  - Nginx错误日志: tail -f /var/log/nginx/raspberrycloud_error.log"
echo "  - 后端服务日志: sudo journalctl -u raspberrycloud -f"
echo ""

