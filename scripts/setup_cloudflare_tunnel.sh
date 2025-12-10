#!/bin/bash
#
# Cloudflare Tunnel 配置脚本
# 适用于无法直接连接路由器的情况
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
    echo "请使用: sudo bash setup_cloudflare_tunnel.sh"
    exit 1
fi

print_info "========================================="
print_info "Cloudflare Tunnel 配置"
print_info "========================================="
echo ""
print_info "Cloudflare Tunnel 可以让你："
echo "  ✅ 不需要公网IP"
echo "  ✅ 不需要端口转发"
echo "  ✅ 可以使用自己的域名"
echo "  ✅ 完全免费"
echo ""

# 步骤1：检查域名
print_step "步骤1: 输入域名信息"
read -p "请输入你的域名 (如: mycloud.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    print_error "域名不能为空"
    exit 1
fi

MAIN_DOMAIN=$(echo $DOMAIN | sed 's/^www\.//')
print_info "域名: $MAIN_DOMAIN"

# 步骤2：安装cloudflared
print_step "步骤2: 安装 cloudflared"
if ! command -v cloudflared &> /dev/null; then
    print_info "下载 cloudflared..."
    cd /tmp
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O cloudflared
    chmod +x cloudflared
    sudo mv cloudflared /usr/local/bin/
    print_info "✅ cloudflared 已安装"
else
    print_info "cloudflared 已安装"
fi

# 步骤3：登录
print_step "步骤3: 登录 Cloudflare"
print_warn "请确保："
echo "  1. 已在 Cloudflare 注册账号"
echo "  2. 已将域名添加到 Cloudflare"
echo "  3. 已将域名的DNS服务器改为Cloudflare提供的"
echo ""
read -p "准备就绪? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "打开浏览器登录 Cloudflare..."
    cloudflared tunnel login
else
    print_error "请先完成 Cloudflare 配置"
    exit 1
fi

# 步骤4：创建隧道
print_step "步骤4: 创建隧道"
TUNNEL_NAME="raspberrycloud"
print_info "创建隧道: $TUNNEL_NAME"
cloudflared tunnel create $TUNNEL_NAME

# 步骤5：配置路由
print_step "步骤5: 配置DNS路由"
print_info "配置域名路由..."
cloudflared tunnel route dns $TUNNEL_NAME $MAIN_DOMAIN
cloudflared tunnel route dns $TUNNEL_NAME www.$MAIN_DOMAIN

# 步骤6：创建配置文件
print_step "步骤6: 创建隧道配置"
TUNNEL_DIR="/etc/cloudflared"
mkdir -p $TUNNEL_DIR

# 获取隧道UUID
TUNNEL_UUID=$(cloudflared tunnel list | grep $TUNNEL_NAME | awk '{print $1}')

cat > $TUNNEL_DIR/config.yml << EOF
tunnel: $TUNNEL_UUID
credentials-file: /root/.cloudflared/$TUNNEL_UUID.json

ingress:
  - hostname: $MAIN_DOMAIN
    service: http://localhost:80
  - hostname: www.$MAIN_DOMAIN
    service: http://localhost:80
  - service: http_status:404
EOF

print_info "✅ 配置文件已创建: $TUNNEL_DIR/config.yml"

# 步骤7：创建systemd服务
print_step "步骤7: 创建系统服务"
cat > /etc/systemd/system/cloudflared.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloudflared
systemctl start cloudflared

# 检查服务状态
sleep 3
if systemctl is-active --quiet cloudflared; then
    print_info "✅ Cloudflare Tunnel 服务运行中"
else
    print_error "❌ Cloudflare Tunnel 服务启动失败"
    echo "查看日志: sudo journalctl -u cloudflared -n 50"
fi

# 完成
echo ""
print_info "========================================="
print_info "配置完成！"
print_info "========================================="
echo ""
print_info "访问地址:"
echo "  https://$MAIN_DOMAIN"
echo "  https://www.$MAIN_DOMAIN"
echo ""
print_info "服务管理:"
echo "  启动: sudo systemctl start cloudflared"
echo "  停止: sudo systemctl stop cloudflared"
echo "  状态: sudo systemctl status cloudflared"
echo "  日志: sudo journalctl -u cloudflared -f"
echo ""




