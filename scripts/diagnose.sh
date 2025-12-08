#!/bin/bash
#
# RaspberryCloud 诊断脚本
# 快速检查服务状态和配置
#

echo "========================================="
echo "RaspberryCloud 系统诊断"
echo "========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. 检查后端服务
echo "1. 检查后端服务状态..."
if systemctl is-active --quiet raspberrycloud; then
    echo -e "${GREEN}✓${NC} 后端服务: 运行中"
else
    echo -e "${RED}✗${NC} 后端服务: 未运行"
    echo "   查看日志: sudo journalctl -u raspberrycloud -n 50"
fi
echo ""

# 2. 检查Nginx服务
echo "2. 检查Nginx服务状态..."
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓${NC} Nginx服务: 运行中"
else
    echo -e "${RED}✗${NC} Nginx服务: 未运行"
fi
echo ""

# 3. 测试后端API（直接访问）
echo "3. 测试后端API（直接访问端口8000）..."
if curl -s http://localhost:8000/api/health > /dev/null; then
    echo -e "${GREEN}✓${NC} 后端API可访问"
    curl -s http://localhost:8000/api/health | head -1
else
    echo -e "${RED}✗${NC} 后端API无法访问"
    echo "   可能原因: 后端服务未运行或端口被占用"
fi
echo ""

# 4. 测试通过Nginx访问API
echo "4. 测试通过Nginx访问API..."
RESPONSE=$(curl -s http://localhost/api/health)
if echo "$RESPONSE" | grep -q "healthy"; then
    echo -e "${GREEN}✓${NC} Nginx代理正常"
    echo "$RESPONSE"
else
    echo -e "${RED}✗${NC} Nginx代理失败"
    echo "   返回内容: ${RESPONSE:0:100}..."
    echo "   可能原因: Nginx配置错误或后端服务未运行"
fi
echo ""

# 5. 检查端口占用
echo "5. 检查端口占用..."
if lsof -i :8000 > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} 端口8000已被占用（应该是后端服务）"
    lsof -i :8000 | head -2
else
    echo -e "${RED}✗${NC} 端口8000未被占用（后端服务可能未运行）"
fi
echo ""

# 6. 检查配置文件
echo "6. 检查配置文件..."
if [ -f "/opt/raspberrycloud/.env" ]; then
    echo -e "${GREEN}✓${NC} .env文件存在"
else
    echo -e "${YELLOW}⚠${NC} .env文件不存在"
fi

if [ -f "/etc/nginx/sites-available/raspberrycloud" ]; then
    echo -e "${GREEN}✓${NC} Nginx配置文件存在"
else
    echo -e "${RED}✗${NC} Nginx配置文件不存在"
fi
echo ""

# 7. 检查Nginx配置语法
echo "7. 检查Nginx配置语法..."
if sudo nginx -t > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Nginx配置语法正确"
else
    echo -e "${RED}✗${NC} Nginx配置语法错误"
    echo "   运行 'sudo nginx -t' 查看详细错误"
fi
echo ""

# 8. 显示IP地址
echo "8. 访问地址..."
IP=$(hostname -I | awk '{print $1}')
echo "   Web界面: http://${IP}"
echo "   后端API: http://${IP}:8000"
echo ""

# 9. 最近错误日志
echo "9. 最近的服务错误（如果有）..."
if [ -f "/var/log/raspberrycloud/backend_error.log" ]; then
    ERROR_COUNT=$(tail -20 /var/log/raspberrycloud/backend_error.log | grep -i error | wc -l)
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}⚠${NC} 发现 $ERROR_COUNT 个错误，查看:"
        echo "   sudo tail -20 /var/log/raspberrycloud/backend_error.log"
    else
        echo -e "${GREEN}✓${NC} 未发现明显错误"
    fi
fi
echo ""

echo "========================================="
echo "诊断完成"
echo "========================================="

