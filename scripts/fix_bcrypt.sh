#!/bin/bash
#
# 修复 bcrypt 版本兼容性问题
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
print_info "修复 bcrypt 版本兼容性问题"
print_info "========================================="
echo ""

# 检查虚拟环境
if [ ! -d "/opt/raspberrycloud/venv" ]; then
    print_error "虚拟环境不存在，请先创建虚拟环境"
    exit 1
fi

# 进入项目目录
cd /opt/raspberrycloud

# 激活虚拟环境
print_info "激活虚拟环境..."
source venv/bin/activate

# 卸载有问题的包
print_info "卸载旧版本的 bcrypt..."
pip uninstall -y bcrypt passlib 2>/dev/null || true

# 安装兼容版本
print_info "安装兼容版本的依赖..."
pip install bcrypt==4.0.1
pip install 'passlib[bcrypt]==1.7.4'

# 验证安装
print_info "验证安装..."
python -c "from passlib.context import CryptContext; ctx = CryptContext(schemes=['bcrypt']); print('✅ bcrypt 工作正常')" || {
    print_error "bcrypt 验证失败"
    exit 1
}

print_info "========================================="
print_info "修复完成！"
print_info "========================================="
echo ""
print_info "现在可以重新初始化数据库："
echo "  cd /opt/raspberrycloud"
echo "  source venv/bin/activate"
echo "  python -c \"from models import init_db; init_db()\""
echo ""

