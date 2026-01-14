# FRP内网穿透部署完整教程

本教程将帮助您通过FRP内网穿透，让您的树莓派私有云可以从外网访问，使用您的域名 `piowncloud.com`。

## 📋 前置条件检查

在开始之前，请确认：

- ✅ 树莓派已完成基础部署（参考 `02-系统部署教程.md`）
- ✅ 树莓派可以正常访问互联网
- ✅ 已有阿里云域名：`piowncloud.com`
- ✅ 已有阿里云账号（或准备注册）
- ✅ 准备购买阿里云轻量应用服务器（38-108元/年）

## 🎯 整体流程概览

```
第1步：购买并配置阿里云服务器     [预计15分钟]
第2步：服务器端安装FRP服务端      [预计10分钟]
第3步：树莓派安装FRP客户端        [预计10分钟]
第4步：配置阿里云域名解析         [预计5分钟]
第5步：配置HTTPS证书              [预计10分钟]
第6步：测试和验证                 [预计5分钟]

总计约：55分钟
```

---

## 📦 第1步：购买阿里云服务器（15分钟）

### 1.1 访问阿里云轻量应用服务器

1. 访问阿里云官网：https://www.aliyun.com
2. 登录您的阿里云账号（没有就注册一个）
3. 搜索"轻量应用服务器"或直接访问：
   https://www.aliyun.com/product/swas

### 1.2 选择配置

推荐配置（家庭使用完全够用）：

```
地域：选择离您最近的
  - 华东（如果在江浙沪）
  - 华南（如果在广东福建）
  - 华北（如果在北京周边）

镜像：Ubuntu 22.04 LTS

套餐：
  新用户推荐：1核2G 3Mbps 40GB存储
    - 价格：首年 ~38元
    - 流量：每月60GB
  
  或者：2核2G 4Mbps 60GB存储
    - 价格：首年 ~66元
    - 流量：每月200GB
```

### 1.3 完成购买

1. 选择套餐后点击"立即购买"
2. 购买时长选择"1年"（性价比最高）
3. 设置服务器密码（记住这个密码！）
4. 勾选协议，完成支付

### 1.4 记录服务器信息

购买完成后，进入控制台：

```
记录以下信息（很重要！）：
1. 公网IP：如 47.100.123.45
2. 服务器密码：您刚才设置的密码
3. 用户名：root（默认）
```

### 1.5 配置防火墙

在阿里云控制台：

1. 进入您的轻量服务器详情页
2. 点击"防火墙"
3. 添加以下规则：

```
规则1：
  协议：TCP
  端口：80
  说明：HTTP

规则2：
  协议：TCP
  端口：443
  说明：HTTPS

规则3：
  协议：TCP
  端口：7000
  说明：FRP通信端口

规则4：
  协议：TCP
  端口：7500
  说明：FRP控制台（可选）
```

---

## 🖥️ 第2步：配置阿里云服务器（10分钟）

### 2.1 SSH连接到服务器

**Windows用户：**

使用PowerShell或下载PuTTY：

```powershell
# 打开PowerShell，输入：
ssh root@你的服务器IP

# 例如：
ssh root@47.100.123.45

# 输入yes（首次连接）
# 输入密码（不显示是正常的）
```

**Mac/Linux用户：**

```bash
# 打开终端，输入：
ssh root@你的服务器IP

# 输入密码
```

### 2.2 更新系统

```bash
# 更新软件包列表
apt update

# 升级系统（可选，但推荐）
apt upgrade -y
```

### 2.3 下载并运行自动安装脚本

**方法一：使用我提供的自动脚本（推荐）**

```bash
# 下载安装脚本
wget https://raw.githubusercontent.com/yourusername/RaspiOwnCloud/main/scripts/install_frps.sh

# 如果GitHub访问困难，使用国内镜像：
wget https://gitee.com/yourusername/RaspiOwnCloud/raw/main/scripts/install_frps.sh

# 添加执行权限
chmod +x install_frps.sh

# 运行安装脚本
bash install_frps.sh
```

脚本会自动完成：
- ✅ 下载FRP服务端
- ✅ 创建配置文件
- ✅ 设置systemd服务
- ✅ 启动FRP服务

**方法二：手动安装（如果脚本不可用）**

请参考本文档末尾的"附录A：手动安装FRP服务端"

### 2.4 记录FRP Token

安装完成后，脚本会生成一个随机token，请记录下来：

```
=== FRP服务端安装完成 ===
FRP Token: abc123def456ghi789
请将此Token记录下来，配置客户端时需要使用！
```

**重要：这个Token要在树莓派配置时使用！**

### 2.5 验证服务运行

```bash
# 查看FRP服务状态
systemctl status frps

# 应该显示 active (running)

# 查看FRP日志
tail -f /var/log/frps.log
```

---

## 🍓 第3步：配置树莓派（10分钟）

### 3.1 SSH连接到树莓派

从您的笔记本连接树莓派：

```bash
# Windows PowerShell 或 Mac/Linux 终端
ssh pi@树莓派IP

# 例如：
ssh pi@192.168.137.100
```

### 3.2 下载并运行自动安装脚本

```bash
# 进入项目目录
cd ~/Desktop/Github/RaspiOwnCloud

# 如果没有这个目录，先克隆项目
git clone https://github.com/yourusername/RaspiOwnCloud.git
cd RaspiOwnCloud

# 运行树莓派端安装脚本
bash scripts/install_frpc.sh

# 按提示输入：
# 1. 阿里云服务器IP
# 2. FRP Token（上一步记录的）
# 3. 您的域名（piowncloud.com）
```

### 3.3 验证FRP客户端运行

```bash
# 查看服务状态
sudo systemctl status frpc

# 应该显示 active (running)

# 查看日志
sudo journalctl -u frpc -f

# 应该看到类似：
# [INFO] login to server success
# [INFO] start proxy success
```

如果看到 "login to server success"，说明隧道建立成功！🎉

---

## 🌐 第4步：配置域名解析（5分钟）

### 4.1 登录阿里云DNS控制台

1. 访问：https://dns.console.aliyun.com/
2. 找到您的域名：`piowncloud.com`
3. 点击"解析设置"

### 4.2 添加A记录

点击"添加记录"，填写：

```
记录类型：A
主机记录：@
解析线路：默认
记录值：您的阿里云服务器公网IP（如 47.100.123.45）
TTL：600（10分钟）
```

点击"确认"。

### 4.3 添加www子域名（可选）

再添加一条记录：

```
记录类型：A
主机记录：www
解析线路：默认
记录值：您的阿里云服务器公网IP
TTL：600
```

### 4.4 验证DNS解析

```bash
# 在您的电脑或树莓派上执行
nslookup piowncloud.com

# 应该返回您的阿里云服务器IP
# 注意：DNS解析可能需要5-10分钟生效
```

---

## 🔒 第5步：配置HTTPS证书（10分钟）

### 5.1 在阿里云服务器上安装Certbot

```bash
# SSH连接到阿里云服务器
ssh root@你的服务器IP

# 安装Certbot
apt install -y certbot
```

### 5.2 申请SSL证书

```bash
# 使用Certbot申请证书
certbot certonly --standalone -d piowncloud.com -d www.piowncloud.com

# 按提示操作：
# 1. 输入邮箱（用于接收证书过期提醒）
# 2. 同意服务条款：输入 Y
# 3. 是否接收邮件：输入 N（可选）
```

**注意：**
- 申请时需要暂停FRP服务：`systemctl stop frps`
- 申请完成后重启：`systemctl start frps`

或者使用自动配置脚本：

```bash
# 运行HTTPS配置脚本
bash /root/setup_https.sh piowncloud.com www.piowncloud.com
```

### 5.3 配置证书自动续期

```bash
# 测试自动续期
certbot renew --dry-run

# 添加定时任务
crontab -e

# 添加以下行（每月1日凌晨3点检查续期）
0 3 1 * * certbot renew --quiet --pre-hook "systemctl stop frps" --post-hook "systemctl start frps"
```

### 5.4 修改FRP配置支持HTTPS

```bash
# 编辑FRP服务端配置
nano /etc/frp/frps.ini

# 在 [common] 部分添加：
vhost_https_port = 443

# 重启FRP
systemctl restart frps
```

### 5.5 修改树莓派FRP客户端配置

在树莓派上：

```bash
# 编辑FRP客户端配置
sudo nano /etc/frp/frpc.ini

# 添加HTTPS代理配置（在文件末尾）
[raspberrycloud-https]
type = https
local_ip = 127.0.0.1
local_port = 443
custom_domains = piowncloud.com

# 重启FRP客户端
sudo systemctl restart frpc
```

---

## ✅ 第6步：测试验证（5分钟）

### 6.1 测试HTTP访问

在浏览器打开：

```
http://piowncloud.com
```

应该能看到您的RaspberryCloud登录页面！

### 6.2 测试HTTPS访问

在浏览器打开：

```
https://piowncloud.com
```

应该能看到：
- ✅ 显示登录页面
- ✅ 地址栏有锁图标（安全连接）
- ✅ 没有证书警告

### 6.3 测试外网访问

1. 用手机关闭WiFi，使用4G/5G网络
2. 浏览器访问：`https://piowncloud.com`
3. 尝试登录并上传/下载文件

### 6.4 测试不同网络环境

**重要测试：验证网络灵活性**

1. 记录树莓派当前网络环境
2. 将树莓派连接到另一个WiFi（如手机热点）
3. 等待30秒，FRP会自动重连
4. 再次访问 `https://piowncloud.com`
5. 应该仍然正常访问！✅

**这证明：**
- ✅ 树莓派可以随意更换网络
- ✅ 外网访问不受影响
- ✅ 域名始终有效

---

## 📊 监控和维护

### 查看FRP状态

**在阿里云服务器：**

```bash
# 查看服务状态
systemctl status frps

# 查看实时日志
tail -f /var/log/frps.log

# 查看连接统计
curl http://localhost:7500/api/proxy/tcp  # 如果开启了控制台
```

**在树莓派：**

```bash
# 查看服务状态
sudo systemctl status frpc

# 查看实时日志
sudo journalctl -u frpc -f

# 重启FRP客户端
sudo systemctl restart frpc
```

### 常用管理命令

```bash
# 重启服务
sudo systemctl restart frpc    # 树莓派
systemctl restart frps         # 阿里云服务器

# 停止服务
sudo systemctl stop frpc
systemctl stop frps

# 查看配置
cat /etc/frp/frpc.ini         # 树莓派
cat /etc/frp/frps.ini         # 阿里云服务器
```

---

## 🔧 故障排查

### Q1：无法访问 piowncloud.com

**检查步骤：**

```bash
# 1. 检查DNS解析
nslookup piowncloud.com
# 应该返回阿里云服务器IP

# 2. 检查阿里云服务器FRP运行
ssh root@服务器IP
systemctl status frps
# 应该是 active (running)

# 3. 检查树莓派FRP连接
ssh pi@树莓派IP
sudo systemctl status frpc
sudo journalctl -u frpc -n 50
# 查看是否有 "login to server success"

# 4. 检查防火墙
# 登录阿里云控制台，确认80、443端口已开放
```

### Q2：FRP客户端无法连接

**症状：**
```
[ERROR] login to server failed: EOF
```

**解决方法：**

```bash
# 1. 检查Token是否正确
sudo nano /etc/frp/frpc.ini
# 确认 token = xxx 与服务端一致

# 2. 检查服务器IP和端口
# 确认 server_addr 和 server_port 正确

# 3. 检查网络连接
ping 阿里云服务器IP
telnet 阿里云服务器IP 7000

# 4. 重启服务
sudo systemctl restart frpc
```

### Q3：HTTPS证书错误

**解决方法：**

```bash
# 在阿里云服务器上

# 1. 检查证书是否存在
ls -la /etc/letsencrypt/live/piowncloud.com/

# 2. 检查证书权限
chmod 755 /etc/letsencrypt/live
chmod 755 /etc/letsencrypt/archive

# 3. 重新申请证书
systemctl stop frps
certbot certonly --standalone -d piowncloud.com --force-renew
systemctl start frps
```

### Q4：树莓派换网络后无法访问

**症状：** 树莓派连接到新网络后，外网无法访问

**解决方法：**

```bash
# 在树莓派上

# 1. 检查网络连接
ping 8.8.8.8

# 2. 检查FRP状态
sudo systemctl status frpc

# 3. 重启FRP（通常会自动重连）
sudo systemctl restart frpc

# 4. 等待30秒，查看日志
sudo journalctl -u frpc -f
# 应该看到 "login to server success"
```

### Q5：访问速度慢

**优化建议：**

1. **选择更近的阿里云地域**
   - 如果在华东，选华东节点
   - 避免跨地域访问

2. **升级带宽**
   - 阿里云控制台可以临时升级带宽
   - 按流量计费更灵活

3. **启用压缩**（在树莓派FRP配置）

```ini
# /etc/frp/frpc.ini
[common]
server_addr = xxx
server_port = 7000
token = xxx
tcp_mux = true           # 启用多路复用
pool_count = 5           # 连接池大小
```

---

## 🎉 完成！

恭喜！您的RaspberryCloud现在可以：

- ✅ 通过 `https://piowncloud.com` 从全球任何地方访问
- ✅ 使用HTTPS加密连接，安全可靠
- ✅ 树莓派可以连接任何网络（WiFi、有线、热点）
- ✅ 外网访问始终稳定
- ✅ 数据完全存储在自己的树莓派上

### 成本总结

```
阿里云服务器：38-108元/年
域名（已有）：0元
树莓派（已有）：0元
电费：~50元/年

总计：~88-158元/年
```

### 下一步

1. [安全加固](04-安全加固指南.md) - 增强系统安全
2. [配置自动备份](备份恢复指南.md) - 保护数据安全
3. [性能优化](性能优化指南.md) - 提升访问速度

---

## 📚 附录

### 附录A：手动安装FRP服务端

如果自动脚本不可用，请按以下步骤手动安装：

```bash
# 1. 下载FRP
cd /root
wget https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_linux_amd64.tar.gz

# 2. 解压
tar -xzf frp_0.52.3_linux_amd64.tar.gz

# 3. 创建目录
mkdir -p /etc/frp
mkdir -p /var/log/frp

# 4. 复制文件
cp frp_0.52.3_linux_amd64/frps /usr/local/bin/
chmod +x /usr/local/bin/frps

# 5. 创建配置文件
nano /etc/frp/frps.ini
```

**frps.ini 内容：**

```ini
[common]
bind_port = 7000
vhost_http_port = 80
vhost_https_port = 443
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = 你的密码（自己设置）
token = 你的Token（随机生成，如：openssl rand -hex 16）

# 日志
log_file = /var/log/frp/frps.log
log_level = info
log_max_days = 3

# 性能优化
max_pool_count = 50
max_ports_per_client = 0
```

**生成随机Token：**

```bash
openssl rand -hex 16
# 输出类似：a1b2c3d4e5f6g7h8i9j0
# 将这个值作为token
```

**创建systemd服务：**

```bash
nano /etc/systemd/system/frps.service
```

**frps.service 内容：**

```ini
[Unit]
Description=FRP Server Service
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=10s
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.ini

[Install]
WantedBy=multi-user.target
```

**启动服务：**

```bash
systemctl daemon-reload
systemctl enable frps
systemctl start frps
systemctl status frps
```

### 附录B：手动安装FRP客户端（树莓派）

```bash
# 1. 下载FRP（ARM64版本）
cd ~
wget https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_linux_arm64.tar.gz

# 2. 解压
tar -xzf frp_0.52.3_linux_arm64.tar.gz

# 3. 创建目录
sudo mkdir -p /etc/frp

# 4. 复制文件
sudo cp frp_0.52.3_linux_arm64/frpc /usr/local/bin/
sudo chmod +x /usr/local/bin/frpc

# 5. 创建配置文件
sudo nano /etc/frp/frpc.ini
```

**frpc.ini 内容：**

```ini
[common]
server_addr = 你的阿里云服务器IP
server_port = 7000
token = 你的Token（与服务端相同）

# 性能优化
tcp_mux = true
pool_count = 5

[raspberrycloud-http]
type = http
local_ip = 127.0.0.1
local_port = 80
custom_domains = piowncloud.com

[raspberrycloud-https]
type = https
local_ip = 127.0.0.1
local_port = 443
custom_domains = piowncloud.com
```

**创建systemd服务：**

```bash
sudo nano /etc/systemd/system/frpc.service
```

**frpc.service 内容：**

```ini
[Unit]
Description=FRP Client Service
After=network.target

[Service]
Type=simple
User=pi
Restart=on-failure
RestartSec=10s
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.ini

[Install]
WantedBy=multi-user.target
```

**启动服务：**

```bash
sudo systemctl daemon-reload
sudo systemctl enable frpc
sudo systemctl start frpc
sudo systemctl status frpc
```

### 附录C：监控脚本

创建监控脚本，自动检查FRP状态并重启：

```bash
sudo nano /opt/raspberrycloud/scripts/monitor_frpc.sh
```

**内容：**

```bash
#!/bin/bash
# FRP客户端监控脚本

LOG_FILE="/var/log/frpc_monitor.log"

# 检查FRP是否运行
if ! systemctl is-active --quiet frpc; then
    echo "[$(date)] FRP客户端未运行，正在重启..." >> $LOG_FILE
    systemctl restart frpc
    sleep 5
    
    if systemctl is-active --quiet frpc; then
        echo "[$(date)] FRP客户端重启成功" >> $LOG_FILE
    else
        echo "[$(date)] FRP客户端重启失败！" >> $LOG_FILE
    fi
else
    echo "[$(date)] FRP客户端运行正常" >> $LOG_FILE
fi
```

**设置执行权限：**

```bash
sudo chmod +x /opt/raspberrycloud/scripts/monitor_frpc.sh
```

**添加定时任务：**

```bash
crontab -e

# 添加（每5分钟检查一次）
*/5 * * * * /opt/raspberrycloud/scripts/monitor_frpc.sh
```

---

## 📞 获取帮助

如果遇到问题，请检查：

1. **查看日志**
   ```bash
   # 阿里云服务器
   tail -f /var/log/frp/frps.log
   
   # 树莓派
   sudo journalctl -u frpc -f
   ```

2. **检查网络连接**
   ```bash
   # 测试到阿里云的连接
   ping 阿里云服务器IP
   telnet 阿里云服务器IP 7000
   ```

3. **重启所有服务**
   ```bash
   # 阿里云
   systemctl restart frps
   
   # 树莓派
   sudo systemctl restart frpc
   sudo systemctl restart raspberrycloud
   sudo systemctl restart nginx
   ```

祝您使用愉快！🎉


























