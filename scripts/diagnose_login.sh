#!/bin/bash
# 登录问题诊断脚本
# 检查所有可能导致登录JSON错误的原因

echo "========================================"
echo "RaspberryCloud 登录问题诊断"
echo "========================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 检查后端服务状态
echo "1️⃣  检查后端服务状态..."
echo "---"
if systemctl is-active --quiet raspberrycloud; then
    echo -e "${GREEN}✅ RaspberryCloud后端服务运行中${NC}"
    
    # 检查端口监听
    if sudo netstat -tlnp 2>/dev/null | grep -q ":8000"; then
        echo -e "${GREEN}✅ 后端端口8000正在监听${NC}"
    else
        echo -e "${RED}❌ 后端端口8000未监听${NC}"
    fi
else
    echo -e "${RED}❌ RaspberryCloud后端服务未运行${NC}"
    echo -e "${YELLOW}   尝试启动: sudo systemctl start raspberrycloud${NC}"
fi
echo ""

# 2. 测试后端API直连
echo "2️⃣  测试后端API直连 (localhost:8000)..."
echo "---"
response=$(curl -s -w "\n%{http_code}" http://localhost:8000/api/health 2>/dev/null)
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ 后端API响应正常${NC}"
    echo "   响应内容: $body"
else
    echo -e "${RED}❌ 后端API无响应或错误 (HTTP $http_code)${NC}"
    echo "   响应内容: $body"
fi
echo ""

# 3. 检查Nginx状态
echo "3️⃣  检查Nginx服务状态..."
echo "---"
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx服务运行中${NC}"
    
    # 检查端口监听
    if sudo netstat -tlnp 2>/dev/null | grep -q ":80"; then
        echo -e "${GREEN}✅ Nginx端口80正在监听${NC}"
    else
        echo -e "${RED}❌ Nginx端口80未监听${NC}"
    fi
else
    echo -e "${RED}❌ Nginx服务未运行${NC}"
    echo -e "${YELLOW}   尝试启动: sudo systemctl start nginx${NC}"
fi
echo ""

# 4. 检查Nginx配置
echo "4️⃣  检查Nginx配置..."
echo "---"
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo -e "${GREEN}✅ Nginx配置文件语法正确${NC}"
else
    echo -e "${RED}❌ Nginx配置文件有错误${NC}"
    sudo nginx -t
fi

# 检查配置文件是否存在
if [ -f "/etc/nginx/sites-available/raspberrycloud" ]; then
    echo -e "${GREEN}✅ Nginx配置文件存在${NC}"
    
    # 检查是否启用
    if [ -L "/etc/nginx/sites-enabled/raspberrycloud" ]; then
        echo -e "${GREEN}✅ Nginx配置已启用${NC}"
    else
        echo -e "${RED}❌ Nginx配置未启用${NC}"
        echo -e "${YELLOW}   启用配置: sudo ln -sf /etc/nginx/sites-available/raspberrycloud /etc/nginx/sites-enabled/${NC}"
    fi
    
    # 检查location /api/配置
    if grep -q "^[[:space:]]*location /api/" /etc/nginx/sites-available/raspberrycloud; then
        echo -e "${GREEN}✅ 找到 location /api/ 配置${NC}"
        
        # 检查是否嵌套在location /内部（错误情况）
        if awk '/^[[:space:]]*location \/ {/,/^[[:space:]]*}/ {
            if (/^[[:space:]]*location \/api\//) { exit 1 }
        }' /etc/nginx/sites-available/raspberrycloud; then
            echo -e "${GREEN}✅ location /api/ 配置结构正确（不在location /内部）${NC}"
        else
            echo -e "${RED}❌ location /api/ 错误地嵌套在 location / 内部${NC}"
            echo -e "${YELLOW}   这是导致JSON错误的主要原因！${NC}"
        fi
    else
        echo -e "${RED}❌ 未找到 location /api/ 配置${NC}"
    fi
else
    echo -e "${RED}❌ Nginx配置文件不存在${NC}"
fi
echo ""

# 5. 测试Nginx代理
echo "5️⃣  测试Nginx API代理 (localhost/api)..."
echo "---"
response=$(curl -s -w "\n%{http_code}" http://localhost/api/health 2>/dev/null)
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" = "200" ]; then
    # 检查返回的是否是JSON
    if echo "$body" | grep -q "status"; then
        echo -e "${GREEN}✅ Nginx代理正常，返回JSON${NC}"
        echo "   响应内容: $body"
    else
        echo -e "${RED}❌ Nginx代理返回的不是JSON（可能是HTML）${NC}"
        echo "   响应内容前100字符: ${body:0:100}"
        echo -e "${YELLOW}   这就是导致登录JSON错误的原因！${NC}"
    fi
else
    echo -e "${RED}❌ Nginx代理无响应或错误 (HTTP $http_code)${NC}"
    echo "   响应内容: $body"
fi
echo ""

# 6. 检查前端文件
echo "6️⃣  检查前端文件..."
echo "---"
if [ -d "/var/www/raspberrycloud" ]; then
    echo -e "${GREEN}✅ 前端目录存在${NC}"
    
    if [ -f "/var/www/raspberrycloud/login.html" ]; then
        echo -e "${GREEN}✅ login.html 存在${NC}"
    else
        echo -e "${RED}❌ login.html 不存在${NC}"
    fi
    
    if [ -f "/var/www/raspberrycloud/js/config.js" ]; then
        echo -e "${GREEN}✅ config.js 存在${NC}"
        
        # 检查API_BASE_URL配置
        api_url=$(grep "API_BASE_URL" /var/www/raspberrycloud/js/config.js | head -n 1)
        echo "   API配置: $api_url"
    else
        echo -e "${RED}❌ config.js 不存在${NC}"
    fi
else
    echo -e "${RED}❌ 前端目录不存在${NC}"
fi
echo ""

# 7. 查看最近的错误日志
echo "7️⃣  查看最近的错误日志..."
echo "---"

echo "📋 Nginx错误日志（最近10行）:"
if [ -f "/var/log/nginx/raspberrycloud_error.log" ]; then
    sudo tail -n 10 /var/log/nginx/raspberrycloud_error.log 2>/dev/null || echo "   日志为空或无法读取"
else
    echo "   日志文件不存在"
fi
echo ""

echo "📋 后端服务日志（最近10行）:"
sudo journalctl -u raspberrycloud -n 10 --no-pager 2>/dev/null || echo "   无法读取日志"
echo ""

# 8. 总结和建议
echo "========================================"
echo "📊 诊断总结"
echo "========================================"
echo ""

# 统计问题
issues=0

if ! systemctl is-active --quiet raspberrycloud; then
    issues=$((issues+1))
    echo -e "${RED}⚠️  问题 $issues: 后端服务未运行${NC}"
    echo "   解决: sudo systemctl start raspberrycloud"
    echo ""
fi

if ! systemctl is-active --quiet nginx; then
    issues=$((issues+1))
    echo -e "${RED}⚠️  问题 $issues: Nginx服务未运行${NC}"
    echo "   解决: sudo systemctl start nginx"
    echo ""
fi

if ! [ -L "/etc/nginx/sites-enabled/raspberrycloud" ]; then
    issues=$((issues+1))
    echo -e "${RED}⚠️  问题 $issues: Nginx配置未启用${NC}"
    echo "   解决: sudo ln -sf /etc/nginx/sites-available/raspberrycloud /etc/nginx/sites-enabled/"
    echo "        sudo systemctl restart nginx"
    echo ""
fi

# 测试是否返回HTML而不是JSON
response=$(curl -s http://localhost/api/health 2>/dev/null)
if echo "$response" | grep -q "<html"; then
    issues=$((issues+1))
    echo -e "${RED}⚠️  问题 $issues: Nginx返回HTML而不是JSON（关键问题）${NC}"
    echo "   原因: location /api/ 配置错误或未生效"
    echo "   解决: sudo cp /home/pi/RaspiOwnCloud/config/nginx.conf /etc/nginx/sites-available/raspberrycloud"
    echo "        sudo nginx -t"
    echo "        sudo systemctl restart nginx"
    echo ""
fi

if [ $issues -eq 0 ]; then
    echo -e "${GREEN}✅ 未发现明显问题，系统应该工作正常${NC}"
    echo ""
    echo "如果仍然无法登录，请检查："
    echo "  1. 浏览器是否清除了缓存"
    echo "  2. 是否使用了正确的IP地址访问"
    echo "  3. 浏览器开发者工具(F12)中Network标签的login请求详情"
else
    echo -e "${YELLOW}📝 发现 $issues 个问题，请按照上述建议逐一解决${NC}"
fi

echo ""
echo "========================================"
echo "完成诊断"
echo "========================================"



