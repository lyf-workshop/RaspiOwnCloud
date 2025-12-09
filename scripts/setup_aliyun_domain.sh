#!/bin/bash
#
# 阿里云域名配置脚本
# 自动配置域名解析和HTTPS
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
    echo "请使用: sudo bash setup_aliyun_domain.sh"
    exit 1
fi

print_info "========================================="
print_info "阿里云域名配置脚本"
print_info "========================================="
echo ""

# 步骤1：获取域名信息
print_step "步骤1: 输入域名信息"
read -p "请输入你的域名 (如: mycloud.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    print_error "域名不能为空"
    exit 1
fi

# 提取主域名（去掉www）
MAIN_DOMAIN=$(echo $DOMAIN | sed 's/^www\.//')

print_info "主域名: $MAIN_DOMAIN"
print_info "完整域名: $MAIN_DOMAIN 和 www.$MAIN_DOMAIN"

# 步骤2：获取公网IP
print_step "步骤2: 获取公网IP"
PUBLIC_IP=$(curl -s ip.sb || curl -s ifconfig.me)
print_info "当前公网IP: $PUBLIC_IP"

read -p "这是你的公网IP吗? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    read -p "请输入你的公网IP: " PUBLIC_IP
fi

# 步骤3：验证域名解析
print_step "步骤3: 验证域名解析"
print_warn "请确保已在阿里云配置DNS解析："
echo ""
echo "  记录类型: A"
echo "  主机记录: @"
echo "  记录值: $PUBLIC_IP"
echo ""
echo "  记录类型: A"
echo "  主机记录: www"
echo "  记录值: $PUBLIC_IP"
echo ""

read -p "DNS解析已配置完成? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "请先配置DNS解析，然后重新运行脚本"
    exit 1
fi

# 等待DNS传播
print_info "等待DNS解析生效（检查中）..."
sleep 5

# 验证解析
RESOLVED_IP=$(nslookup $MAIN_DOMAIN | grep -A 1 "Name:" | tail -1 | awk '{print $2}' || echo "")

if [ -z "$RESOLVED_IP" ]; then
    print_warn "无法验证DNS解析，可能还在传播中"
    print_warn "继续配置，如果证书申请失败，请等待DNS生效后重试"
else
    if [ "$RESOLVED_IP" = "$PUBLIC_IP" ]; then
        print_info "✅ DNS解析正确: $MAIN_DOMAIN → $PUBLIC_IP"
    else
        print_warn "DNS解析可能不正确: $MAIN_DOMAIN → $RESOLVED_IP (期望: $PUBLIC_IP)"
        print_warn "继续配置，如果证书申请失败，请检查DNS设置"
    fi
fi

# 步骤4：配置路由器端口转发提示
print_step "步骤4: 配置路由器端口转发"
LOCAL_IP=$(hostname -I | awk '{print $1}')
print_info "树莓派内网IP: $LOCAL_IP"

echo ""
print_warn "请在路由器中配置端口转发："
echo ""
echo "  规则1:"
echo "    外部端口: 80"
echo "    内部IP: $LOCAL_IP"
echo "    内部端口: 80"
echo "    协议: TCP"
echo ""
echo "  规则2:"
echo "    外部端口: 443"
echo "    内部IP: $LOCAL_IP"
echo "    内部端口: 443"
echo "    协议: TCP"
echo ""
print_warn "如果运营商封禁80/443端口，使用8080/8443端口"
read -p "端口转发配置完成后，按回车继续..."

# 步骤5：更新Nginx配置
print_step "步骤5: 更新Nginx配置"
print_info "更新server_name为: $MAIN_DOMAIN www.$MAIN_DOMAIN"

# 备份配置
cp /etc/nginx/sites-available/raspberrycloud /etc/nginx/sites-available/raspberrycloud.backup.$(date +%Y%m%d_%H%M%S)

# 更新server_name
sed -i "s/server_name _;/server_name $MAIN_DOMAIN www.$MAIN_DOMAIN;/" /etc/nginx/sites-available/raspberrycloud

# 测试配置
if nginx -t; then
    print_info "✅ Nginx配置正确"
    systemctl reload nginx
else
    print_error "Nginx配置错误，已恢复备份"
    exit 1
fi

# 步骤6：配置HTTPS
print_step "步骤6: 配置HTTPS (Let's Encrypt)"
read -p "是否配置HTTPS? (强烈推荐) (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 安装Certbot
    if ! command -v certbot &> /dev/null; then
        print_info "安装Certbot..."
        apt update
        apt install -y certbot python3-certbot-nginx
    fi
    
    # 申请证书
    print_info "申请SSL证书..."
    print_warn "请确保:"
    echo "  1. 域名已正确解析到 $PUBLIC_IP"
    echo "  2. 80端口已映射并可访问"
    echo "  3. 防火墙已开放80端口"
    echo ""
    
    read -p "准备就绪，开始申请证书? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 获取邮箱
        read -p "请输入邮箱地址（用于证书到期提醒）: " EMAIL
        
        # 申请证书
        certbot --nginx -d $MAIN_DOMAIN -d www.$MAIN_DOMAIN \
            --non-interactive \
            --agree-tos \
            --email "$EMAIL" \
            --redirect
        
        if [ $? -eq 0 ]; then
            print_info "✅ SSL证书申请成功"
            
            # 设置自动续期
            print_info "设置证书自动续期..."
            (crontab -l 2>/dev/null | grep -v "certbot renew"; echo "0 3 1 * * certbot renew --quiet && systemctl reload nginx") | crontab -
            print_info "✅ 自动续期已配置"
        else
            print_error "SSL证书申请失败"
            print_warn "可能原因:"
            echo "  1. 域名未正确解析"
            echo "  2. 80端口无法访问"
            echo "  3. 防火墙阻止"
            echo ""
            print_info "请检查后手动运行:"
            echo "  sudo certbot --nginx -d $MAIN_DOMAIN -d www.$MAIN_DOMAIN"
        fi
    fi
else
    print_warn "跳过HTTPS配置"
fi

# 步骤7：更新防火墙
print_step "步骤7: 更新防火墙规则"
print_info "添加端口规则..."
ufw allow 80/tcp
ufw allow 443/tcp
print_info "✅ 防火墙规则已更新"

# 步骤8：验证配置
print_step "步骤8: 验证配置"
echo ""
print_info "配置完成！"
echo ""
print_info "========================================="
print_info "访问信息"
print_info "========================================="
echo ""
print_info "访问地址:"
echo "  HTTPS: https://$MAIN_DOMAIN"
echo "  HTTP: http://$MAIN_DOMAIN (如果配置了HTTPS会自动跳转)"
echo ""
print_info "测试命令:"
echo "  # 验证DNS解析"
echo "  nslookup $MAIN_DOMAIN"
echo ""
echo "  # 测试HTTP访问"
echo "  curl http://$MAIN_DOMAIN/api/health"
echo ""
echo "  # 测试HTTPS访问"
echo "  curl https://$MAIN_DOMAIN/api/health"
echo ""
print_warn "⚠️  重要提示:"
echo "  1. 立即修改默认管理员密码"
echo "  2. 使用手机4G网络测试外网访问"
echo "  3. 检查浏览器地址栏是否有锁图标 🔒"
echo ""




