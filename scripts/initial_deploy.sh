#!/bin/bash
#
# 初始部署脚本（双文件夹部署架构）
# 
# 架构说明：
#   更新文件夹：~/Desktop/Github/RaspiOwnCloud/ (从GitHub拉取代码)
#   生产文件夹：/opt/raspberrycloud/ (实际运行的服务)
# 
# 使用方法：
#   cd ~/Desktop/Github/RaspiOwnCloud
#   sudo bash scripts/initial_deploy.sh
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    print_error "此脚本需要root权限运行"
    echo "请使用: sudo bash initial_deploy.sh"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}RaspberryCloud 初始部署${NC}"
echo -e "${GREEN}双文件夹部署架构${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检测更新文件夹
if [ -d "/home/pi/Desktop/Github/RaspiOwnCloud" ]; then
    UPDATE_DIR="/home/pi/Desktop/Github/RaspiOwnCloud"
elif [ -d "$HOME/Desktop/Github/RaspiOwnCloud" ]; then
    UPDATE_DIR="$HOME/Desktop/Github/RaspiOwnCloud"
else
    print_error "未找到更新文件夹"
    echo ""
    echo "请先创建更新文件夹并克隆项目："
    echo "  mkdir -p ~/Desktop/Github"
    echo "  cd ~/Desktop/Github"
    echo "  git clone https://github.com/lyf-workshop/RaspiOwnCloud.git"
    echo ""
    exit 1
fi

# 生产文件夹
PROD_DIR="/opt/raspberrycloud"

print_info "更新文件夹: $UPDATE_DIR"
print_info "生产文件夹: $PROD_DIR"
echo ""

# 检查生产文件夹是否已存在
if [ -d "$PROD_DIR" ]; then
    print_warn "生产文件夹已存在: $PROD_DIR"
    read -p "是否覆盖现有部署? (yes/no): " -r
    if [[ ! $REPLY == "yes" ]]; then
        print_info "已取消部署"
        exit 0
    fi
    print_info "备份现有部署..."
    BACKUP_DIR="/opt/raspberrycloud_backup_$(date +%Y%m%d_%H%M%S)"
    cp -r "$PROD_DIR" "$BACKUP_DIR"
    print_info "备份保存在: $BACKUP_DIR"
fi

# 步骤1：创建生产目录结构
print_step "步骤1：创建生产目录结构"
mkdir -p "$PROD_DIR"/{backend,frontend,config,scripts,docs}
mkdir -p /var/www/raspberrycloud
mkdir -p /var/log/raspberrycloud
print_info "✅ 目录结构创建完成"
echo ""

# 步骤2：复制文件到生产目录
print_step "步骤2：复制文件到生产目录"

print_info "复制后端文件..."
cp -r "$UPDATE_DIR/backend"/* "$PROD_DIR/backend/"

print_info "复制前端文件..."
cp -r "$UPDATE_DIR/frontend"/* /var/www/raspberrycloud/

print_info "复制配置文件..."
cp -r "$UPDATE_DIR/config"/* "$PROD_DIR/config/"

print_info "复制脚本文件..."
cp -r "$UPDATE_DIR/scripts"/* "$PROD_DIR/scripts/"

print_info "复制文档文件..."
cp -r "$UPDATE_DIR/docs"/* "$PROD_DIR/docs/"

print_info "✅ 文件复制完成"
echo ""

# 步骤3：设置权限
print_step "步骤3：设置权限"
chown -R www-data:www-data "$PROD_DIR"
chown -R www-data:www-data /var/www/raspberrycloud
chown -R www-data:www-data /var/log/raspberrycloud
chmod -R 755 "$PROD_DIR"
chmod -R 755 /var/www/raspberrycloud
print_info "✅ 权限设置完成"
echo ""

# 步骤4：创建Python虚拟环境
print_step "步骤4：创建Python虚拟环境"
cd "$PROD_DIR"
python3 -m venv venv
chown -R www-data:www-data "$PROD_DIR/venv"
print_info "✅ 虚拟环境创建完成"
echo ""

# 步骤5：安装Python依赖
print_step "步骤5：安装Python依赖（需要5-10分钟）"
cd "$PROD_DIR/backend"
sudo -u www-data bash -c "source $PROD_DIR/venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"
print_info "✅ Python依赖安装完成"
echo ""

# 步骤6：配置环境变量
print_step "步骤6：配置环境变量"
if [ -f "$PROD_DIR/config/env.example" ]; then
    if [ ! -f "$PROD_DIR/backend/.env" ]; then
        cp "$PROD_DIR/config/env.example" "$PROD_DIR/backend/.env"
        print_info "已创建 .env 文件"
        print_warn "请编辑 $PROD_DIR/backend/.env 配置数据库等信息"
    else
        print_info ".env 文件已存在，跳过"
    fi
    chown www-data:www-data "$PROD_DIR/backend/.env"
    chmod 600 "$PROD_DIR/backend/.env"
fi
echo ""

# 步骤7：配置systemd服务
print_step "步骤7：配置systemd服务"
if [ -f "$PROD_DIR/config/raspberrycloud.service" ]; then
    cp "$PROD_DIR/config/raspberrycloud.service" /etc/systemd/system/
    systemctl daemon-reload
    print_info "✅ systemd服务配置完成"
else
    print_warn "未找到服务配置文件"
fi
echo ""

# 步骤8：配置Nginx
print_step "步骤8：配置Nginx"
if [ -f "$PROD_DIR/config/nginx.conf" ]; then
    cp "$PROD_DIR/config/nginx.conf" /etc/nginx/sites-available/raspberrycloud
    
    # 创建软链接
    if [ ! -L /etc/nginx/sites-enabled/raspberrycloud ]; then
        ln -s /etc/nginx/sites-available/raspberrycloud /etc/nginx/sites-enabled/
    fi
    
    # 测试Nginx配置
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        print_info "✅ Nginx配置完成"
    else
        print_warn "Nginx配置测试失败，请手动检查"
    fi
else
    print_warn "未找到Nginx配置文件"
fi
echo ""

# 步骤9：启动服务
print_step "步骤9：启动服务"
systemctl enable raspberrycloud
systemctl start raspberrycloud
sleep 3

# 检查服务状态
if systemctl is-active --quiet raspberrycloud; then
    print_info "✅ RaspberryCloud服务: 运行中"
else
    print_error "❌ RaspberryCloud服务: 未运行"
    echo "   查看日志: sudo journalctl -u raspberrycloud -n 50"
fi

if systemctl is-active --quiet nginx; then
    print_info "✅ Nginx服务: 运行中"
else
    print_error "❌ Nginx服务: 未运行"
fi
echo ""

# 完成
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
print_info "架构说明："
echo "  📁 更新文件夹: $UPDATE_DIR"
echo "     - 用于Git操作和代码更新"
echo "     - 权限：普通用户"
echo ""
echo "  📁 生产文件夹: $PROD_DIR"
echo "     - 实际运行的服务代码"
echo "     - 权限：www-data"
echo ""
print_info "后续更新流程："
echo "  1. cd $UPDATE_DIR"
echo "  2. git pull origin main"
echo "  3. bash scripts/quick_update.sh"
echo ""
print_info "访问地址: http://$(hostname -I | awk '{print $1}')"
print_info "默认账户: admin / RaspberryCloud2024!"
echo ""
print_warn "重要提示："
echo "  1. 请修改默认管理员密码"
echo "  2. 请编辑 $PROD_DIR/backend/.env 配置数据库等信息"
echo "  3. 如需初始化数据库，运行: cd $PROD_DIR/backend && sudo -u www-data bash -c 'source ../venv/bin/activate && python -c \"from models import init_db; init_db()\"'"
echo ""


