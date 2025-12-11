#!/bin/bash
#
# 阿里云DNS配置向导
# 交互式配置脚本，帮助用户正确设置AccessKey和域名
#

echo "========================================="
echo "阿里云DNS自动更新 - 配置向导"
echo "========================================="
echo ""

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/update_aliyun_dns.sh"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERROR] 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

echo "此向导将帮助您配置阿里云DNS自动更新脚本。"
echo ""
echo "需要准备的信息："
echo "  1. 阿里云 AccessKey ID"
echo "  2. 阿里云 AccessKey Secret"
echo "  3. 您的域名（例如: piowncloud.com）"
echo "  4. 子域名（@ 表示主域名，www 表示www子域名）"
echo ""

# 读取当前配置（如果有）
CURRENT_AK_ID=$(grep 'ALIYUN_ACCESS_KEY_ID=' "$CONFIG_FILE" | cut -d'"' -f2)
CURRENT_AK_SECRET=$(grep 'ALIYUN_ACCESS_KEY_SECRET=' "$CONFIG_FILE" | cut -d'"' -f2)
CURRENT_DOMAIN=$(grep 'ALIYUN_DOMAIN=' "$CONFIG_FILE" | cut -d'"' -f2)
CURRENT_SUBDOMAIN=$(grep 'ALIYUN_SUBDOMAIN=' "$CONFIG_FILE" | cut -d'"' -f2)

# 提示输入AccessKey ID
echo "----------------------------------------"
echo "步骤 1/4: 配置 AccessKey ID"
echo "----------------------------------------"
if [[ "$CURRENT_AK_ID" != *"你的AccessKey"* ]] && [[ "$CURRENT_AK_ID" != *"你的"* ]] && [ -n "$CURRENT_AK_ID" ]; then
    echo "当前配置: ${CURRENT_AK_ID:0:10}..."
    read -p "是否使用当前配置? (y/n, 默认y): " use_current
    if [[ "$use_current" != "n" ]] && [[ "$use_current" != "N" ]]; then
        ACCESS_KEY_ID="$CURRENT_AK_ID"
    else
        read -p "请输入 AccessKey ID: " ACCESS_KEY_ID
    fi
else
    read -p "请输入 AccessKey ID: " ACCESS_KEY_ID
fi

# 验证AccessKey ID格式
if [ -z "$ACCESS_KEY_ID" ]; then
    echo "[ERROR] AccessKey ID 不能为空"
    exit 1
fi

if [[ ! "$ACCESS_KEY_ID" =~ ^LTAI[0-9A-Za-z]{16}$ ]]; then
    echo "[WARN] AccessKey ID 格式可能不正确（应以 LTAI 开头，共20个字符）"
    read -p "是否继续? (y/n): " continue_anyway
    if [[ "$continue_anyway" != "y" ]] && [[ "$continue_anyway" != "Y" ]]; then
        exit 1
    fi
fi

# 提示输入AccessKey Secret
echo ""
echo "----------------------------------------"
echo "步骤 2/4: 配置 AccessKey Secret"
echo "----------------------------------------"
if [[ "$CURRENT_AK_SECRET" != *"你的AccessKey"* ]] && [[ "$CURRENT_AK_SECRET" != *"你的"* ]] && [ -n "$CURRENT_AK_SECRET" ]; then
    echo "当前配置: ***已设置***"
    read -p "是否使用当前配置? (y/n, 默认y): " use_current
    if [[ "$use_current" != "n" ]] && [[ "$use_current" != "N" ]]; then
        ACCESS_KEY_SECRET="$CURRENT_AK_SECRET"
    else
        read -sp "请输入 AccessKey Secret (输入时不会显示): " ACCESS_KEY_SECRET
        echo ""
    fi
else
    read -sp "请输入 AccessKey Secret (输入时不会显示): " ACCESS_KEY_SECRET
    echo ""
fi

# 验证AccessKey Secret
if [ -z "$ACCESS_KEY_SECRET" ]; then
    echo "[ERROR] AccessKey Secret 不能为空"
    exit 1
fi

# 提示输入域名
echo ""
echo "----------------------------------------"
echo "步骤 3/4: 配置域名"
echo "----------------------------------------"
if [[ "$CURRENT_DOMAIN" != *"你的域名"* ]] && [[ "$CURRENT_DOMAIN" != *"example.com"* ]] && [ -n "$CURRENT_DOMAIN" ]; then
    echo "当前配置: $CURRENT_DOMAIN"
    read -p "是否使用当前配置? (y/n, 默认y): " use_current
    if [[ "$use_current" != "n" ]] && [[ "$use_current" != "N" ]]; then
        DOMAIN="$CURRENT_DOMAIN"
    else
        read -p "请输入域名 (例如: piowncloud.com): " DOMAIN
    fi
else
    read -p "请输入域名 (例如: piowncloud.com): " DOMAIN
fi

# 验证域名格式
if [ -z "$DOMAIN" ]; then
    echo "[ERROR] 域名不能为空"
    exit 1
fi

# 移除可能的协议前缀
DOMAIN=$(echo "$DOMAIN" | sed 's|^https\?://||' | sed 's|/$||')

# 提示输入子域名
echo ""
echo "----------------------------------------"
echo "步骤 4/4: 配置子域名"
echo "----------------------------------------"
if [ -n "$CURRENT_SUBDOMAIN" ]; then
    echo "当前配置: $CURRENT_SUBDOMAIN"
    read -p "是否使用当前配置? (y/n, 默认y): " use_current
    if [[ "$use_current" != "n" ]] && [[ "$use_current" != "N" ]]; then
        SUBDOMAIN="$CURRENT_SUBDOMAIN"
    else
        read -p "请输入子域名 (@ 表示主域名, www 表示www子域名, 默认@): " SUBDOMAIN
        SUBDOMAIN=${SUBDOMAIN:-@}
    fi
else
    read -p "请输入子域名 (@ 表示主域名, www 表示www子域名, 默认@): " SUBDOMAIN
    SUBDOMAIN=${SUBDOMAIN:-@}
fi

# 显示配置摘要
echo ""
echo "========================================="
echo "配置摘要"
echo "========================================="
echo "AccessKey ID:     ${ACCESS_KEY_ID:0:10}..."
echo "AccessKey Secret: ***隐藏***"
echo "域名:            $DOMAIN"
echo "子域名:          $SUBDOMAIN"
echo ""

read -p "确认保存配置? (y/n): " confirm
if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
    echo "已取消"
    exit 0
fi

# 备份原配置文件
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "[INFO] 已备份原配置文件: $BACKUP_FILE"

# 更新配置文件
sed -i "s|export ALIYUN_ACCESS_KEY_ID=\".*\"|export ALIYUN_ACCESS_KEY_ID=\"$ACCESS_KEY_ID\"|" "$CONFIG_FILE"
sed -i "s|export ALIYUN_ACCESS_KEY_SECRET=\".*\"|export ALIYUN_ACCESS_KEY_SECRET=\"$ACCESS_KEY_SECRET\"|" "$CONFIG_FILE"
sed -i "s|export ALIYUN_DOMAIN=\".*\"|export ALIYUN_DOMAIN=\"$DOMAIN\"|" "$CONFIG_FILE"
sed -i "s|export ALIYUN_SUBDOMAIN=\".*\"|export ALIYUN_SUBDOMAIN=\"$SUBDOMAIN\"|" "$CONFIG_FILE"

echo ""
echo "[SUCCESS] 配置已保存！"
echo ""
echo "下一步："
echo "  1. 运行配置检查: bash scripts/check_aliyun_config.sh"
echo "  2. 测试脚本: bash scripts/update_aliyun_dns.sh"
echo ""

