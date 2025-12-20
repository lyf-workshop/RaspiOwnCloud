#!/bin/bash
#
# SSL证书申请前置条件检查脚本
# 用于验证DNS、端口转发、防火墙等配置是否正确
#

DOMAIN="${1:-piowncloud.com}"
WWW_DOMAIN="www.${DOMAIN}"

echo "=========================================="
echo "SSL证书申请前置条件检查"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查函数
check_dns() {
    echo "1. 检查DNS解析..."
    echo "   - 主域名: $DOMAIN"
    MAIN_IP=$(nslookup $DOMAIN 2>/dev/null | grep -A 1 "Name:" | tail -1 | awk '{print $2}' || echo "")
    
    if [ -z "$MAIN_IP" ]; then
        echo -e "   ${RED}❌ 无法解析 $DOMAIN${NC}"
        return 1
    else
        echo -e "   ${GREEN}✅ $DOMAIN → $MAIN_IP${NC}"
    fi
    
    echo "   - www子域名: $WWW_DOMAIN"
    WWW_IP=$(nslookup $WWW_DOMAIN 2>/dev/null | grep -A 1 "Name:" | tail -1 | awk '{print $2}' || echo "")
    
    if [ -z "$WWW_IP" ]; then
        echo -e "   ${YELLOW}⚠️  无法解析 $WWW_DOMAIN（如果不需要www子域名，可以忽略）${NC}"
    else
        echo -e "   ${GREEN}✅ $WWW_DOMAIN → $WWW_IP${NC}"
        
        # 检查两个域名是否指向同一IP
        if [ "$MAIN_IP" != "$WWW_IP" ]; then
            echo -e "   ${YELLOW}⚠️  主域名和www子域名指向不同IP${NC}"
        fi
    fi
    
    return 0
}

check_local_http() {
    echo ""
    echo "2. 检查本地HTTP服务..."
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302"; then
        echo -e "   ${GREEN}✅ 本地HTTP服务正常${NC}"
        return 0
    else
        echo -e "   ${RED}❌ 本地HTTP服务无法访问${NC}"
        echo "   请检查Nginx是否运行: sudo systemctl status nginx"
        return 1
    fi
}

check_nginx_config() {
    echo ""
    echo "3. 检查Nginx配置..."
    
    if [ ! -f /etc/nginx/sites-available/raspberrycloud ]; then
        echo -e "   ${RED}❌ Nginx配置文件不存在${NC}"
        return 1
    fi
    
    # 检查server_name是否包含域名
    if grep -q "server_name.*$DOMAIN" /etc/nginx/sites-available/raspberrycloud; then
        echo -e "   ${GREEN}✅ Nginx配置包含域名${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Nginx配置中未找到域名，请检查server_name${NC}"
    fi
    
    # 检查acme-challenge配置
    if grep -q "\.well-known/acme-challenge" /etc/nginx/sites-available/raspberrycloud; then
        echo -e "   ${GREEN}✅ acme-challenge路径已配置${NC}"
    else
        echo -e "   ${YELLOW}⚠️  acme-challenge路径未配置${NC}"
    fi
    
    # 测试Nginx配置语法
    if sudo nginx -t > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ Nginx配置语法正确${NC}"
        return 0
    else
        echo -e "   ${RED}❌ Nginx配置语法错误${NC}"
        echo "   运行 'sudo nginx -t' 查看详细错误"
        return 1
    fi
}

check_firewall() {
    echo ""
    echo "4. 检查防火墙..."
    
    if command -v ufw > /dev/null 2>&1; then
        UFW_STATUS=$(sudo ufw status | head -1)
        if echo "$UFW_STATUS" | grep -q "Status: active"; then
            if sudo ufw status | grep -q "80/tcp\|443/tcp"; then
                echo -e "   ${GREEN}✅ UFW已开放80和443端口${NC}"
            else
                echo -e "   ${YELLOW}⚠️  UFW未开放80和443端口${NC}"
                echo "   运行: sudo ufw allow 80/tcp && sudo ufw allow 443/tcp"
            fi
        else
            echo -e "   ${GREEN}✅ UFW未启用（或已允许所有流量）${NC}"
        fi
    else
        echo -e "   ${YELLOW}⚠️  未检测到UFW，请手动检查防火墙${NC}"
    fi
}

check_certbot_dir() {
    echo ""
    echo "5. 检查certbot目录..."
    
    if [ -d /var/www/certbot ]; then
        echo -e "   ${GREEN}✅ certbot目录存在${NC}"
        
        # 检查权限
        if [ -w /var/www/certbot ]; then
            echo -e "   ${GREEN}✅ certbot目录可写${NC}"
        else
            echo -e "   ${YELLOW}⚠️  certbot目录权限可能不正确${NC}"
            echo "   运行: sudo chown -R www-data:www-data /var/www/certbot"
        fi
    else
        echo -e "   ${YELLOW}⚠️  certbot目录不存在${NC}"
        echo "   运行: sudo mkdir -p /var/www/certbot && sudo chown -R www-data:www-data /var/www/certbot"
    fi
}

check_external_access() {
    echo ""
    echo "6. 检查外网访问（需要从外网测试）..."
    echo -e "   ${YELLOW}⚠️  此检查需要从外网（如手机4G）访问${NC}"
    echo "   请在手机浏览器或外网电脑上访问："
    echo "   - http://$DOMAIN"
    echo "   - http://$WWW_DOMAIN"
    echo ""
    echo "   如果无法访问，请检查："
    echo "   1. Windows端口转发是否配置（80和443端口）"
    echo "   2. Windows防火墙是否允许这些端口"
    echo "   3. DNS是否已完全传播（等待10-30分钟）"
}

# 执行检查
ALL_OK=true

check_dns || ALL_OK=false
check_local_http || ALL_OK=false
check_nginx_config || ALL_OK=false
check_firewall
check_certbot_dir
check_external_access

echo ""
echo "=========================================="
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}✅ 基本检查通过！${NC}"
    echo ""
    echo "下一步："
    echo "1. 确认外网可以访问 http://$DOMAIN"
    echo "2. 如果www子域名也需要证书，确认外网可以访问 http://$WWW_DOMAIN"
    echo "3. 运行: sudo certbot --nginx -d $DOMAIN -d $WWW_DOMAIN"
else
    echo -e "${RED}❌ 部分检查失败，请先修复上述问题${NC}"
    echo ""
    echo "修复后重新运行此脚本检查"
fi
echo "=========================================="












