#!/bin/bash
#
# RaspberryCloud 快速启动脚本
# 用于手动启动服务（开发/测试用）
#

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否在正确的目录
if [ ! -f "/opt/raspberrycloud/backend/main.py" ]; then
    print_error "未找到后端文件，请确保已正确安装"
    exit 1
fi

# 进入后端目录
cd /opt/raspberrycloud/backend

# 激活虚拟环境
print_info "激活Python虚拟环境..."
source /opt/raspberrycloud/venv/bin/activate

# 检查环境变量文件
if [ ! -f ".env" ]; then
    print_warn ".env文件不存在，使用默认配置"
fi

# 初始化数据库（如果需要）
print_info "检查数据库..."
python -c "from models import init_db; init_db()" 2>/dev/null || print_warn "数据库初始化跳过"

# 获取IP地址
IP=$(hostname -I | awk '{print $1}')

print_info "========================================="
print_info "启动 RaspberryCloud 服务"
print_info "========================================="
echo ""
print_info "访问地址:"
echo "  - 后端API: http://${IP}:8000"
echo "  - Web界面: http://${IP}"
echo "  - API文档: http://${IP}:8000/api/docs"
echo ""
print_info "按 Ctrl+C 停止服务"
echo ""

# 启动服务
uvicorn main:app --host 0.0.0.0 --port 8000 --reload

