#!/bin/bash
# FRP服务端自动安装脚本（阿里云服务器）
# 适用于：Ubuntu 20.04/22.04, Debian 11/12

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    log_error "请使用root用户运行此脚本"
    exit 1
fi

echo "================================================"
echo "  FRP服务端自动安装脚本"
echo "  版本：v1.0"
echo "================================================"
echo ""

# 配置变量
FRP_VERSION="0.52.3"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/frp"
LOG_DIR="/var/log/frp"

# 生成随机Token
generate_token() {
    if command -v openssl &> /dev/null; then
        TOKEN=$(openssl rand -hex 16)
    else
        TOKEN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    fi
}

log_info "开始安装FRP服务端..."

# 1. 检测系统架构
log_info "检测系统架构..."
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        FRP_ARCH="amd64"
        ;;
    aarch64)
        FRP_ARCH="arm64"
        ;;
    *)
        log_error "不支持的架构: $ARCH"
        exit 1
        ;;
esac
log_info "系统架构: $ARCH (FRP: $FRP_ARCH)"

# 2. 下载FRP
log_info "下载FRP v${FRP_VERSION}..."
FRP_FILE="frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz"
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FRP_FILE}"

cd /tmp
if [ -f "$FRP_FILE" ]; then
    log_warn "发现已下载的文件，跳过下载"
else
    if ! wget -q --show-progress "$FRP_URL"; then
        log_error "下载失败，请检查网络连接"
        log_info "您也可以手动下载: $FRP_URL"
        exit 1
    fi
fi

# 3. 解压
log_info "解压文件..."
tar -xzf "$FRP_FILE"
cd "frp_${FRP_VERSION}_linux_${FRP_ARCH}"

# 4. 安装文件
log_info "安装FRP服务端..."
mkdir -p "$CONFIG_DIR" "$LOG_DIR"
cp frps "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/frps"

# 5. 生成配置文件
log_info "生成配置文件..."
generate_token

cat > "$CONFIG_DIR/frps.ini" <<EOF
[common]
# FRP服务端监听端口
bind_port = 7000

# HTTP/HTTPS虚拟主机端口
vhost_http_port = 80
vhost_https_port = 443

# 控制面板（可选）
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = $(openssl rand -hex 8)

# 安全Token（客户端需要相同的token）
token = $TOKEN

# 日志配置
log_file = $LOG_DIR/frps.log
log_level = info
log_max_days = 3

# 性能配置
max_pool_count = 50
max_ports_per_client = 0

# 认证超时
authentication_timeout = 900

# 心跳配置
heartbeat_timeout = 90
EOF

# 6. 创建systemd服务
log_info "创建systemd服务..."
cat > /etc/systemd/system/frps.service <<EOF
[Unit]
Description=FRP Server Service
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=10s
ExecStart=$INSTALL_DIR/frps -c $CONFIG_DIR/frps.ini
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 7. 启动服务
log_info "启动FRP服务..."
systemctl daemon-reload
systemctl enable frps
systemctl start frps

# 8. 等待启动
sleep 2

# 9. 检查状态
if systemctl is-active --quiet frps; then
    log_info "✅ FRP服务端安装成功！"
else
    log_error "❌ FRP服务启动失败，请检查日志"
    systemctl status frps
    exit 1
fi

# 10. 清理
log_info "清理临时文件..."
cd /tmp
rm -rf "frp_${FRP_VERSION}_linux_${FRP_ARCH}" "$FRP_FILE"

# 11. 获取公网IP
PUBLIC_IP=$(curl -s ip.sb || curl -s ifconfig.me || echo "无法获取")

# 12. 显示配置信息
echo ""
echo "================================================"
echo "  🎉 安装完成！"
echo "================================================"
echo ""
echo "📋 配置信息："
echo "----------------------------"
echo "服务器IP:        $PUBLIC_IP"
echo "FRP端口:         7000"
echo "HTTP端口:        80"
echo "HTTPS端口:       443"
echo "控制台端口:      7500"
echo ""
echo "🔑 重要信息（请记录！）："
echo "----------------------------"
echo "FRP Token:       $TOKEN"
echo ""
echo "⚠️  请将此Token保存好，配置树莓派客户端时需要使用！"
echo ""
echo "📁 文件位置："
echo "----------------------------"
echo "程序文件:        $INSTALL_DIR/frps"
echo "配置文件:        $CONFIG_DIR/frps.ini"
echo "日志文件:        $LOG_DIR/frps.log"
echo ""
echo "🔧 管理命令："
echo "----------------------------"
echo "查看状态:        systemctl status frps"
echo "启动服务:        systemctl start frps"
echo "停止服务:        systemctl stop frps"
echo "重启服务:        systemctl restart frps"
echo "查看日志:        tail -f $LOG_DIR/frps.log"
echo ""
echo "🌐 控制台访问："
echo "----------------------------"
echo "URL:             http://$PUBLIC_IP:7500"
echo "用户名:          admin"
echo "密码:            $(grep dashboard_pwd $CONFIG_DIR/frps.ini | cut -d'=' -f2 | tr -d ' ')"
echo ""
echo "⚠️  下一步操作："
echo "----------------------------"
echo "1. 确保防火墙已开放端口: 7000, 80, 443, 7500"
echo "2. 在阿里云控制台配置安全组规则"
echo "3. 在树莓派上运行: bash install_frpc.sh"
echo "4. 配置DNS解析，将域名指向: $PUBLIC_IP"
echo ""
echo "================================================"

# 保存配置到文件
cat > /root/frp_config.txt <<EOF
FRP服务端配置信息
================

安装时间: $(date)
服务器IP: $PUBLIC_IP
FRP Token: $TOKEN
控制台密码: $(grep dashboard_pwd $CONFIG_DIR/frps.ini | cut -d'=' -f2 | tr -d ' ')

配置文件: $CONFIG_DIR/frps.ini
日志文件: $LOG_DIR/frps.log
EOF

log_info "配置信息已保存到: /root/frp_config.txt"























