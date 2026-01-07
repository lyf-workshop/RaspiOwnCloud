# FRP 快速参考指南

## 🚀 一键安装命令

### 阿里云服务器端

```bash
# 下载并运行安装脚本
wget https://raw.githubusercontent.com/yourusername/RaspiOwnCloud/main/scripts/install_frps.sh
chmod +x install_frps.sh
bash install_frps.sh

# 记住显示的Token！
```

### 树莓派客户端

```bash
# 下载并运行安装脚本
cd ~/Desktop/Github/RaspiOwnCloud
bash scripts/install_frpc.sh

# 按提示输入服务器IP、Token和域名
```

---

## 📋 常用管理命令

### 服务管理

```bash
# 查看状态
systemctl status frps    # 服务端
systemctl status frpc    # 客户端

# 启动服务
systemctl start frps
systemctl start frpc

# 停止服务
systemctl stop frps
systemctl stop frpc

# 重启服务
systemctl restart frps
systemctl restart frpc

# 开机自启
systemctl enable frps
systemctl enable frpc
```

### 日志查看

```bash
# 实时日志
journalctl -u frps -f    # 服务端
journalctl -u frpc -f    # 客户端

# 最近50行日志
journalctl -u frps -n 50
journalctl -u frpc -n 50

# 查看特定时间日志
journalctl -u frpc --since "10 minutes ago"
journalctl -u frpc --since "2023-12-01"
```

### 配置文件

```bash
# 编辑配置
nano /etc/frp/frps.ini    # 服务端
nano /etc/frp/frpc.ini    # 客户端

# 查看配置
cat /etc/frp/frps.ini
cat /etc/frp/frpc.ini

# 修改配置后重启
systemctl restart frps
systemctl restart frpc
```

---

## 🔧 快速诊断

### 检查FRP状态

```bash
# 使用状态检查脚本
bash scripts/frp_status.sh

# 或手动检查
systemctl status frpc
journalctl -u frpc -n 20
```

### 检查网络连接（树莓派）

```bash
# 1. 检查本地网络
ping 8.8.8.8

# 2. 检查服务器连接
ping 你的服务器IP

# 3. 检查FRP端口
telnet 你的服务器IP 7000
# 或
nc -zv 你的服务器IP 7000

# 4. 检查DNS解析
nslookup piowncloud.com
```

### 检查端口监听（服务器）

```bash
# 查看FRP监听的端口
ss -tunlp | grep frps

# 应该看到：
# 0.0.0.0:7000  (FRP通信端口)
# 0.0.0.0:80    (HTTP)
# 0.0.0.0:443   (HTTPS)
# 0.0.0.0:7500  (控制台)
```

---

## 🐛 常见问题快速修复

### Q1: 客户端无法连接服务器

```bash
# 1. 检查Token是否正确
cat /etc/frp/frpc.ini | grep token

# 2. 检查服务器IP和端口
cat /etc/frp/frpc.ini | grep server

# 3. 测试网络
ping 服务器IP
telnet 服务器IP 7000

# 4. 查看详细错误
journalctl -u frpc -n 50

# 5. 重启服务
sudo systemctl restart frpc
```

### Q2: 域名无法访问

```bash
# 1. 检查DNS解析
nslookup piowncloud.com
# 应该返回你的阿里云服务器IP

# 2. 检查FRP服务端
ssh root@服务器IP
systemctl status frps

# 3. 检查FRP客户端
systemctl status frpc

# 4. 检查Nginx（树莓派）
systemctl status nginx

# 5. 端到端测试
curl -I http://piowncloud.com
```

### Q3: HTTPS证书错误

```bash
# 在阿里云服务器上

# 1. 检查证书是否存在
ls -la /etc/letsencrypt/live/piowncloud.com/

# 2. 查看证书信息
certbot certificates

# 3. 重新申请证书
systemctl stop frps
certbot certonly --standalone -d piowncloud.com --force-renew
systemctl start frps

# 4. 测试证书
curl -I https://piowncloud.com
```

### Q4: 树莓派换网络后无法访问

```bash
# 树莓派会自动重连，如果不行：

# 1. 检查网络
ping 8.8.8.8

# 2. 重启FRP客户端
sudo systemctl restart frpc

# 3. 等待30秒，检查日志
sudo journalctl -u frpc -f
# 应该看到 "login to server success"

# 4. 如果还不行，检查配置
cat /etc/frp/frpc.ini
```

---

## 📊 性能优化

### 优化FRP配置（客户端）

编辑 `/etc/frp/frpc.ini`：

```ini
[common]
server_addr = xxx
server_port = 7000
token = xxx

# 性能优化
tcp_mux = true              # 启用TCP多路复用
pool_count = 10             # 增加连接池（默认5）
tcp_mux_keepalive_interval = 60  # 保活间隔

# 连接优化
dial_server_timeout = 10    # 连接超时
dial_server_keepalive = 7200  # 保活时间

# 日志级别（生产环境建议warn）
log_level = info
```

### 监控和自动重启

```bash
# 1. 复制监控脚本
sudo cp scripts/monitor_frpc.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/monitor_frpc.sh

# 2. 添加定时任务
crontab -e

# 添加（每5分钟检查一次）
*/5 * * * * /usr/local/bin/monitor_frpc.sh

# 3. 查看监控日志
tail -f /var/log/frpc_monitor.log
```

---

## 🔐 安全建议

### 1. 修改默认端口（可选）

**服务端 `/etc/frp/frps.ini`：**
```ini
bind_port = 17000  # 改为非标准端口
```

**客户端 `/etc/frp/frpc.ini`：**
```ini
server_port = 17000  # 与服务端一致
```

### 2. 限制控制台访问

**服务端 `/etc/frp/frps.ini`：**
```ini
dashboard_port = 7500
dashboard_user = 你的用户名
dashboard_pwd = 复杂密码

# 限制只能本地访问（推荐）
# dashboard_addr = 127.0.0.1
```

### 3. 启用加密（可选）

**服务端：**
```ini
[common]
tls_enable = true
```

**客户端：**
```ini
[common]
tls_enable = true
```

### 4. 定期更新

```bash
# 定期检查FRP新版本
# https://github.com/fatedier/frp/releases

# 备份配置
cp /etc/frp/frps.ini /etc/frp/frps.ini.backup
cp /etc/frp/frpc.ini /etc/frp/frpc.ini.backup

# 下载新版本并替换
```

---

## 📱 移动网络切换

### 树莓派使用手机热点

```bash
# 1. 连接到手机热点WiFi
# 2. FRP会自动重连（等待30秒）
# 3. 检查连接
sudo journalctl -u frpc -f

# 4. 外网访问不受影响
# 浏览器访问 https://piowncloud.com 仍然可用
```

### 临时断网恢复

```bash
# FRP有自动重连机制
# 断网后恢复，会自动重新连接

# 如需强制重连：
sudo systemctl restart frpc
```

---

## 🎯 完整测试流程

### 部署完成后的测试清单

```bash
# === 在阿里云服务器 ===

# 1. 检查FRP服务
systemctl status frps

# 2. 检查端口监听
ss -tunlp | grep frps

# 3. 查看日志
tail -f /var/log/frp/frps.log


# === 在树莓派 ===

# 1. 检查FRP客户端
sudo systemctl status frpc

# 2. 检查连接日志
sudo journalctl -u frpc -n 20 | grep "login to server success"

# 3. 检查Nginx
sudo systemctl status nginx

# 4. 检查RaspberryCloud
sudo systemctl status raspberrycloud


# === 在任意设备 ===

# 1. DNS解析测试
nslookup piowncloud.com

# 2. HTTP测试
curl -I http://piowncloud.com

# 3. HTTPS测试
curl -I https://piowncloud.com

# 4. 浏览器测试
# 打开 https://piowncloud.com
# 应该看到登录页面

# 5. 功能测试
# 登录、上传、下载、分享

# 6. 外网测试
# 用手机4G网络访问
```

---

## 📞 获取帮助

### 查看完整日志

```bash
# 服务端
cat /var/log/frp/frps.log

# 客户端
sudo journalctl -u frpc --no-pager | tail -n 100

# 导出日志
sudo journalctl -u frpc > ~/frpc.log
```

### 配置备份

```bash
# 备份配置
sudo cp /etc/frp/frpc.ini ~/frpc.ini.backup
sudo cp /etc/frp/frps.ini ~/frps.ini.backup

# 恢复配置
sudo cp ~/frpc.ini.backup /etc/frp/frpc.ini
sudo systemctl restart frpc
```

### 完全重装

```bash
# 停止服务
sudo systemctl stop frpc
sudo systemctl disable frpc

# 删除文件
sudo rm /usr/local/bin/frpc
sudo rm /etc/frp/frpc.ini
sudo rm /etc/systemd/system/frpc.service

# 重新安装
bash scripts/install_frpc.sh
```

---

## 💡 提示和技巧

### 1. 查看Token

```bash
# 服务端
grep token /etc/frp/frps.ini

# 客户端
grep token /etc/frp/frpc.ini
```

### 2. 修改域名

```bash
# 编辑客户端配置
sudo nano /etc/frp/frpc.ini

# 修改 custom_domains = 新域名
# 保存后重启
sudo systemctl restart frpc
```

### 3. 添加多个域名

```ini
# 在客户端配置中添加
[raspberrycloud-http-www]
type = http
local_ip = 127.0.0.1
local_port = 80
custom_domains = www.piowncloud.com

[raspberrycloud-http-cloud]
type = http
local_ip = 127.0.0.1
local_port = 80
custom_domains = cloud.piowncloud.com
```

### 4. 查看公网IP

```bash
# 方法1
curl ip.sb

# 方法2
curl ifconfig.me

# 方法3
curl icanhazip.com
```

---

## 📚 相关文档

- [FRP内网穿透部署完整教程](FRP内网穿透部署完整教程.md) - 详细安装指南
- [02-系统部署教程](02-系统部署教程.md) - 树莓派基础部署
- [03-多端访问配置](03-多端访问配置.md) - 其他访问方式

---

## 🎉 完成

这个快速参考指南包含了最常用的命令和操作。

遇到问题时：
1. 先查看日志：`journalctl -u frpc -f`
2. 使用状态脚本：`bash scripts/frp_status.sh`
3. 参考完整教程解决

祝您使用愉快！























