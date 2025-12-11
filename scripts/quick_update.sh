#!/bin/bash
#
# 快速更新脚本（简化版 - 双文件夹部署）
# 适用于日常快速更新，不备份、不更新依赖
# 
# 架构说明：
#   更新文件夹：~/Desktop/Github/RaspiOwnCloud/ (从GitHub拉取代码)
#   生产文件夹：/opt/raspberrycloud/ (实际运行的服务)
# 
# 使用方法：
#   cd ~/Desktop/Github/RaspiOwnCloud
#   bash scripts/quick_update.sh
#

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}快速更新（双文件夹部署）${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检测更新文件夹
if [ -d "/home/pi/Desktop/Github/RaspiOwnCloud" ]; then
    UPDATE_DIR="/home/pi/Desktop/Github/RaspiOwnCloud"
elif [ -d "$HOME/Desktop/Github/RaspiOwnCloud" ]; then
    UPDATE_DIR="$HOME/Desktop/Github/RaspiOwnCloud"
else
    echo -e "${RED}[错误]${NC} 未找到更新文件夹"
    echo "请先创建更新文件夹："
    echo "  mkdir -p ~/Desktop/Github"
    echo "  cd ~/Desktop/Github"
    echo "  git clone https://github.com/lyf-workshop/RaspiOwnCloud.git"
    exit 1
fi

# 生产文件夹
PROD_DIR="/opt/raspberrycloud"

if [ ! -d "$PROD_DIR" ]; then
    echo -e "${RED}[错误]${NC} 生产文件夹不存在: $PROD_DIR"
    exit 1
fi

echo -e "${GREEN}更新文件夹:${NC} $UPDATE_DIR"
echo -e "${GREEN}生产文件夹:${NC} $PROD_DIR"
echo ""

cd "$UPDATE_DIR"

# 拉取最新代码到更新文件夹
echo -e "${GREEN}[1/5]${NC} 拉取最新代码到更新文件夹..."
git pull origin main || git pull origin master

# 更新后端文件到生产目录
echo -e "${GREEN}[2/5]${NC} 更新后端文件到生产目录..."
sudo cp -r "$UPDATE_DIR/backend"/* "$PROD_DIR/backend/"

# 更新前端文件到Web目录
echo -e "${GREEN}[3/5]${NC} 更新前端文件到Web目录..."
sudo cp -r "$UPDATE_DIR/frontend"/* /var/www/raspberrycloud/

# 设置权限
echo -e "${GREEN}[4/5]${NC} 设置权限..."
sudo chown -R www-data:www-data "$PROD_DIR"
sudo chown -R www-data:www-data /var/www/raspberrycloud

# 重启服务
echo -e "${GREEN}[5/5]${NC} 重启服务..."
sudo systemctl restart raspberrycloud

# 检查服务状态
sleep 2
echo ""
echo -e "${GREEN}========================================${NC}"
if systemctl is-active --quiet raspberrycloud; then
    echo -e "${GREEN}✅ 更新完成！服务运行正常${NC}"
else
    echo -e "${YELLOW}⚠️  服务可能未正常启动${NC}"
    echo -e "${YELLOW}查看日志：${NC}sudo journalctl -u raspberrycloud -n 50"
fi
echo -e "${GREEN}========================================${NC}"



