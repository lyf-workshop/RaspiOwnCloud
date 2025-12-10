#!/bin/bash
#
# 从 GitHub 更新代码脚本
# 适用于项目在 ~/Desktop/Github/RaspiOwnCloud 的情况
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
print_info "从 GitHub 更新代码"
print_info "========================================="
echo ""

# 检测项目目录
if [ -d "/home/pi/Desktop/Github/RaspiOwnCloud" ]; then
    PROJECT_DIR="/home/pi/Desktop/Github/RaspiOwnCloud"
elif [ -d "$HOME/Desktop/Github/RaspiOwnCloud" ]; then
    PROJECT_DIR="$HOME/Desktop/Github/RaspiOwnCloud"
elif [ -d "/opt/raspberrycloud" ] && [ -d "/opt/raspberrycloud/.git" ]; then
    PROJECT_DIR="/opt/raspberrycloud"
else
    read -p "请输入项目目录的完整路径: " PROJECT_DIR
    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "目录不存在: $PROJECT_DIR"
        exit 1
    fi
fi

print_info "项目目录: $PROJECT_DIR"

# 检查 Git 仓库
if [ ! -d "$PROJECT_DIR/.git" ]; then
    print_error "未检测到 Git 仓库"
    exit 1
fi

# 停止服务
print_info "停止服务..."
systemctl stop raspberrycloud 2>/dev/null || print_warn "服务未运行"

# 备份当前版本
print_info "备份当前版本..."
BACKUP_DIR="/opt/raspberrycloud_backup_$(date +%Y%m%d_%H%M%S)"
if [ -d "/opt/raspberrycloud" ]; then
    cp -r /opt/raspberrycloud "$BACKUP_DIR"
    print_info "备份保存在: $BACKUP_DIR"
fi

# 备份配置文件
print_info "备份配置文件..."
if [ -f "/opt/raspberrycloud/.env" ]; then
    cp /opt/raspberrycloud/.env /tmp/raspberrycloud.env.backup
    print_info "已备份 .env 文件"
fi

# 拉取最新代码
print_info "从 GitHub 拉取最新代码..."
cd "$PROJECT_DIR"

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

# 复制后端文件
print_info "更新后端文件..."
if [ -d "$PROJECT_DIR/backend" ]; then
    cp -r "$PROJECT_DIR/backend"/* /opt/raspberrycloud/
    chown -R www-data:www-data /opt/raspberrycloud
    print_info "后端文件已更新"
else
    print_error "backend 目录不存在"
    exit 1
fi

# 复制前端文件
print_info "更新前端文件..."
if [ -d "$PROJECT_DIR/frontend" ]; then
    cp -r "$PROJECT_DIR/frontend"/* /var/www/raspberrycloud/
    chown -R www-data:www-data /var/www/raspberrycloud
    print_info "前端文件已更新"
else
    print_error "frontend 目录不存在"
    exit 1
fi

# 恢复配置文件
if [ -f "/tmp/raspberrycloud.env.backup" ]; then
    cp /tmp/raspberrycloud.env.backup /opt/raspberrycloud/.env
    chown www-data:www-data /opt/raspberrycloud/.env
    print_info "已恢复 .env 文件"
fi

# 更新 Python 依赖
print_info "更新 Python 依赖..."
cd /opt/raspberrycloud
if [ -d "venv" ]; then
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt --upgrade
    print_info "Python 依赖已更新"
else
    print_warn "虚拟环境不存在，跳过依赖更新"
fi

# 更新配置文件（如果需要）
if [ -f "$PROJECT_DIR/config/raspberrycloud.service" ]; then
    print_info "更新 systemd 服务配置..."
    cp "$PROJECT_DIR/config/raspberrycloud.service" /etc/systemd/system/
    systemctl daemon-reload
fi

if [ -f "$PROJECT_DIR/config/nginx.conf" ]; then
    print_info "更新 Nginx 配置..."
    cp "$PROJECT_DIR/config/nginx.conf" /etc/nginx/sites-available/raspberrycloud
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






