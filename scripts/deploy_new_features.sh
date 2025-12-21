#!/bin/bash

# 新功能部署脚本
# 部署4大新功能：批量操作、拖拽上传、二维码分享、网格视图

echo "=========================================="
echo "  RaspberryCloud 新功能部署脚本"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检查是否在正确的目录
if [ ! -f "backend/main.py" ]; then
    echo -e "${RED}错误：请在项目根目录运行此脚本${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/6] 检查新文件...${NC}"
NEW_FILES=(
    "frontend/js/batch-operations.js"
    "frontend/js/drag-upload.js"
    "frontend/js/grid-view.js"
    "frontend/js/qrcode-share.js"
)

for file in "${NEW_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file ${RED}(缺失)${NC}"
        exit 1
    fi
done

echo ""
echo -e "${YELLOW}[2/6] 复制前端文件到生产环境...${NC}"
sudo cp -r frontend/* /var/www/raspberrycloud/
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 前端文件复制完成${NC}"
else
    echo -e "${RED}✗ 前端文件复制失败${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}[3/6] 设置文件权限...${NC}"
sudo chown -R www-data:www-data /var/www/raspberrycloud
sudo chmod -R 755 /var/www/raspberrycloud
echo -e "${GREEN}✓ 权限设置完成${NC}"

echo ""
echo -e "${YELLOW}[4/6] 重启后端服务...${NC}"
sudo systemctl restart raspberrycloud
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 后端服务重启成功${NC}"
else
    echo -e "${RED}✗ 后端服务重启失败${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}[5/6] 检查服务状态...${NC}"
sleep 2
sudo systemctl is-active --quiet raspberrycloud
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 服务运行正常${NC}"
else
    echo -e "${RED}✗ 服务未正常运行${NC}"
    sudo systemctl status raspberrycloud
    exit 1
fi

echo ""
echo -e "${YELLOW}[6/6] 验证新功能文件...${NC}"
PROD_FILES=(
    "/var/www/raspberrycloud/js/batch-operations.js"
    "/var/www/raspberrycloud/js/drag-upload.js"
    "/var/www/raspberrycloud/js/grid-view.js"
    "/var/www/raspberrycloud/js/qrcode-share.js"
)

for file in "${PROD_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $(basename $file)"
    else
        echo -e "${RED}✗${NC} $(basename $file) ${RED}(生产环境缺失)${NC}"
    fi
done

echo ""
echo "=========================================="
echo -e "${GREEN}  ✓ 新功能部署完成！${NC}"
echo "=========================================="
echo ""
echo "已部署的新功能："
echo "  ✅ 批量操作（多选 + 批量下载/删除）"
echo "  ✅ 拖拽上传"
echo "  ✅ 二维码分享"
echo "  ✅ 网格视图切换"
echo ""
echo "使用说明："
echo "  1. 刷新浏览器（Ctrl+F5 或 Cmd+Shift+R）"
echo "  2. 查看《新功能使用指南.md》了解详情"
echo "  3. 体验新功能！"
echo ""
echo "测试建议："
echo "  • 测试批量选择和下载"
echo "  • 尝试拖拽文件上传"
echo "  • 创建分享并查看二维码"
echo "  • 切换网格/列表视图"
echo ""



