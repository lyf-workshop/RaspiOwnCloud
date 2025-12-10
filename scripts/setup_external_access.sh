#!/bin/bash
#
# 外网访问配置脚本
# 自动配置端口转发、DDNS、HTTPS
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    print_error "此脚本需要root权限运行"
    echo "请使用: sudo bash setup_external_access.sh"
    exit 1
fi

print_info "========================================="
print_info "RaspberryCloud 外网访问配置"
print_info "========================================="
echo ""

# 步骤1：检查公网IP
print_step "步骤1: 检查公网IP"
PUBLIC_IP=$(curl -s ip.sb || curl -s ifconfig.me)
print_info "当前公网IP: $PUBLIC_IP"

# 检查是否为内网IP
if [[ $PUBLIC_IP =~ ^10\. ]] || [[ $PUBLIC_IP =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ $PUBLIC_IP =~ ^192\.168\. ]]; then
    print_error "检测到内网IP，需要联系运营商申请公网IP"
    exit 1
fi

echo ""
read -p "这是你的公网IP吗? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    read -p "请输入你的公网IP: " PUBLIC_IP
fi

# 步骤2：获取树莓派内网IP
print_step "步骤2: 获取树莓派内网IP"
LOCAL_IP=$(hostname -I | awk '{print $1}')
print_info "树莓派内网IP: $LOCAL_IP"

# 步骤3：配置端口转发提示
print_step "步骤3: 配置路由器端口转发"
echo ""
print_warn "请手动在路由器中配置端口转发："
echo ""
echo "  规则1:"
echo "    外部端口: 8080"
echo "    内部IP: $LOCAL_IP"
echo "    内部端口: 80"
echo "    协议: TCP"
echo ""
echo "  规则2:"
echo "    外部端口: 8443"
echo "    内部IP: $LOCAL_IP"
echo "    内部端口: 443"
echo "    协议: TCP"
echo ""
read -p "端口转发配置完成后，按回车继续..."

# 步骤4：配置DDNS
print_step "步骤4: 配置动态DNS (DDNS)"
echo ""
read -p "是否配置DDNS? (如果没有固定IP，建议配置) (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "DDNS服务商选择:"
    echo "  1. DuckDNS (免费，推荐)"
    echo "  2. No-IP (免费)"
    echo "  3. 花生壳 (免费/付费)"
    echo "  4. 跳过"
    read -p "请选择 (1-4): " DDNS_CHOICE
    
    case $DDNS_CHOICE in
        1)
            print_info "配置 DuckDNS..."
            read -p "请输入你的DuckDNS域名 (如: mycloud.duckdns.org): " DDNS_DOMAIN
            read -p "请输入你的DuckDNS Token: " DDNS_TOKEN
            
            # 创建更新脚本
            cat > /opt/raspberrycloud/scripts/update_ddns.sh << EOF
#!/bin/bash
DOMAIN="$DDNS_DOMAIN"
TOKEN="$DDNS_TOKEN"
curl -s "https://www.duckdns.org/update?domains=\$DOMAIN&token=\$TOKEN&ip="
EOF
            chmod +x /opt/raspberrycloud/scripts/update_ddns.sh
            
            # 添加到定时任务
            (crontab -l 2>/dev/null | grep -v update_ddns.sh; echo "*/5 * * * * /opt/raspberrycloud/scripts/update_ddns.sh") | crontab -
            
            # 立即执行一次
            /opt/raspberrycloud/scripts/update_ddns.sh
            
            print_info "DuckDNS配置完成"
            DOMAIN=$DDNS_DOMAIN
            ;;
        2)
            print_warn "No-IP配置需要手动安装客户端"
            print_info "参考文档: docs/03-多端访问配置.md"
            read -p "请输入你的域名: " DOMAIN
            ;;
        3)
            print_warn "花生壳配置需要手动安装客户端"
            print_info "参考文档: docs/03-多端访问配置.md"
            read -p "请输入你的域名: " DOMAIN
            ;;
        *)
            read -p "请输入你的域名 (或直接使用IP): " DOMAIN
            ;;
    esac
else
    read -p "请输入你的域名 (或直接使用IP): " DOMAIN
fi

# 步骤5：配置HTTPS
print_step "步骤5: 配置HTTPS (Let's Encrypt)"
echo ""

if [[ $DOMAIN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_warn "检测到IP地址，无法申请SSL证书"
    print_warn "建议使用域名配置HTTPS"
    USE_HTTPS=false
else
    read -p "是否配置HTTPS? (推荐) (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        USE_HTTPS=true
        
        # 安装Certbot
        print_info "安装Certbot..."
        apt install -y certbot python3-certbot-nginx
        
        # 修改Nginx配置
        print_info "更新Nginx配置..."
        sed -i "s/server_name _;/server_name $DOMAIN www.$DOMAIN;/" /etc/nginx/sites-available/raspberrycloud
        
        # 测试配置
        nginx -t
        
        # 申请证书
        print_info "申请SSL证书..."
        print_warn "请确保域名已正确解析到 $PUBLIC_IP"
        read -p "域名解析正确吗? (y/n) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN --redirect
            
            if [ $? -eq 0 ]; then
                print_info "✅ SSL证书申请成功"
            else
                print_error "SSL证书申请失败"
                print_warn "请手动运行: sudo certbot --nginx -d $DOMAIN"
            fi
        else
            print_warn "请先配置域名解析，然后运行:"
            echo "  sudo certbot --nginx -d $DOMAIN"
        fi
    else
        USE_HTTPS=false
    fi
fi

# 步骤6：更新防火墙
print_step "步骤6: 更新防火墙规则"
print_info "添加端口规则..."

if [ "$USE_HTTPS" = true ]; then
    ufw allow 80/tcp
    ufw allow 443/tcp
else
    ufw allow 8080/tcp
    ufw allow 8443/tcp
fi

# 步骤7：安装Fail2ban
print_step "步骤7: 安装Fail2ban (安全加固)"
read -p "是否安装Fail2ban防暴力破解? (推荐) (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    apt install -y fail2ban
    
    # 创建配置
    if [ ! -f /etc/fail2ban/jail.local ]; then
        cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    fi
    
    # 添加nginx配置
    cat >> /etc/fail2ban/jail.local << EOF

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/raspberrycloud_error.log
maxretry = 5
EOF
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    print_info "✅ Fail2ban已安装并启动"
fi

# 完成
echo ""
print_info "========================================="
print_info "配置完成！"
print_info "========================================="
echo ""

if [ "$USE_HTTPS" = true ]; then
    print_info "访问地址:"
    echo "  HTTPS: https://$DOMAIN"
    echo "  HTTP: http://$DOMAIN (自动跳转到HTTPS)"
else
    print_info "访问地址:"
    echo "  HTTP: http://$DOMAIN:8080"
    echo "  或: http://$PUBLIC_IP:8080"
fi

echo ""
print_warn "⚠️  重要提示:"
echo "  1. 立即修改默认管理员密码"
echo "  2. 定期更新系统和软件"
echo "  3. 定期检查日志和访问记录"
echo "  4. 备份重要数据"
echo ""

print_info "测试外网访问:"
echo "  1. 使用手机4G/5G网络（关闭WiFi）"
if [ "$USE_HTTPS" = true ]; then
    echo "  2. 访问: https://$DOMAIN"
else
    echo "  2. 访问: http://$PUBLIC_IP:8080"
fi
echo ""






