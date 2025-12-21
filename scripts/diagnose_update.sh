#!/bin/bash
#
# 更新诊断脚本 - 检查文件是否已更新
#

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  更新状态诊断工具${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查新增的JS文件
echo -e "${YELLOW}[检查1] 新增的JS文件${NC}"
echo ""

NEW_FILES=(
    "/var/www/raspberrycloud/js/batch-operations.js"
    "/var/www/raspberrycloud/js/drag-upload.js"
    "/var/www/raspberrycloud/js/grid-view.js"
    "/var/www/raspberrycloud/js/qrcode-share.js"
    "/var/www/raspberrycloud/js/user-settings.js"
)

for file in "${NEW_FILES[@]}"; do
    if [ -f "$file" ]; then
        size=$(ls -lh "$file" | awk '{print $5}')
        modified=$(stat -c %y "$file" 2>/dev/null || stat -f "%Sm" "$file" 2>/dev/null)
        echo -e "  ${GREEN}✓${NC} $(basename $file) - ${size} - ${modified:0:16}"
    else
        echo -e "  ${RED}✗${NC} $(basename $file) ${RED}(不存在)${NC}"
    fi
done

echo ""
echo -e "${YELLOW}[检查2] index.html 是否包含新模块${NC}"
echo ""

SEARCH_STRINGS=(
    "user-settings.js"
    "batch-operations.js"
    "drag-upload.js"
    "grid-view.js"
    "qrcode-share.js"
)

INDEX_FILE="/var/www/raspberrycloud/index.html"
if [ -f "$INDEX_FILE" ]; then
    for search in "${SEARCH_STRINGS[@]}"; do
        if grep -q "$search" "$INDEX_FILE"; then
            echo -e "  ${GREEN}✓${NC} 包含 $search"
        else
            echo -e "  ${RED}✗${NC} 缺少 $search"
        fi
    done
else
    echo -e "  ${RED}✗${NC} index.html 不存在"
fi

echo ""
echo -e "${YELLOW}[检查3] 更新文件夹的文件状态${NC}"
echo ""

UPDATE_DIR="$HOME/Desktop/Github/RaspiOwnCloud"
if [ -d "$UPDATE_DIR" ]; then
    echo -e "  更新文件夹: ${GREEN}$UPDATE_DIR${NC}"
    echo ""
    
    cd "$UPDATE_DIR"
    
    # Git状态
    echo "  Git状态:"
    git_status=$(git status --porcelain 2>/dev/null)
    if [ -z "$git_status" ]; then
        echo -e "    ${GREEN}✓${NC} 工作区干净"
    else
        echo -e "    ${YELLOW}⚠${NC}  有未提交的更改:"
        git status -s | head -5 | sed 's/^/      /'
    fi
    
    echo ""
    echo "  最后一次提交:"
    git log -1 --oneline | sed 's/^/    /'
    
    echo ""
    echo "  更新文件夹中的新文件:"
    for file in "${NEW_FILES[@]}"; do
        basename_file=$(basename "$file")
        update_file="$UPDATE_DIR/frontend/js/$basename_file"
        if [ -f "$update_file" ]; then
            size=$(ls -lh "$update_file" | awk '{print $5}')
            echo -e "    ${GREEN}✓${NC} $basename_file - $size"
        else
            echo -e "    ${RED}✗${NC} $basename_file ${RED}(不存在)${NC}"
        fi
    done
else
    echo -e "  ${RED}✗${NC} 更新文件夹不存在: $UPDATE_DIR"
fi

echo ""
echo -e "${YELLOW}[检查4] 后端服务状态${NC}"
echo ""

if systemctl is-active --quiet raspberrycloud; then
    echo -e "  ${GREEN}✓${NC} 服务运行中"
    echo "  最后重启时间:"
    systemctl status raspberrycloud | grep "Active:" | sed 's/^/    /'
else
    echo -e "  ${RED}✗${NC} 服务未运行"
fi

echo ""
echo -e "${YELLOW}[检查5] 文件修改时间对比${NC}"
echo ""

# 对比更新文件夹和生产文件夹的文件时间
compare_files=(
    "js/main.js"
    "css/style.css"
    "index.html"
)

for file in "${compare_files[@]}"; do
    update_file="$UPDATE_DIR/frontend/$file"
    prod_file="/var/www/raspberrycloud/$file"
    
    if [ -f "$update_file" ] && [ -f "$prod_file" ]; then
        update_time=$(stat -c %Y "$update_file" 2>/dev/null || stat -f %m "$update_file" 2>/dev/null)
        prod_time=$(stat -c %Y "$prod_file" 2>/dev/null || stat -f %m "$prod_file" 2>/dev/null)
        
        if [ "$update_time" -gt "$prod_time" ]; then
            echo -e "  ${YELLOW}⚠${NC}  $file - ${YELLOW}更新文件夹较新${NC}"
        elif [ "$update_time" -eq "$prod_time" ]; then
            echo -e "  ${GREEN}✓${NC} $file - 时间一致"
        else
            echo -e "  ${GREEN}✓${NC} $file - 生产环境较新或相同"
        fi
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  诊断建议${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 给出建议
missing_count=0
for file in "${NEW_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        missing_count=$((missing_count + 1))
    fi
done

if [ $missing_count -gt 0 ]; then
    echo -e "${RED}问题：${NC}有 $missing_count 个新文件缺失"
    echo ""
    echo "解决方法："
    echo "  1. 确认Windows端已提交并推送代码："
    echo "     ${YELLOW}git status${NC}  # 检查是否有未提交的文件"
    echo "     ${YELLOW}git add .${NC}"
    echo "     ${YELLOW}git commit -m \"新增功能\"${NC}"
    echo "     ${YELLOW}git push origin main${NC}"
    echo ""
    echo "  2. 在树莓派上重新运行更新脚本："
    echo "     ${YELLOW}cd ~/Desktop/Github/RaspiOwnCloud${NC}"
    echo "     ${YELLOW}bash scripts/quick_update.sh${NC}"
else
    echo -e "${GREEN}✓ 所有文件已正常部署${NC}"
    echo ""
    echo "如果浏览器看不到更新，请："
    echo "  1. 硬刷新: ${YELLOW}Ctrl + F5${NC} (Windows) 或 ${YELLOW}Cmd + Shift + R${NC} (Mac)"
    echo "  2. 清除浏览器缓存"
    echo "  3. 使用无痕模式测试"
    echo "  4. 检查浏览器控制台是否有JS错误 (F12)"
fi

echo ""

