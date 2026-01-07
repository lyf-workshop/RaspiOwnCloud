#!/bin/bash
# HTTPS证书自动配置脚本（阿里云服务器）
# 使用Let's Encrypt免费证书

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查root权限
if [ "$EUID" -ne 0 ]; then 
    log_error "请使用root用户运行此脚本"
    exit 1
fi

echo "================================================"
echo "  Let's Encrypt HTTPS证书自动配置"
echo "================================================"
echo ""

# 获取域名
if [ -z "$1" ]; then
    read -p "请输入您的域名 (如: piowncloud.com): " DOMAIN
else
    DOMAIN=$1
fi

if [ -z "$DOMAIN" ]; then
    log_error "域名不能为空"
    exit 1
fi

# 是否配置www子域名
read -p "是否同时配置 www.$DOMAIN ? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    WWW_DOMAIN="www.$DOMAIN"
    DOMAINS="-d $DOMAIN -d $WWW_DOMAIN"
else
    DOMAINS="-d $DOMAIN"
fi

# 获取邮箱
read -p "请输入您的邮箱 (用于证书到期提醒): " EMAIL
if [ -z "$EMAIL" ]; then
    log_warn "未提供邮箱，将使用--register-unsafely-without-email选项"
    EMAIL_OPT="--register-unsafely-without-email"
else
    EMAIL_OPT="--email $EMAIL"
fi

# 安装certbot
log_info "检查certbot..."
if ! command -v certbot &> /dev/null; then
    log_info "安装certbot..."
    apt update
    apt install -y certbot
fi

# 检查DNS解析
log_info "检查DNS解析..."
RESOLVED_IP=$(dig +short $DOMAIN | tail -n1)
PUBLIC_IP=$(curl -s ip.sb || curl -s ifconfig.me)

if [ "$RESOLVED_IP" != "$PUBLIC_IP" ]; then
    log_warn "域名 $DOMAIN 解析到: $RESOLVED_IP"
    log_warn "服务器公网IP: $PUBLIC_IP"
    log_warn "DNS解析不匹配！证书申请可能失败"
    read -p "是否继续？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# 停止FRP服务（释放80端口）
log_info "停止FRP服务..."
if systemctl is-active --quiet frps; then
    systemctl stop frps
    FRP_WAS_RUNNING=true
else
    FRP_WAS_RUNNING=false
fi

# 申请证书
log_info "申请SSL证书..."
log_warn "这可能需要几分钟，请耐心等待..."

if certbot certonly --standalone $DOMAINS $EMAIL_OPT --agree-tos --non-interactive; then
    log_info "✅ 证书申请成功！"
else
    log_error "❌ 证书申请失败"
    
    # 重启FRP
    if [ "$FRP_WAS_RUNNING" = true ]; then
        systemctl start frps
    fi
    
    log_error "常见失败原因："
    log_error "1. DNS解析未生效或不正确"
    log_error "2. 80端口被占用"
    log_error "3. 防火墙阻止了80端口"
    log_error "4. 域名已申请过证书（速率限制）"
    exit 1
fi

# 配置证书目录权限
log_info "配置证书权限..."
chmod 755 /etc/letsencrypt/live
chmod 755 /etc/letsencrypt/archive

# 更新FRP配置
log_info "更新FRP配置..."
FRP_CONFIG="/etc/frp/frps.ini"

if [ -f "$FRP_CONFIG" ]; then
    # 确保HTTPS端口已配置
    if ! grep -q "vhost_https_port" "$FRP_CONFIG"; then
        sed -i '/vhost_http_port/a vhost_https_port = 443' "$FRP_CONFIG"
        log_info "已添加HTTPS端口配置"
    fi
fi

# 重启FRP服务
log_info "重启FRP服务..."
systemctl start frps

if systemctl is-active --quiet frps; then
    log_info "✅ FRP服务已重启"
else
    log_error "❌ FRP服务启动失败"
    systemctl status frps
    exit 1
fi

# 配置自动续期
log_info "配置自动续期..."
CRON_CMD="0 3 1 * * certbot renew --quiet --pre-hook 'systemctl stop frps' --post-hook 'systemctl start frps' >> /var/log/certbot-renew.log 2>&1"

# 检查是否已存在
if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    log_info "✅ 已设置自动续期任务"
else
    log_warn "自动续期任务已存在"
fi

# 测试续期
log_info "测试证书续期..."
if certbot renew --dry-run --pre-hook 'systemctl stop frps' --post-hook 'systemctl start frps'; then
    log_info "✅ 续期测试通过"
else
    log_warn "⚠️  续期测试失败，但不影响当前使用"
fi

# 显示证书信息
echo ""
echo "================================================"
echo "  🎉 HTTPS证书配置完成！"
echo "================================================"
echo ""
echo "📋 证书信息："
echo "----------------------------"
echo "域名:            $DOMAIN"
if [ -n "$WWW_DOMAIN" ]; then
    echo "                 $WWW_DOMAIN"
fi
echo ""
echo "证书文件:        /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
echo "私钥文件:        /etc/letsencrypt/live/$DOMAIN/privkey.pem"
echo ""
echo "有效期:          90天"
echo "自动续期:        每月1日凌晨3点"
echo ""
echo "✅ 测试访问："
echo "----------------------------"
echo "HTTP:            http://$DOMAIN"
echo "HTTPS:           https://$DOMAIN"
echo ""
echo "⚠️  重要提醒："
echo "----------------------------"
echo "1. 确保树莓派FRP客户端已配置HTTPS代理"
echo "2. 证书会在到期前30天内自动续期"
echo "3. 如遇问题，查看续期日志: /var/log/certbot-renew.log"
echo ""

# 检查树莓派配置
echo "🔧 树莓派端配置检查："
echo "----------------------------"
echo "请确保树莓派 /etc/frp/frpc.ini 包含以下配置："
echo ""
echo "[raspberrycloud-https]"
echo "type = https"
echo "local_ip = 127.0.0.1"
echo "local_port = 443"
echo "custom_domains = $DOMAIN"
echo ""
echo "如果没有，请添加后重启: sudo systemctl restart frpc"
echo ""
echo "================================================"

# 保存证书信息
cat > /root/ssl_certificate_info.txt <<EOF
SSL证书信息
===========

配置时间: $(date)
域名: $DOMAIN $([ -n "$WWW_DOMAIN" ] && echo "和 $WWW_DOMAIN")
邮箱: $EMAIL

证书文件:
  fullchain.pem: /etc/letsencrypt/live/$DOMAIN/fullchain.pem
  privkey.pem: /etc/letsencrypt/live/$DOMAIN/privkey.pem

有效期: 90天
自动续期: 每月1日凌晨3点

管理命令:
  查看证书: certbot certificates
  手动续期: certbot renew
  测试续期: certbot renew --dry-run

日志文件:
  certbot日志: /var/log/letsencrypt/letsencrypt.log
  续期日志: /var/log/certbot-renew.log
EOF

log_info "证书信息已保存到: /root/ssl_certificate_info.txt"























