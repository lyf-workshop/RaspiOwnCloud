#!/bin/bash
# FRP客户端自动安装脚本（树莓派）
# 适用于：Raspberry Pi OS (Debian-based)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_prompt() {
    echo -e "${BLUE}[?]${NC} $1"
}

echo "================================================"
echo "  FRP客户端自动安装脚本（树莓派）"
echo "  版本：v1.0"
echo "================================================"
echo ""

# 配置变量
FRP_VERSION="0.52.3"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/frp"

# 检测架构
ARCH=$(uname -m)
case $ARCH in
    aarch64|arm64)
        FRP_ARCH="arm64"
        ;;
    armv7l|armv6l)
        FRP_ARCH="arm"
        ;;
    x86_64)
        FRP_ARCH="amd64"
        ;;
    *)
        log_error "不支持的架构: $ARCH"
        exit 1
        ;;
esac

log_info "系统架构: $ARCH (FRP: $FRP_ARCH)"

# 获取配置信息
echo ""
echo "请输入FRP服务端配置信息："
echo "----------------------------"

# 服务器IP
read -p "阿里云服务器IP: " SERVER_IP
if [ -z "$SERVER_IP" ]; then
    log_error "服务器IP不能为空"
    exit 1
fi

# Token
read -p "FRP Token: " TOKEN
if [ -z "$TOKEN" ]; then
    log_error "Token不能为空"
    exit 1
fi

# 域名
read -p "您的域名 (如: piowncloud.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    log_error "域名不能为空"
    exit 1
fi

# 确认信息
echo ""
echo "请确认以下信息："
echo "----------------------------"
echo "服务器IP:  $SERVER_IP"
echo "Token:     $TOKEN"
echo "域名:      $DOMAIN"
echo ""
read -p "确认无误？(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "已取消安装"
    exit 0
fi

log_info "开始安装FRP客户端..."

# 下载FRP
log_info "下载FRP v${FRP_VERSION}..."
FRP_FILE="frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz"
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FRP_FILE}"

cd /tmp
if [ -f "$FRP_FILE" ]; then
    log_warn "发现已下载的文件，跳过下载"
else
    if ! wget -q --show-progress "$FRP_URL"; then
        log_error "下载失败"
        log_info "尝试使用国内镜像..."
        FRP_URL="https://ghproxy.com/$FRP_URL"
        if ! wget -q --show-progress "$FRP_URL"; then
            log_error "下载失败，请检查网络连接"
            exit 1
        fi
    fi
fi

# 解压
log_info "解压文件..."
tar -xzf "$FRP_FILE"
cd "frp_${FRP_VERSION}_linux_${FRP_ARCH}"

# 安装
log_info "安装FRP客户端..."
sudo mkdir -p "$CONFIG_DIR"
sudo cp frpc "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/frpc"

# 生成配置文件
log_info "生成配置文件..."
sudo tee "$CONFIG_DIR/frpc.ini" > /dev/null <<EOF
[common]
# FRP服务端地址和端口
server_addr = $SERVER_IP
server_port = 7000

# 安全Token（必须与服务端相同）
token = $TOKEN

# 性能优化
tcp_mux = true
pool_count = 5

# 心跳配置
heartbeat_interval = 30
heartbeat_timeout = 90

# HTTP代理
[raspberrycloud-http]
type = http
local_ip = 127.0.0.1
local_port = 80
custom_domains = $DOMAIN

# HTTPS代理
[raspberrycloud-https]
type = https
local_ip = 127.0.0.1
local_port = 443
custom_domains = $DOMAIN
EOF

# 创建systemd服务
log_info "创建systemd服务..."
sudo tee /etc/systemd/system/frpc.service > /dev/null <<EOF
[Unit]
Description=FRP Client Service
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
User=pi
Restart=on-failure
RestartSec=10s
ExecStart=$INSTALL_DIR/frpc -c $CONFIG_DIR/frpc.ini
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
log_info "启动FRP客户端..."
sudo systemctl daemon-reload
sudo systemctl enable frpc
sudo systemctl start frpc

# 等待启动
sleep 3

# 检查状态
if sudo systemctl is-active --quiet frpc; then
    log_info "✅ FRP客户端安装成功！"
    
    # 检查连接状态
    sleep 2
    if sudo journalctl -u frpc -n 20 | grep -q "login to server success"; then
        log_info "✅ 已成功连接到FRP服务器！"
    else
        log_warn "⚠️  客户端已启动，但可能未成功连接到服务器"
        log_info "请查看日志: sudo journalctl -u frpc -f"
    fi
else
    log_error "❌ FRP客户端启动失败"
    sudo systemctl status frpc
    exit 1
fi

# 清理
log_info "清理临时文件..."
cd /tmp
rm -rf "frp_${FRP_VERSION}_linux_${FRP_ARCH}" "$FRP_FILE"

# 显示配置信息
echo ""
echo "================================================"
echo "  🎉 安装完成！"
echo "================================================"
echo ""
echo "📋 配置信息："
echo "----------------------------"
echo "服务器IP:        $SERVER_IP"
echo "域名:            $DOMAIN"
echo "本地HTTP端口:    80"
echo "本地HTTPS端口:   443"
echo ""
echo "📁 文件位置："
echo "----------------------------"
echo "程序文件:        $INSTALL_DIR/frpc"
echo "配置文件:        $CONFIG_DIR/frpc.ini"
echo ""
echo "🔧 管理命令："
echo "----------------------------"
echo "查看状态:        sudo systemctl status frpc"
echo "启动服务:        sudo systemctl start frpc"
echo "停止服务:        sudo systemctl stop frpc"
echo "重启服务:        sudo systemctl restart frpc"
echo "查看日志:        sudo journalctl -u frpc -f"
echo ""
echo "✅ 下一步操作："
echo "----------------------------"
echo "1. 在阿里云DNS控制台配置域名解析："
echo "   记录类型: A"
echo "   主机记录: @"
echo "   记录值:   $SERVER_IP"
echo ""
echo "2. 等待DNS解析生效（5-10分钟）"
echo ""
echo "3. 测试访问: http://$DOMAIN"
echo ""
echo "4. （可选）配置HTTPS证书"
echo ""
echo "================================================"

# 保存配置
cat > ~/frp_client_config.txt <<EOF
FRP客户端配置信息
================

安装时间: $(date)
服务器IP: $SERVER_IP
域名: $DOMAIN
Token: $TOKEN

配置文件: $CONFIG_DIR/frpc.ini

测试命令:
  sudo systemctl status frpc
  sudo journalctl -u frpc -f
EOF

log_info "配置信息已保存到: ~/frp_client_config.txt"













