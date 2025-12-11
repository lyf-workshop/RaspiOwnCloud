#!/bin/bash
#
# 检查阿里云DNS配置脚本
# 用于验证配置是否正确
#

echo "========================================="
echo "阿里云DNS配置检查"
echo "========================================="
echo ""

# 检查脚本文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/update_aliyun_dns.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERROR] 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

echo "1. 检查配置文件内容："
echo "----------------------------------------"
grep -E "ALIYUN_(ACCESS_KEY_ID|ACCESS_KEY_SECRET|DOMAIN|SUBDOMAIN)" "$CONFIG_FILE" | while IFS= read -r line; do
    # 隐藏敏感信息
    if [[ $line == *"ACCESS_KEY_SECRET"* ]]; then
        echo "$line" | sed 's/="[^"]*/="***隐藏***/'
    else
        echo "$line"
    fi
done
echo ""

echo "2. 检查环境变量："
echo "----------------------------------------"
if [ -z "$ALIYUN_ACCESS_KEY_ID" ]; then
    echo "[WARN] ALIYUN_ACCESS_KEY_ID 未设置"
else
    if [[ "$ALIYUN_ACCESS_KEY_ID" == *"你的AccessKey"* ]] || [[ "$ALIYUN_ACCESS_KEY_ID" == *"你的"* ]]; then
        echo "[ERROR] ALIYUN_ACCESS_KEY_ID 还是示例值，请修改！"
    else
        echo "[OK] ALIYUN_ACCESS_KEY_ID 已设置: ${ALIYUN_ACCESS_KEY_ID:0:10}..."
    fi
fi

if [ -z "$ALIYUN_ACCESS_KEY_SECRET" ]; then
    echo "[WARN] ALIYUN_ACCESS_KEY_SECRET 未设置"
else
    if [[ "$ALIYUN_ACCESS_KEY_SECRET" == *"你的AccessKey"* ]] || [[ "$ALIYUN_ACCESS_KEY_SECRET" == *"你的"* ]]; then
        echo "[ERROR] ALIYUN_ACCESS_KEY_SECRET 还是示例值，请修改！"
    else
        echo "[OK] ALIYUN_ACCESS_KEY_SECRET 已设置: ***隐藏***"
    fi
fi

if [ -z "$ALIYUN_DOMAIN" ]; then
    echo "[WARN] ALIYUN_DOMAIN 未设置"
else
    if [[ "$ALIYUN_DOMAIN" == *"你的域名"* ]] || [[ "$ALIYUN_DOMAIN" == *"example.com"* ]]; then
        echo "[ERROR] ALIYUN_DOMAIN 还是示例值，请修改！"
    else
        echo "[OK] ALIYUN_DOMAIN 已设置: $ALIYUN_DOMAIN"
    fi
fi

if [ -z "$ALIYUN_SUBDOMAIN" ]; then
    echo "[WARN] ALIYUN_SUBDOMAIN 未设置（将使用默认值 @）"
else
    echo "[OK] ALIYUN_SUBDOMAIN 已设置: $ALIYUN_SUBDOMAIN"
fi
echo ""

echo "3. 配置检查结果："
echo "----------------------------------------"

# 检查配置文件中是否有示例值
if grep -q "你的AccessKey\|你的域名\|example.com" "$CONFIG_FILE"; then
    echo "[ERROR] 配置文件中还有示例值，请修改以下行："
    echo ""
    echo "编辑文件: nano $CONFIG_FILE"
    echo ""
    echo "需要修改的行："
    grep -n "你的AccessKey\|你的域名\|example.com" "$CONFIG_FILE" | while IFS= read -r line; do
        echo "  $line"
    done
    echo ""
    exit 1
else
    echo "[OK] 配置文件格式正确"
fi

# 检查环境变量是否从配置文件加载
if [ -z "$ALIYUN_ACCESS_KEY_ID" ] || [ -z "$ALIYUN_ACCESS_KEY_SECRET" ] || [ -z "$ALIYUN_DOMAIN" ]; then
    echo "[WARN] 环境变量未设置，请确保："
    echo "  1. 已修改 $CONFIG_FILE 中的配置"
    echo "  2. 运行脚本时使用: bash $CONFIG_FILE"
    echo "  或"
    echo "  3. 手动设置环境变量后运行Python脚本"
    echo ""
fi

echo ""
echo "========================================="
echo "配置检查完成"
echo "========================================="

