#!/bin/bash
#
# RaspberryCloud 存储挂载脚本
# 自动检测并挂载外接存储设备
#

set -e

# 配置
MOUNT_POINT="/mnt/cloud_storage"
DEVICE=""  # 自动检测

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    print_error "此脚本需要root权限运行"
    echo "请使用: sudo bash mount_storage.sh"
    exit 1
fi

print_info "检测外接存储设备..."

# 列出所有块设备
lsblk

echo ""
print_info "请选择要挂载的设备（例如：sda1）:"
read -r DEVICE

if [ -z "$DEVICE" ]; then
    print_error "未选择设备"
    exit 1
fi

# 验证设备存在
if [ ! -b "/dev/$DEVICE" ]; then
    print_error "设备 /dev/$DEVICE 不存在"
    exit 1
fi

# 获取设备UUID
UUID=$(blkid -s UUID -o value "/dev/$DEVICE")

if [ -z "$UUID" ]; then
    print_error "无法获取设备UUID"
    exit 1
fi

print_info "设备UUID: $UUID"

# 获取文件系统类型
FSTYPE=$(blkid -s TYPE -o value "/dev/$DEVICE")
print_info "文件系统类型: $FSTYPE"

# 创建挂载点
print_info "创建挂载点: $MOUNT_POINT"
mkdir -p "$MOUNT_POINT"

# 临时挂载测试
print_info "测试挂载..."
mount "/dev/$DEVICE" "$MOUNT_POINT"

if mountpoint -q "$MOUNT_POINT"; then
    print_info "✅ 挂载成功"
    
    # 创建目录结构
    print_info "创建目录结构..."
    mkdir -p "$MOUNT_POINT"/{users,shares,temp,backups}
    
    # 设置权限
    chown -R www-data:www-data "$MOUNT_POINT"
    chmod -R 755 "$MOUNT_POINT"
    
    # 询问是否添加到fstab
    echo ""
    read -p "是否添加到/etc/fstab实现开机自动挂载? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 备份fstab
        cp /etc/fstab /etc/fstab.backup_$(date +%Y%m%d)
        
        # 检查是否已存在
        if grep -q "$UUID" /etc/fstab; then
            print_warn "UUID已存在于/etc/fstab，跳过添加"
        else
            # 添加到fstab
            echo "" >> /etc/fstab
            echo "# RaspberryCloud存储 - 添加于 $(date)" >> /etc/fstab
            echo "UUID=$UUID $MOUNT_POINT $FSTYPE defaults,nofail 0 2" >> /etc/fstab
            print_info "✅ 已添加到/etc/fstab"
        fi
        
        # 测试fstab
        print_info "测试fstab配置..."
        umount "$MOUNT_POINT"
        mount -a
        
        if mountpoint -q "$MOUNT_POINT"; then
            print_info "✅ fstab配置成功"
        else
            print_error "❌ fstab配置失败"
            exit 1
        fi
    fi
    
    echo ""
    print_info "========================================="
    print_info "存储挂载完成！"
    print_info "========================================="
    echo ""
    print_info "挂载点: $MOUNT_POINT"
    print_info "设备: /dev/$DEVICE"
    print_info "UUID: $UUID"
    echo ""
    
    # 显示磁盘使用情况
    df -h "$MOUNT_POINT"
    
else
    print_error "❌ 挂载失败"
    exit 1
fi


