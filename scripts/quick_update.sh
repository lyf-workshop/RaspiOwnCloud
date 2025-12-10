#!/bin/bash
#
# 快速更新脚本（简化版）
# 适用于日常快速更新，不备份、不更新依赖
# 
# 使用方法：
#   cd ~/Desktop/Github/RaspiOwnCloud
#   bash scripts/quick_update.sh
#

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[快速更新]${NC} 开始更新..."

# 检测项目目录
if [ -d "/home/pi/Desktop/Github/RaspiOwnCloud" ]; then
    PROJECT_DIR="/home/pi/Desktop/Github/RaspiOwnCloud"
elif [ -d "$HOME/Desktop/Github/RaspiOwnCloud" ]; then
    PROJECT_DIR="$HOME/Desktop/Github/RaspiOwnCloud"
else
    echo -e "${YELLOW}[警告]${NC} 未找到项目目录，请手动指定"
    exit 1
fi

cd "$PROJECT_DIR"

# 拉取最新代码
echo -e "${GREEN}[1/4]${NC} 拉取最新代码..."
git pull origin main || git pull origin master

# 更新后端文件
echo -e "${GREEN}[2/4]${NC} 更新后端文件..."
sudo cp -r "$PROJECT_DIR/backend"/* /opt/raspberrycloud/
sudo chown -R www-data:www-data /opt/raspberrycloud

# 更新前端文件
echo -e "${GREEN}[3/4]${NC} 更新前端文件..."
sudo cp -r "$PROJECT_DIR/frontend"/* /var/www/raspberrycloud/
sudo chown -R www-data:www-data /var/www/raspberrycloud

# 重启服务
echo -e "${GREEN}[4/4]${NC} 重启服务..."
sudo systemctl restart raspberrycloud

# 检查服务状态
sleep 2
if systemctl is-active --quiet raspberrycloud; then
    echo -e "${GREEN}✅ 更新完成！服务运行正常${NC}"
else
    echo -e "${YELLOW}⚠️  服务可能未正常启动，请检查日志：${NC}"
    echo "   sudo journalctl -u raspberrycloud -n 50"
fi



