#!/bin/bash
#
# 增强版快速更新脚本 - 带验证功能
# 确保每一步都成功执行
#

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  增强版快速更新（带验证）${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检测更新文件夹
if [ -d "/home/pi/Desktop/Github/RaspiOwnCloud" ]; then
    UPDATE_DIR="/home/pi/Desktop/Github/RaspiOwnCloud"
elif [ -d "$HOME/Desktop/Github/RaspiOwnCloud" ]; then
    UPDATE_DIR="$HOME/Desktop/Github/RaspiOwnCloud"
else
    echo -e "${RED}[错误]${NC} 未找到更新文件夹"
    exit 1
fi

PROD_DIR="/opt/raspberrycloud"
WEB_DIR="/var/www/raspberrycloud"

echo -e "${GREEN}更新文件夹:${NC} $UPDATE_DIR"
echo -e "${GREEN}生产文件夹:${NC} $PROD_DIR"
echo -e "${GREEN}Web文件夹:${NC} $WEB_DIR"
echo ""

cd "$UPDATE_DIR"

# 步骤1: 拉取最新代码
echo -e "${YELLOW}[1/7]${NC} 拉取最新代码..."
BEFORE_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
git pull origin main || git pull origin master
AFTER_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

if [ "$BEFORE_COMMIT" = "$AFTER_COMMIT" ]; then
    echo -e "  ${YELLOW}⚠${NC}  代码已是最新（没有新提交）"
else
    echo -e "  ${GREEN}✓${NC} 拉取成功"
    echo "  最新提交: $(git log -1 --oneline)"
fi
echo ""

# 步骤2: 验证关键文件存在
echo -e "${YELLOW}[2/7]${NC} 验证关键文件..."
REQUIRED_FILES=(
    "frontend/js/batch-operations.js"
    "frontend/js/drag-upload.js"
    "frontend/js/grid-view.js"
    "frontend/js/qrcode-share.js"
    "frontend/js/user-settings.js"
    "frontend/index.html"
    "frontend/css/style.css"
)

missing_files=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$UPDATE_DIR/$file" ]; then
        echo -e "  ${GREEN}✓${NC} $(basename $file)"
    else
        echo -e "  ${RED}✗${NC} $(basename $file) ${RED}缺失${NC}"
        missing_files=$((missing_files + 1))
    fi
done

if [ $missing_files -gt 0 ]; then
    echo -e "${RED}错误: 有 $missing_files 个必需文件缺失${NC}"
    echo "请检查Windows端是否已提交并推送所有文件"
    exit 1
fi
echo ""

# 步骤3: 更新后端文件
echo -e "${YELLOW}[3/7]${NC} 更新后端文件..."
sudo cp -r "$UPDATE_DIR/backend"/* "$PROD_DIR/backend/"
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} 后端文件已更新"
else
    echo -e "  ${RED}✗${NC} 后端文件更新失败"
    exit 1
fi
echo ""

# 步骤4: 更新前端文件
echo -e "${YELLOW}[4/7]${NC} 更新前端文件..."
sudo cp -r "$UPDATE_DIR/frontend"/* "$WEB_DIR/"
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} 前端文件已更新"
else
    echo -e "  ${RED}✗${NC} 前端文件更新失败"
    exit 1
fi
echo ""

# 步骤5: 验证生产环境文件
echo -e "${YELLOW}[5/7]${NC} 验证生产环境文件..."
prod_missing=0
for file in "${REQUIRED_FILES[@]}"; do
    # 只检查frontend文件
    if [[ $file == frontend/* ]]; then
        prod_file="$WEB_DIR/${file#frontend/}"
        if [ -f "$prod_file" ]; then
            echo -e "  ${GREEN}✓${NC} $(basename $prod_file)"
        else
            echo -e "  ${RED}✗${NC} $(basename $prod_file) ${RED}未部署${NC}"
            prod_missing=$((prod_missing + 1))
        fi
    fi
done

if [ $prod_missing -gt 0 ]; then
    echo -e "${RED}警告: 有 $prod_missing 个文件未成功部署${NC}"
fi
echo ""

# 步骤6: 设置权限
echo -e "${YELLOW}[6/7]${NC} 设置权限..."
sudo chown -R www-data:www-data "$PROD_DIR"
sudo chown -R www-data:www-data "$WEB_DIR"
sudo chmod -R 755 "$WEB_DIR"
echo -e "  ${GREEN}✓${NC} 权限已设置"
echo ""

# 步骤7: 重启服务
echo -e "${YELLOW}[7/7]${NC} 重启服务..."
sudo systemctl restart raspberrycloud
sleep 2

# 检查服务状态
echo ""
echo -e "${BLUE}========================================${NC}"
if systemctl is-active --quiet raspberrycloud; then
    echo -e "${GREEN}✅ 更新成功！服务运行正常${NC}"
    echo ""
    echo "验证要点："
    echo -e "  ${GREEN}✓${NC} 代码已拉取"
    echo -e "  ${GREEN}✓${NC} 文件已更新"
    echo -e "  ${GREEN}✓${NC} 服务已重启"
    echo ""
    echo "下一步："
    echo "  1. 在浏览器中按 Ctrl+F5 强制刷新"
    echo "  2. 检查右上角用户菜单是否有'设置'选项"
    echo "  3. 检查文件前是否有复选框"
    echo "  4. 尝试拖拽上传文件"
else
    echo -e "${RED}❌ 服务未正常启动${NC}"
    echo ""
    echo "查看日志："
    echo "  sudo journalctl -u raspberrycloud -n 50"
fi
echo -e "${BLUE}========================================${NC}"
echo ""

# 显示部署的文件大小
echo "部署文件统计："
for file in "${REQUIRED_FILES[@]}"; do
    if [[ $file == frontend/* ]]; then
        prod_file="$WEB_DIR/${file#frontend/}"
        if [ -f "$prod_file" ]; then
            size=$(ls -lh "$prod_file" | awk '{print $5}')
            echo "  $(basename $prod_file): $size"
        fi
    fi
done
echo ""

