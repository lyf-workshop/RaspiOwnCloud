#!/bin/bash
# 强制修复Nginx配置
# 当普通修复无效时使用此脚本

set -e

echo "========================================"
echo "强制修复 Nginx 配置"
echo "========================================"
echo ""

# 检查root权限
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用root权限运行"
    echo "   运行: sudo bash scripts/force_fix_nginx.sh"
    exit 1
fi

# 获取项目目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "📂 项目目录: $PROJECT_ROOT"
echo ""

# 1. 停止服务
echo "🛑 停止服务..."
systemctl stop nginx || true
echo "✅ Nginx已停止"
echo ""

# 2. 备份旧配置
echo "📦 备份旧配置..."
BACKUP_FILE="/etc/nginx/sites-available/raspberrycloud.backup.$(date +%Y%m%d_%H%M%S)"
if [ -f "/etc/nginx/sites-available/raspberrycloud" ]; then
    cp /etc/nginx/sites-available/raspberrycloud "$BACKUP_FILE"
    echo "✅ 备份到: $BACKUP_FILE"
else
    echo "⚠️  未找到旧配置文件"
fi
echo ""

# 3. 删除旧的符号链接
echo "🗑️  删除旧的符号链接..."
rm -f /etc/nginx/sites-enabled/raspberrycloud
rm -f /etc/nginx/sites-enabled/default
echo "✅ 已删除"
echo ""

# 4. 复制新配置
echo "📝 复制新的Nginx配置..."
cp "$PROJECT_ROOT/config/nginx.conf" /etc/nginx/sites-available/raspberrycloud
echo "✅ 配置文件已复制"
echo ""

# 5. 显示关键配置内容
echo "🔍 检查关键配置..."
echo "---"
echo "查找 location /api/ 块："
if grep -A 5 "location /api/" /etc/nginx/sites-available/raspberrycloud | grep -v "^--$"; then
    echo "✅ 找到 location /api/ 配置"
else
    echo "❌ 未找到 location /api/ 配置"
fi
echo ""

# 6. 创建符号链接
echo "🔗 创建符号链接..."
ln -sf /etc/nginx/sites-available/raspberrycloud /etc/nginx/sites-enabled/raspberrycloud
echo "✅ 符号链接已创建"
echo ""

# 7. 测试配置
echo "🔍 测试Nginx配置..."
if nginx -t; then
    echo "✅ Nginx配置测试通过"
else
    echo "❌ Nginx配置测试失败"
    echo ""
    echo "正在恢复备份..."
    if [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" /etc/nginx/sites-available/raspberrycloud
        echo "✅ 已恢复备份"
    fi
    exit 1
fi
echo ""

# 8. 启动Nginx
echo "🚀 启动Nginx..."
systemctl start nginx
echo "✅ Nginx已启动"
echo ""

# 9. 检查服务状态
echo "🔍 检查服务状态..."
echo "---"

if systemctl is-active --quiet nginx; then
    echo "✅ Nginx运行正常"
else
    echo "❌ Nginx启动失败"
    systemctl status nginx
    exit 1
fi

if systemctl is-active --quiet raspberrycloud; then
    echo "✅ RaspberryCloud后端运行正常"
else
    echo "⚠️  RaspberryCloud后端未运行"
    echo "   正在启动..."
    systemctl start raspberrycloud || true
    sleep 2
    if systemctl is-active --quiet raspberrycloud; then
        echo "✅ RaspberryCloud后端已启动"
    else
        echo "❌ RaspberryCloud后端启动失败"
        echo "   查看日志: sudo journalctl -u raspberrycloud -n 50"
    fi
fi
echo ""

# 10. 测试API端点
echo "🧪 测试API端点..."
echo "---"

echo "测试后端直连 (localhost:8000)..."
if curl -s http://localhost:8000/api/health | grep -q "status"; then
    echo "✅ 后端API响应正常"
else
    echo "❌ 后端API无响应"
fi

sleep 1

echo "测试Nginx代理 (localhost:80)..."
response=$(curl -s http://localhost/api/health)
if echo "$response" | grep -q "status"; then
    echo "✅ Nginx代理正常，返回JSON"
    echo "   响应: $response"
elif echo "$response" | grep -q "<html"; then
    echo "❌ Nginx仍然返回HTML！"
    echo "   响应前100字符: ${response:0:100}"
    echo ""
    echo "⚠️  这可能是因为Nginx缓存，请清除浏览器缓存后重试"
else
    echo "⚠️  响应异常: $response"
fi
echo ""

# 11. 显示配置文件位置
echo "📍 配置文件位置:"
echo "   源文件: $PROJECT_ROOT/config/nginx.conf"
echo "   安装位置: /etc/nginx/sites-available/raspberrycloud"
echo "   启用链接: /etc/nginx/sites-enabled/raspberrycloud"
echo "   备份文件: $BACKUP_FILE"
echo ""

echo "========================================"
echo "✨ 强制修复完成！"
echo "========================================"
echo ""
echo "📝 下一步操作:"
echo "   1. 在浏览器中清除缓存 (Ctrl+Shift+Delete)"
echo "   2. 或使用无痕模式 (Ctrl+Shift+N)"
echo "   3. 访问 http://树莓派IP"
echo "   4. 登录: admin / RaspberryCloud2024!"
echo ""
echo "如果仍然有问题，请查看:"
echo "   - Nginx日志: tail -f /var/log/nginx/raspberrycloud_error.log"
echo "   - 后端日志: journalctl -u raspberrycloud -f"
echo ""



























