#!/bin/bash
# FRP状态检查脚本
# 用于快速检查FRP服务端和客户端状态

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检测运行环境
if [ -f /etc/frp/frps.ini ]; then
    MODE="server"
elif [ -f /etc/frp/frpc.ini ]; then
    MODE="client"
else
    echo "❌ 未检测到FRP配置文件"
    exit 1
fi

echo "========================================"
echo "  FRP 状态检查"
echo "========================================"
echo ""

if [ "$MODE" = "server" ]; then
    echo "📦 运行模式: FRP服务端"
    echo ""
    
    # 服务状态
    echo "🔧 服务状态:"
    echo "--------"
    if systemctl is-active --quiet frps; then
        echo -e "${GREEN}✅ FRP服务端运行中${NC}"
    else
        echo -e "${RED}❌ FRP服务端未运行${NC}"
    fi
    echo ""
    
    # 端口监听
    echo "🌐 端口监听:"
    echo "--------"
    ss -tunlp | grep frps || echo "未找到FRP监听端口"
    echo ""
    
    # 配置信息
    echo "⚙️  配置信息:"
    echo "--------"
    if [ -f /etc/frp/frps.ini ]; then
        echo "FRP端口: $(grep bind_port /etc/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')"
        echo "HTTP端口: $(grep vhost_http_port /etc/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')"
        echo "HTTPS端口: $(grep vhost_https_port /etc/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')"
        echo "控制台端口: $(grep dashboard_port /etc/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')"
    fi
    echo ""
    
    # 公网IP
    echo "🌍 公网IP:"
    echo "--------"
    PUBLIC_IP=$(curl -s --connect-timeout 5 ip.sb || curl -s --connect-timeout 5 ifconfig.me || echo "无法获取")
    echo "$PUBLIC_IP"
    echo ""
    
    # 最近日志
    echo "📋 最近日志 (最近10行):"
    echo "--------"
    if [ -f /var/log/frp/frps.log ]; then
        tail -n 10 /var/log/frp/frps.log
    else
        journalctl -u frps -n 10 --no-pager
    fi
    
else
    echo "📦 运行模式: FRP客户端"
    echo ""
    
    # 服务状态
    echo "🔧 服务状态:"
    echo "--------"
    if systemctl is-active --quiet frpc; then
        echo -e "${GREEN}✅ FRP客户端运行中${NC}"
    else
        echo -e "${RED}❌ FRP客户端未运行${NC}"
    fi
    echo ""
    
    # 连接状态
    echo "🔗 连接状态:"
    echo "--------"
    if journalctl -u frpc --since "10 minutes ago" | grep -q "login to server success"; then
        echo -e "${GREEN}✅ 已连接到服务器${NC}"
    else
        echo -e "${YELLOW}⚠️  未检测到连接成功日志${NC}"
    fi
    echo ""
    
    # 配置信息
    echo "⚙️  配置信息:"
    echo "--------"
    if [ -f /etc/frp/frpc.ini ]; then
        echo "服务器: $(grep server_addr /etc/frp/frpc.ini | cut -d'=' -f2 | tr -d ' ')"
        echo "端口: $(grep server_port /etc/frp/frpc.ini | cut -d'=' -f2 | tr -d ' ')"
        echo "域名: $(grep custom_domains /etc/frp/frpc.ini | head -n1 | cut -d'=' -f2 | tr -d ' ')"
    fi
    echo ""
    
    # 本地网络
    echo "🌐 本地网络:"
    echo "--------"
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo "本地IP: $LOCAL_IP"
    echo ""
    
    # 测试服务器连接
    echo "🔍 测试服务器连接:"
    echo "--------"
    SERVER_ADDR=$(grep server_addr /etc/frp/frpc.ini | cut -d'=' -f2 | tr -d ' ')
    SERVER_PORT=$(grep server_port /etc/frp/frpc.ini | cut -d'=' -f2 | tr -d ' ')
    
    if ping -c 1 -W 2 "$SERVER_ADDR" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 可以Ping通服务器${NC}"
    else
        echo -e "${RED}❌ 无法Ping通服务器${NC}"
    fi
    
    if nc -zv "$SERVER_ADDR" "$SERVER_PORT" 2>&1 | grep -q "succeeded"; then
        echo -e "${GREEN}✅ 可以连接到FRP端口${NC}"
    else
        echo -e "${RED}❌ 无法连接到FRP端口${NC}"
    fi
    echo ""
    
    # 最近日志
    echo "📋 最近日志 (最近10行):"
    echo "--------"
    journalctl -u frpc -n 10 --no-pager
fi

echo ""
echo "========================================"
echo "💡 提示:"
echo "  查看实时日志: journalctl -u frp${MODE:0:1} -f"
echo "  重启服务: systemctl restart frp${MODE:0:1}"
echo "  查看配置: cat /etc/frp/frp${MODE:0:1}.ini"
echo "========================================"


























