#!/bin/bash
#
# 修复 raspberrycloud 服务配置
# 解决 226/NAMESPACE 错误
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

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    print_error "此脚本需要root权限运行"
    echo "请使用: sudo bash fix_service.sh"
    exit 1
fi

print_info "========================================="
print_info "修复 RaspberryCloud 服务配置"
print_info "========================================="
echo ""

# 备份原配置
if [ -f "/etc/systemd/system/raspberrycloud.service" ]; then
    print_info "备份原配置文件..."
    cp /etc/systemd/system/raspberrycloud.service /etc/systemd/system/raspberrycloud.service.backup.$(date +%Y%m%d_%H%M%S)
fi

# 创建修复后的服务配置
print_info "创建修复后的服务配置..."
cat > /etc/systemd/system/raspberrycloud.service << 'EOF'
[Unit]
Description=RaspberryCloud Private Cloud Storage Service
Documentation=https://github.com/your-repo/raspberrycloud
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/raspberrycloud/backend
Environment="PATH=/opt/raspberrycloud/venv/bin"
Environment="PYTHONUNBUFFERED=1"

# 启动命令
ExecStart=/opt/raspberrycloud/venv/bin/uvicorn main:app \
    --host 127.0.0.1 \
    --port 8000 \
    --workers 2 \
    --log-level info

# 自动重启
Restart=always
RestartSec=10

# 资源限制
LimitNOFILE=65536
MemoryLimit=512M
CPUQuota=100%

# 日志
StandardOutput=append:/var/log/raspberrycloud/backend.log
StandardError=append:/var/log/raspberrycloud/backend_error.log
SyslogIdentifier=raspberrycloud

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd
print_info "重新加载systemd配置..."
systemctl daemon-reload

# 停止旧服务（如果正在运行）
print_info "停止旧服务..."
systemctl stop raspberrycloud 2>/dev/null || true

# 启动服务
print_info "启动服务..."
systemctl start raspberrycloud

# 等待几秒
sleep 3

# 检查服务状态
print_info "检查服务状态..."
if systemctl is-active --quiet raspberrycloud; then
    print_info "✅ 服务启动成功！"
    echo ""
    systemctl status raspberrycloud --no-pager -l
else
    print_error "❌ 服务启动失败"
    echo ""
    print_info "查看详细日志："
    echo "  sudo journalctl -u raspberrycloud -n 50 --no-pager"
    echo "  sudo tail -50 /var/log/raspberrycloud/backend_error.log"
    exit 1
fi

echo ""
print_info "========================================="
print_info "修复完成！"
print_info "========================================="


