#!/bin/bash
#
# 从Windows传输文件到树莓派的辅助脚本
# 使用方法：在Windows上使用scp/rsync传输后，在树莓派上运行此脚本
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

print_info "========================================="
print_info "从Windows传输文件后的部署脚本"
print_info "========================================="
echo ""

# 检查是否在部署目录
if [ ! -d "/opt/raspberrycloud" ]; then
    print_error "未找到部署目录 /opt/raspberrycloud"
    exit 1
fi

# 进入部署目录
cd /opt/raspberrycloud

# 1. 更新Python依赖
print_info "更新Python依赖..."
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    pip install --upgrade pip
    if [ -f "backend/requirements.txt" ]; then
        pip install -r backend/requirements.txt --upgrade
    elif [ -f "requirements.txt" ]; then
        pip install -r requirements.txt --upgrade
    else
        print_warn "未找到requirements.txt，跳过依赖更新"
    fi
else
    print_warn "未找到虚拟环境，跳过依赖更新"
fi

# 2. 检查并重启服务
print_info "检查服务状态..."
if systemctl is-active --quiet raspberrycloud; then
    print_info "重启raspberrycloud服务..."
    sudo systemctl restart raspberrycloud
else
    print_warn "raspberrycloud服务未运行，尝试启动..."
    sudo systemctl start raspberrycloud
fi

# 3. 重启Nginx（如果需要）
if systemctl is-active --quiet nginx; then
    print_info "重启Nginx..."
    sudo systemctl restart nginx
fi

# 4. 检查服务状态
sleep 3
print_info "检查服务状态..."
if systemctl is-active --quiet raspberrycloud; then
    print_info "✅ raspberrycloud服务运行正常"
else
    print_error "❌ raspberrycloud服务启动失败"
    print_info "查看日志：sudo journalctl -u raspberrycloud -n 50"
    exit 1
fi

# 5. 显示服务信息
echo ""
print_info "服务信息："
echo "  - 后端服务：$(systemctl is-active raspberrycloud)"
echo "  - Nginx服务：$(systemctl is-active nginx)"
echo ""
print_info "✅ 部署完成！"
print_info "访问地址：http://$(hostname -I | awk '{print $1}')"

