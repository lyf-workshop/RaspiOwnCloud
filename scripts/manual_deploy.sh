#!/bin/bash
#
# RaspberryCloud 手动部署脚本
# 适用于项目根目录为 RaspiOwnCloud 的情况
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    print_error "此脚本需要root权限运行"
    echo "请使用: sudo bash manual_deploy.sh"
    exit 1
fi

print_info "========================================="
print_info "RaspberryCloud 手动部署脚本"
print_info "========================================="
echo ""

# 获取项目目录（假设在 /home/pi/RaspiOwnCloud 或当前目录）
if [ -d "/home/pi/RaspiOwnCloud" ]; then
    PROJECT_DIR="/home/pi/RaspiOwnCloud"
elif [ -d "$(pwd)/RaspiOwnCloud" ]; then
    PROJECT_DIR="$(pwd)/RaspiOwnCloud"
elif [ -f "$(pwd)/backend/main.py" ]; then
    PROJECT_DIR="$(pwd)"
else
    read -p "请输入项目目录的完整路径: " PROJECT_DIR
    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "目录不存在: $PROJECT_DIR"
        exit 1
    fi
fi

print_info "项目目录: $PROJECT_DIR"

# 验证项目结构
if [ ! -d "$PROJECT_DIR/backend" ] || [ ! -d "$PROJECT_DIR/frontend" ]; then
    print_error "项目结构不完整，请确保包含 backend 和 frontend 目录"
    exit 1
fi

# 更新系统
print_info "更新系统软件包..."
apt update
apt upgrade -y

# 安装系统依赖
print_info "安装系统依赖..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    libssl-dev \
    libffi-dev \
    sqlite3 \
    libsqlite3-dev \
    nginx \
    git \
    curl \
    wget \
    vim \
    htop \
    ufw \
    ffmpeg \
    libjpeg-dev \
    zlib1g-dev \
    samba \
    samba-common-bin

# 询问是否安装MariaDB
read -p "是否安装MariaDB数据库? (适合多用户场景) (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "安装MariaDB..."
    apt install -y mariadb-server mariadb-client
    systemctl start mariadb
    systemctl enable mariadb
    print_warn "请稍后运行 'sudo mysql_secure_installation' 配置数据库安全"
fi

# 创建应用目录
print_info "创建应用目录..."
mkdir -p /opt/raspberrycloud
mkdir -p /var/www/raspberrycloud
mkdir -p /var/log/raspberrycloud

# 询问存储方案
echo ""
read -p "使用SD卡存储还是外接硬盘存储? (sd/hdd) [默认:sd] " -n 3 -r
echo
STORAGE_TYPE=${REPLY:-sd}

if [[ $STORAGE_TYPE =~ ^[Hh][Dd][Dd]$ ]]; then
    print_info "使用外接硬盘存储方案..."
    mkdir -p /mnt/cloud_storage/{users,shares,temp,backups}
    chown -R www-data:www-data /mnt/cloud_storage
    STORAGE_PATH="/mnt/cloud_storage"
else
    print_info "使用SD卡存储方案..."
    mkdir -p /opt/raspberrycloud/storage/{users,shares,temp,backups}
    STORAGE_PATH="/opt/raspberrycloud/storage"
fi

# 设置权限
chown -R www-data:www-data /opt/raspberrycloud
chown -R www-data:www-data /var/www/raspberrycloud
chown -R www-data:www-data /var/log/raspberrycloud

# 复制文件
print_info "复制项目文件..."
cp -r "$PROJECT_DIR/backend"/* /opt/raspberrycloud/ 2>/dev/null || print_warn "backend目录未找到，请手动复制"
cp -r "$PROJECT_DIR/frontend"/* /var/www/raspberrycloud/ 2>/dev/null || print_warn "frontend目录未找到，请手动复制"

# 创建Python虚拟环境
print_info "创建Python虚拟环境..."
cd /opt/raspberrycloud
python3 -m venv venv
source venv/bin/activate

# 安装Python依赖
print_info "安装Python依赖（可能需要5-10分钟）..."
if [ -f requirements.txt ]; then
    pip install --upgrade pip
    pip install -r requirements.txt
else
    print_error "requirements.txt未找到"
    exit 1
fi

# 配置环境变量
print_info "配置环境变量..."
if [ ! -f .env ]; then
    if [ -f "$PROJECT_DIR/config/env.example" ]; then
        cp "$PROJECT_DIR/config/env.example" .env
        
        # 生成随机密钥
        SECRET_KEY=$(openssl rand -hex 32)
        sed -i "s/your-secret-key-change-this-in-production-use-openssl-rand-hex-32/$SECRET_KEY/" .env
        
        # 根据存储方案修改路径
        if [[ ! $STORAGE_TYPE =~ ^[Hh][Dd][Dd]$ ]]; then
            print_info "配置SD卡存储路径..."
            sed -i "s|STORAGE_PATH=/mnt/cloud_storage/users|STORAGE_PATH=/opt/raspberrycloud/storage/users|" .env
            sed -i "s|SHARE_PATH=/mnt/cloud_storage/shares|SHARE_PATH=/opt/raspberrycloud/storage/shares|" .env
            sed -i "s|TEMP_PATH=/mnt/cloud_storage/temp|TEMP_PATH=/opt/raspberrycloud/storage/temp|" .env
            sed -i "s|BACKUP_PATH=/mnt/cloud_storage/backups|BACKUP_PATH=/opt/raspberrycloud/storage/backups|" .env
            # SD卡方案使用较小的默认配额
            sed -i "s|DEFAULT_USER_QUOTA=107374182400|DEFAULT_USER_QUOTA=21474836480|" .env
        fi
        
        print_info "环境变量已配置，请检查 /opt/raspberrycloud/.env 文件"
    else
        print_error "env.example未找到"
        exit 1
    fi
fi

# 初始化数据库
print_info "初始化数据库..."
cd /opt/raspberrycloud
source venv/bin/activate
python -c "from models import init_db; init_db()" || print_error "数据库初始化失败"

# 配置Nginx
print_info "配置Nginx..."
if [ -f "$PROJECT_DIR/config/nginx.conf" ]; then
    cp "$PROJECT_DIR/config/nginx.conf" /etc/nginx/sites-available/raspberrycloud
    ln -sf /etc/nginx/sites-available/raspberrycloud /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl restart nginx
else
    print_error "nginx.conf未找到"
fi

# 配置systemd服务
print_info "配置systemd服务..."
if [ -f "$PROJECT_DIR/config/raspberrycloud.service" ]; then
    cp "$PROJECT_DIR/config/raspberrycloud.service" /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable raspberrycloud
    systemctl start raspberrycloud
else
    print_error "raspberrycloud.service未找到"
fi

# 配置防火墙
print_info "配置防火墙..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 配置Samba
print_info "配置Samba..."
if [[ $STORAGE_TYPE =~ ^[Hh][Dd][Dd]$ ]]; then
    SMB_PATH="/mnt/cloud_storage/users"
else
    SMB_PATH="/opt/raspberrycloud/storage/users"
fi

# 添加Samba配置
cat >> /etc/samba/smb.conf << EOF

[cloud]
   comment = RaspberryCloud Storage
   path = $SMB_PATH
   browseable = yes
   writable = yes
   valid users = @cloud-users
   create mask = 0664
   directory mask = 0775
   force user = www-data
   force group = www-data
EOF

# 创建用户组
groupadd -f cloud-users
usermod -aG cloud-users www-data

# 重启Samba
systemctl restart smbd
systemctl enable smbd

# 检查服务状态
print_info "检查服务状态..."
sleep 3

echo ""
print_info "========================================="
print_info "部署完成！"
print_info "========================================="
echo ""

# 显示服务状态
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
print_info "访问地址: http://$(hostname -I | awk '{print $1}')"
print_info "默认账号: admin"
print_info "默认密码: RaspberryCloud2024!"
echo ""
print_warn "⚠️  首次登录后请立即修改默认密码！"
echo ""

print_info "常用命令:"
echo "  - 查看服务状态: sudo systemctl status raspberrycloud"
echo "  - 重启服务: sudo systemctl restart raspberrycloud"
echo "  - 查看日志: sudo journalctl -u raspberrycloud -f"
echo "  - 查看Nginx日志: sudo tail -f /var/log/nginx/raspberrycloud_error.log"
echo ""

print_info "下一步:"
echo "  1. 访问Web界面并登录"
echo "  2. 修改默认管理员密码"
echo "  3. 查看文档配置HTTPS和外网访问: docs/03-多端访问配置.md"
echo ""

