#!/bin/bash
#
# 从 GitHub 更新代码脚本（双文件夹部署架构）
# 
# 架构说明：
#   更新文件夹：~/Desktop/Github/RaspiOwnCloud/ (从GitHub拉取代码)
#   生产文件夹：/opt/raspberrycloud/ (实际运行的服务)
# 
# 使用方法：
#   cd ~/Desktop/Github/RaspiOwnCloud
#   sudo bash scripts/update_from_github.sh
#
# 或者直接运行：
#   sudo bash ~/Desktop/Github/RaspiOwnCloud/scripts/update_from_github.sh
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
    echo "请使用: sudo bash update_from_github.sh"
    exit 1
fi

print_info "========================================="
print_info "从 GitHub 更新代码（双文件夹部署）"
print_info "========================================="
echo ""

# 检测更新文件夹（开发目录）
if [ -d "/home/pi/Desktop/Github/RaspiOwnCloud" ]; then
    UPDATE_DIR="/home/pi/Desktop/Github/RaspiOwnCloud"
elif [ -d "$HOME/Desktop/Github/RaspiOwnCloud" ]; then
    UPDATE_DIR="$HOME/Desktop/Github/RaspiOwnCloud"
else
    print_error "未找到更新文件夹"
    echo "请先创建更新文件夹："
    echo "  mkdir -p ~/Desktop/Github"
    echo "  cd ~/Desktop/Github"
    echo "  git clone https://github.com/lyf-workshop/RaspiOwnCloud.git"
    exit 1
fi

# 生产文件夹（固定路径）
PROD_DIR="/opt/raspberrycloud"

print_info "更新文件夹: $UPDATE_DIR"
print_info "生产文件夹: $PROD_DIR"
echo ""

# 检查更新文件夹是否为Git仓库
if [ ! -d "$UPDATE_DIR/.git" ]; then
    print_error "更新文件夹不是Git仓库"
    print_error "请重新克隆项目："
    echo "  cd ~/Desktop/Github"
    echo "  git clone https://github.com/lyf-workshop/RaspiOwnCloud.git"
    exit 1
fi

# 检查生产文件夹是否存在
if [ ! -d "$PROD_DIR" ]; then
    print_error "生产文件夹不存在: $PROD_DIR"
    print_error "请先创建生产文件夹："
    echo "  sudo mkdir -p /opt/raspberrycloud"
    echo "  sudo cp -r $UPDATE_DIR/{backend,frontend,config,scripts,docs} /opt/raspberrycloud/"
    exit 1
fi

# 停止服务
print_info "停止服务..."
systemctl stop raspberrycloud 2>/dev/null || print_warn "服务未运行"

# 备份当前生产版本
print_info "备份当前生产版本..."
BACKUP_DIR="/opt/raspberrycloud_backup_$(date +%Y%m%d_%H%M%S)"
cp -r "$PROD_DIR" "$BACKUP_DIR"
print_info "备份保存在: $BACKUP_DIR"

# 备份配置文件
print_info "备份配置文件..."
if [ -f "$PROD_DIR/backend/.env" ]; then
    cp "$PROD_DIR/backend/.env" /tmp/raspberrycloud.env.backup
    print_info "已备份 .env 文件"
fi

# 拉取最新代码到更新文件夹
print_info "从 GitHub 拉取最新代码到更新文件夹..."
cd "$UPDATE_DIR"

# 保存本地修改（如果有）
if ! git diff --quiet || ! git diff --cached --quiet; then
    print_warn "检测到未提交的修改"
    echo "选项："
    echo "  1) 保存本地修改后拉取（推荐）"
    echo "  2) 丢弃本地修改，使用远程版本"
    echo "  3) 取消更新"
    read -p "请选择 (1/2/3): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[1]$ ]]; then
        git stash
        print_info "本地修改已保存到stash"
        STASHED=true
    elif [[ $REPLY =~ ^[2]$ ]]; then
        print_warn "⚠️  将丢弃所有本地修改！"
        read -p "确认继续? (yes/no): " -r
        if [[ $REPLY == "yes" ]]; then
            git reset --hard HEAD
            print_info "本地修改已丢弃"
        else
            print_info "已取消更新"
            exit 0
        fi
    else
        print_info "已取消更新"
        exit 0
    fi
fi

# 拉取代码
print_info "从远程拉取最新代码..."
git fetch origin
if git pull origin main 2>/dev/null || git pull origin master 2>/dev/null; then
    print_info "代码拉取成功"
else
    print_error "代码拉取失败，可能有冲突"
    if [ "$STASHED" = true ]; then
        print_info "恢复本地修改..."
        git stash pop || print_warn "恢复本地修改时可能有冲突，请手动解决"
    fi
    exit 1
fi

# 如果有保存的本地修改，尝试恢复
if [ "$STASHED" = true ]; then
    print_info "尝试恢复本地修改..."
    if git stash pop; then
        print_info "本地修改已恢复"
    else
        print_warn "恢复本地修改时出现冲突，请手动解决："
        print_warn "  1. 编辑冲突文件"
        print_warn "  2. 解决冲突后运行: git add . && git commit -m '解决冲突'"
    fi
fi

print_info "代码更新完成"
echo ""

# 从更新文件夹复制到生产文件夹
print_info "========================================="
print_info "部署到生产文件夹"
print_info "========================================="
echo ""

# 复制后端文件到生产目录
print_info "更新后端文件..."
if [ -d "$UPDATE_DIR/backend" ]; then
    cp -r "$UPDATE_DIR/backend"/* "$PROD_DIR/backend/"
    print_info "后端文件已更新"
else
    print_error "backend 目录不存在"
    exit 1
fi

# 复制前端文件到Web目录
print_info "更新前端文件..."
if [ -d "$UPDATE_DIR/frontend" ]; then
    mkdir -p /var/www/raspberrycloud
    cp -r "$UPDATE_DIR/frontend"/* /var/www/raspberrycloud/
    chown -R www-data:www-data /var/www/raspberrycloud
    print_info "前端文件已更新"
else
    print_error "frontend 目录不存在"
    exit 1
fi

# 复制脚本文件
print_info "更新脚本文件..."
if [ -d "$UPDATE_DIR/scripts" ]; then
    mkdir -p "$PROD_DIR/scripts"
    cp -r "$UPDATE_DIR/scripts"/* "$PROD_DIR/scripts/"
    print_info "脚本文件已更新"
fi

# 设置生产目录权限
print_info "设置生产目录权限..."
chown -R www-data:www-data "$PROD_DIR"
chmod -R 755 "$PROD_DIR"

# 恢复配置文件
if [ -f "/tmp/raspberrycloud.env.backup" ]; then
    cp /tmp/raspberrycloud.env.backup "$PROD_DIR/backend/.env"
    chown www-data:www-data "$PROD_DIR/backend/.env"
    chmod 600 "$PROD_DIR/backend/.env"
    print_info "已恢复 .env 文件"
fi

# 更新 Python 依赖
print_info "更新 Python 依赖..."
cd "$PROD_DIR/backend"
if [ -d "$PROD_DIR/venv" ]; then
    sudo -u www-data bash -c "source $PROD_DIR/venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt --upgrade"
    print_info "Python 依赖已更新"
else
    print_warn "虚拟环境不存在，跳过依赖更新"
fi

# 更新配置文件（如果需要）
if [ -f "$UPDATE_DIR/config/raspberrycloud.service" ]; then
    print_info "更新 systemd 服务配置..."
    cp "$UPDATE_DIR/config/raspberrycloud.service" /etc/systemd/system/
    systemctl daemon-reload
fi

if [ -f "$UPDATE_DIR/config/nginx.conf" ]; then
    print_info "更新 Nginx 配置..."
    cp "$UPDATE_DIR/config/nginx.conf" /etc/nginx/sites-available/raspberrycloud
    nginx -t && systemctl reload nginx
fi

# 重启服务
print_info "重启服务..."
systemctl start raspberrycloud
systemctl restart nginx

# 检查服务状态
sleep 3
print_info "检查服务状态..."
if systemctl is-active --quiet raspberrycloud; then
    print_info "✅ RaspberryCloud 服务: 运行中"
else
    print_error "❌ RaspberryCloud 服务: 未运行"
    echo "   查看日志: sudo journalctl -u raspberrycloud -n 50"
    print_warn "如需回滚，运行: sudo cp -r $BACKUP_DIR/* /opt/raspberrycloud/"
fi

if systemctl is-active --quiet nginx; then
    print_info "✅ Nginx 服务: 运行中"
else
    print_error "❌ Nginx 服务: 未运行"
fi

echo ""
print_info "========================================="
print_info "更新完成！"
print_info "========================================="
echo ""
print_info "备份位置: $BACKUP_DIR"
print_info "访问地址: http://$(hostname -I | awk '{print $1}')"
echo ""






