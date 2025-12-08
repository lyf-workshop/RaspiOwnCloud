#!/bin/bash
#
# 重置管理员密码脚本
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
print_info "重置管理员密码"
print_info "========================================="
echo ""

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    print_error "此脚本需要root权限运行"
    echo "请使用: sudo bash reset_admin_password.sh"
    exit 1
fi

# 进入项目目录
cd /opt/raspberrycloud

# 激活虚拟环境
print_info "激活Python虚拟环境..."
source venv/bin/activate

# 运行重置脚本
print_info "重置管理员密码..."
python scripts/reset_admin_password.py

echo ""
print_info "========================================="
print_info "完成！"
print_info "========================================="
echo ""
print_info "默认管理员信息:"
echo "  用户名: admin"
echo "  密码: RaspberryCloud2024!"
echo ""
print_warn "请使用新密码登录，登录后立即修改密码！"
echo ""

