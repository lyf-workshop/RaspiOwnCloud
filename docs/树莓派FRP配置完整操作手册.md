# 树莓派FRP配置完整操作手册

适用于：树莓派运行后端 + 阿里云服务器做FRP中转的场景

## 📋 当前情况确认

- ✅ 树莓派已部署RaspberryCloud后端服务
- ✅ 阿里云域名：`piowncloud.com`
- ✅ 阿里云服务器IP：`39.104.94.53`
- ✅ ICP备案已完成
- ✅ DNS解析指向阿里云服务器

## 🎯 配置目标

通过FRP内网穿透实现：
- 树莓派在任何网络环境都能被外网访问
- 使用域名 `https://piowncloud.com` 访问
- 数据存储在树莓派本地
- 阿里云服务器仅作为流量中转

## ⏱️ 时间预估

```
第1步：配置阿里云服务器FRP服务端    [15分钟]
第2步：配置树莓派FRP客户端          [10分钟]
第3步：申请HTTPS证书               [10分钟]
第4步：测试验证                    [5分钟]

总计约：40分钟
```

---

## 🖥️ 第1步：配置阿里云服务器FRP服务端

### 1.1 SSH连接到阿里云服务器

在笔记本上打开PowerShell：

```powershell
# 连接到阿里云服务器
ssh root@39.104.94.53

# 输入密码
```

### 1.2 配置阿里云防火墙

在阿里云控制台：

1. 登录阿里云控制台
2. 进入轻量应用服务器
3. 点击"防火墙"
4. 添加以下规则（如果没有）：

| 协议 | 端口 | 说明 |
|------|------|------|
| TCP | 80 | HTTP |
| TCP | 443 | HTTPS |
| TCP | 7000 | FRP通信端口 |
| TCP | 7500 | FRP控制台（可选） |

### 1.3 更新系统

```bash
# 更新软件包列表
apt update

# 升级系统（可选）
apt upgrade -y
```

### 1.4 下载并安装FRP服务端

```bash
# 进入root目录
cd /root

# 下载FRP（AMD64版本，适用于阿里云服务器）
wget https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_linux_amd64.tar.gz

# 如果GitHub下载慢，使用代理：
# wget https://ghproxy.com/https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_linux_amd64.tar.gz

# 解压
tar -xzf frp_0.52.3_linux_amd64.tar.gz

# 进入目录
cd frp_0.52.3_linux_amd64

# 查看文件
ls
# 应该看到：frps、frps.ini等文件
```

### 1.5 创建FRP目录和配置

```bash
# 创建配置目录
mkdir -p /etc/frp
mkdir -p /var/log/frp

# 复制服务端程序
cp frps /usr/local/bin/
chmod +x /usr/local/bin/frps

# 验证安装
frps --version
```

### 1.6 生成安全Token

```bash
# 生成随机Token（记住这个，配置客户端时要用）
openssl rand -hex 16

# 输出示例：a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
# 复制并保存这个Token！
```

### 1.7 创建FRP服务端配置文件

```bash
# 创建配置文件
nano /etc/frp/frps.ini
```

输入以下内容（**替换Token为你刚才生成的**）：

```ini
[common]
# FRP通信端口
bind_port = 7000

# HTTP端口
vhost_http_port = 80

# HTTPS端口
vhost_https_port = 443

# 控制台端口（可选，用于查看状态）
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = 你的密码（自己设置一个强密码）

# 安全Token（替换为你生成的Token）
token = a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

# 日志配置
log_file = /var/log/frp/frps.log
log_level = info
log_max_days = 3

# 性能优化
max_pool_count = 50
max_ports_per_client = 0
tcp_mux = true
```

**重要参数说明：**
- `token`：安全认证，必须与客户端一致
- `dashboard_pwd`：控制台密码，设置一个强密码

保存文件：`Ctrl+O`，回车，`Ctrl+X`

### 1.8 创建systemd服务

```bash
# 创建服务文件
nano /etc/systemd/system/frps.service
```

输入以下内容：

```ini
[Unit]
Description=FRP Server Service
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=10s
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.ini
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

保存文件。

### 1.9 启动FRP服务端

```bash
# 重新加载systemd
systemctl daemon-reload

# 设置开机自启
systemctl enable frps

# 启动服务
systemctl start frps

# 查看状态
systemctl status frps
```

**预期结果：**
- 显示 `active (running)` 表示运行正常

### 1.10 验证FRP服务端

```bash
# 查看日志
tail -f /var/log/frp/frps.log

# 应该看到类似：
# [I] [service.go:xxx] frps started successfully

# 检查端口监听
ss -tunlp | grep frps

# 应该看到：
# 0.0.0.0:7000  (FRP通信端口)
# 0.0.0.0:80    (HTTP)
# 0.0.0.0:443   (HTTPS)
# 0.0.0.0:7500  (控制台)
```

### 1.11 记录配置信息

**请记录以下信息（配置树莓派时需要）：**

```
阿里云服务器IP：39.104.94.53
FRP Token：a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6（你生成的）
FRP端口：7000
域名：piowncloud.com
```

---

## 🍓 第2步：配置树莓派FRP客户端

### 2.1 SSH连接到树莓派

在笔记本上打开新的PowerShell窗口：

```powershell
# 连接到树莓派
ssh pi@192.168.137.51

# 输入密码
```

### 2.2 检查树莓派服务状态

```bash
# 检查后端服务
sudo systemctl status raspberrycloud

# 检查Nginx
sudo systemctl status nginx

# 如果服务未运行，启动它们
sudo systemctl start raspberrycloud
sudo systemctl start nginx
```

### 2.3 下载并安装FRP客户端

```bash
# 进入临时目录
cd /tmp

# 下载FRP（ARM64版本，适用于树莓派）
wget https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_linux_arm64.tar.gz

# 如果下载慢，使用代理：
# wget https://ghproxy.com/https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_linux_arm64.tar.gz

# 解压
tar -xzf frp_0.52.3_linux_arm64.tar.gz

# 进入目录
cd frp_0.52.3_linux_arm64
```

### 2.4 安装FRP客户端

```bash
# 创建配置目录
sudo mkdir -p /etc/frp

# 复制客户端程序
sudo cp frpc /usr/local/bin/
sudo chmod +x /usr/local/bin/frpc

# 验证安装
frpc --version
```

### 2.5 创建FRP客户端配置文件

```bash
# 创建配置文件
sudo nano /etc/frp/frpc.ini
```

输入以下内容（**替换为你的实际信息**）：

```ini
[common]
# 阿里云服务器IP
server_addr = 39.104.94.53
server_port = 7000

# Token（与服务端一致）
token = a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

# 性能优化
tcp_mux = true
pool_count = 5
tcp_mux_keepalive_interval = 60
dial_server_timeout = 10
dial_server_keepalive = 7200

# 日志级别
log_level = info

# HTTP代理（80端口）
[raspberrycloud-http]
type = http
local_ip = 127.0.0.1
local_port = 80
custom_domains = piowncloud.com

# HTTPS代理（443端口）
[raspberrycloud-https]
type = https
local_ip = 127.0.0.1
local_port = 443
custom_domains = piowncloud.com
```

**重要参数说明：**
- `server_addr`：阿里云服务器IP
- `token`：必须与服务端Token完全一致
- `custom_domains`：你的域名
- `local_port`：80和443是树莓派Nginx的端口

保存文件：`Ctrl+O`，回车，`Ctrl+X`

### 2.6 创建systemd服务

```bash
# 创建服务文件
sudo nano /etc/systemd/system/frpc.service
```

输入以下内容：

```ini
[Unit]
Description=FRP Client Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
Restart=on-failure
RestartSec=10s
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.ini
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

保存文件。

### 2.7 启动FRP客户端

```bash
# 重新加载systemd
sudo systemctl daemon-reload

# 设置开机自启
sudo systemctl enable frpc

# 启动服务
sudo systemctl start frpc

# 查看状态
sudo systemctl status frpc
```

**预期结果：**
- 显示 `active (running)` 表示运行正常

### 2.8 验证FRP客户端连接

```bash
# 查看实时日志
sudo journalctl -u frpc -f

# 应该看到：
# [I] [service.go:xxx] login to server success, get run id [xxx]
# [I] [proxy_manager.go:xxx] [xxx] proxy added: [raspberrycloud-http]
# [I] [proxy_manager.go:xxx] [xxx] proxy added: [raspberrycloud-https]
```

**如果看到 "login to server success"，说明隧道建立成功！** 🎉

按 `Ctrl+C` 退出日志查看。

---

## 🔒 第3步：配置HTTPS证书

现在需要在阿里云服务器上申请SSL证书。

### 3.1 SSH回到阿里云服务器

```bash
# 在笔记本PowerShell中
ssh root@39.104.94.53
```

### 3.2 安装Certbot

```bash
# 安装Certbot
apt update
apt install -y certbot
```

### 3.3 临时停止FRP申请证书

```bash
# 停止FRP（因为Certbot需要占用80端口）
systemctl stop frps

# 申请SSL证书
certbot certonly --standalone -d piowncloud.com -d www.piowncloud.com
```

**按提示操作：**

1. 输入邮箱地址（用于证书到期提醒）：
   ```
   Enter email address: 3070198668@qq.com
   ```

2. 同意服务条款：
   ```
   (A)gree/(C)ancel: A
   ```

3. 是否分享邮箱（可选）：
   ```
   (Y)es/(N)o: N
   ```

**申请成功后会显示：**
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/piowncloud.com/fullchain.pem
Key is saved at: /etc/letsencrypt/live/piowncloud.com/privkey.pem
```

### 3.4 重启FRP服务

```bash
# 启动FRP
systemctl start frps

# 检查状态
systemctl status frps
```

### 3.5 配置证书自动续期

```bash
# 编辑crontab
crontab -e

# 如果首次使用，选择编辑器（推荐选择nano：输入1）
```

在文件末尾添加以下行：

```cron
# SSL证书自动续期（每月1日凌晨3点）
0 3 1 * * certbot renew --quiet --pre-hook "systemctl stop frps" --post-hook "systemctl start frps"
```

保存并退出：`Ctrl+O`，回车，`Ctrl+X`

### 3.6 测试证书续期

```bash
# 测试续期（不会真正续期）
certbot renew --dry-run

# 如果看到 "Congratulations, all simulated renewals succeeded"
# 说明自动续期配置成功
```

---

## ✅ 第4步：测试验证

### 4.1 验证DNS解析

在笔记本上：

```powershell
# 检查DNS
nslookup piowncloud.com

# 应该返回：39.104.94.53（阿里云服务器IP）
```

### 4.2 测试HTTP访问

在笔记本浏览器中打开：

```
http://piowncloud.com
```

**预期结果：**
- 能够看到登录页面
- 或自动跳转到HTTPS

### 4.3 测试HTTPS访问

在浏览器中打开：

```
https://piowncloud.com
```

**预期结果：**
- ✅ 显示登录页面
- ✅ 地址栏有锁图标 🔒
- ✅ 没有证书警告

### 4.4 测试外网访问

1. **使用手机4G/5G测试**
   - 关闭手机WiFi
   - 浏览器访问：`https://piowncloud.com`
   - 尝试登录

2. **测试功能**
   - 登录账号
   - 上传文件
   - 下载文件
   - 创建分享链接

### 4.5 测试网络切换（重要）

**验证树莓派网络灵活性：**

1. 记录当前树莓派网络（笔记本热点）
2. 将树莓派切换到其他网络（如路由器WiFi或手机热点）
3. 等待30秒，FRP会自动重连
4. 再次访问 `https://piowncloud.com`
5. 应该仍然正常访问！✅

**这证明：**
- ✅ 树莓派可以随意更换网络
- ✅ 外网访问不受影响
- ✅ 域名始终有效

---

## 📊 配置完成检查清单

```
□ 阿里云服务器FRP服务端运行正常（systemctl status frps）
□ 树莓派FRP客户端运行正常（systemctl status frpc）
□ FRP客户端日志显示 "login to server success"
□ DNS解析到阿里云服务器IP（39.104.94.53）
□ SSL证书申请成功
□ HTTP访问正常（http://piowncloud.com）
□ HTTPS访问正常（https://piowncloud.com）
□ 地址栏显示锁图标 🔒
□ 外网访问测试成功（手机4G）
□ 树莓派切换网络后仍可访问
□ 网站底部显示备案号
```

---

## 🔧 常用管理命令

### FRP服务管理

**阿里云服务器：**

```bash
# 查看FRP服务端状态
systemctl status frps

# 重启FRP服务端
systemctl restart frps

# 查看日志
tail -f /var/log/frp/frps.log

# 查看配置
cat /etc/frp/frps.ini
```

**树莓派：**

```bash
# 查看FRP客户端状态
sudo systemctl status frpc

# 重启FRP客户端
sudo systemctl restart frpc

# 查看实时日志
sudo journalctl -u frpc -f

# 查看最近50行日志
sudo journalctl -u frpc -n 50

# 查看配置
cat /etc/frp/frpc.ini
```

### 树莓派服务管理

```bash
# 后端服务
sudo systemctl status raspberrycloud
sudo systemctl restart raspberrycloud
sudo journalctl -u raspberrycloud -f

# Nginx
sudo systemctl status nginx
sudo systemctl restart nginx
sudo nginx -t  # 测试配置
```

### 端口和连接检查

**阿里云服务器：**

```bash
# 查看FRP监听的端口
ss -tunlp | grep frps

# 查看活跃连接
ss -tn | grep 7000
```

**树莓派：**

```bash
# 检查到服务器的连接
ping 39.104.94.53

# 测试FRP端口
telnet 39.104.94.53 7000
# 或
nc -zv 39.104.94.53 7000
```

---

## 🐛 常见问题排查

### Q1: FRP客户端无法连接服务器

**症状：**
```
[ERROR] login to server failed: EOF
```

**排查步骤：**

```bash
# 1. 检查Token是否一致
cat /etc/frp/frpc.ini | grep token
ssh root@39.104.94.53 "cat /etc/frp/frps.ini | grep token"
# 两者必须完全一致！

# 2. 检查服务器IP和端口
cat /etc/frp/frpc.ini | grep server

# 3. 测试网络连接
ping 39.104.94.53
telnet 39.104.94.53 7000

# 4. 检查服务端是否运行
ssh root@39.104.94.53 "systemctl status frps"

# 5. 查看详细错误
sudo journalctl -u frpc -n 100

# 6. 重启客户端
sudo systemctl restart frpc
```

### Q2: 域名无法访问

**排查步骤：**

```bash
# 1. 检查DNS解析
nslookup piowncloud.com
# 应该返回 39.104.94.53

# 2. 检查FRP服务端
ssh root@39.104.94.53 "systemctl status frps"

# 3. 检查FRP客户端
sudo systemctl status frpc
sudo journalctl -u frpc -n 20

# 4. 检查树莓派Nginx
sudo systemctl status nginx
curl http://localhost

# 5. 检查树莓派后端
sudo systemctl status raspberrycloud

# 6. 端到端测试
curl -I http://piowncloud.com
curl -I https://piowncloud.com
```

### Q3: HTTPS证书错误

**排查步骤：**

```bash
# 在阿里云服务器上

# 1. 检查证书文件
ls -la /etc/letsencrypt/live/piowncloud.com/

# 2. 查看证书信息
certbot certificates

# 3. 测试证书
curl -I https://piowncloud.com

# 4. 重新申请证书（如果过期或有问题）
systemctl stop frps
certbot certonly --standalone -d piowncloud.com -d www.piowncloud.com --force-renew
systemctl start frps
```

### Q4: 树莓派换网络后无法访问

**解决方法：**

```bash
# 在树莓派上

# 1. 检查网络连接
ping 8.8.8.8

# 2. 检查到服务器的连接
ping 39.104.94.53

# 3. 重启FRP客户端
sudo systemctl restart frpc

# 4. 等待30秒，查看日志
sudo journalctl -u frpc -f
# 应该看到 "login to server success"

# 5. 如果还不行，检查配置
cat /etc/frp/frpc.ini

# 6. 强制重连
sudo systemctl stop frpc
sleep 5
sudo systemctl start frpc
```

### Q5: 访问速度慢

**优化建议：**

1. **优化FRP客户端配置**

编辑 `/etc/frp/frpc.ini`：

```ini
[common]
server_addr = 39.104.94.53
server_port = 7000
token = xxx

# 性能优化（增加这些）
tcp_mux = true
pool_count = 10              # 增加连接池
tcp_mux_keepalive_interval = 30
compression = false          # 如果CPU不足，关闭压缩
```

2. **升级阿里云带宽**
   - 登录阿里云控制台
   - 轻量服务器 → 升级带宽
   - 按流量计费更灵活

3. **选择更近的地域**
   - 如果在华东，使用华东节点
   - 避免跨地域访问

---

## 📱 移动网络使用

### 树莓派使用手机热点

**场景：** 笔记本没网，树莓派连接手机热点

```bash
# 1. 在树莓派上连接手机热点WiFi
#    通过WiFi设置或命令行配置

# 2. FRP会自动重连（等待30秒）

# 3. 检查连接
sudo journalctl -u frpc -f
# 应该看到 "login to server success"

# 4. 外网访问不受影响
#    浏览器访问 https://piowncloud.com 仍然可用
```

### 临时断网恢复

FRP有自动重连机制：
- 断网后自动尝试重连
- 默认每10秒重试一次
- 无需手动干预

如需强制重连：
```bash
sudo systemctl restart frpc
```

---

## 🎯 性能监控

### 创建监控脚本

在树莓派上创建自动监控脚本：

```bash
# 创建脚本目录
sudo mkdir -p /opt/raspberrycloud/scripts

# 创建监控脚本
sudo nano /opt/raspberrycloud/scripts/monitor_frpc.sh
```

输入以下内容：

```bash
#!/bin/bash
# FRP客户端监控脚本

LOG_FILE="/var/log/frpc_monitor.log"

# 检查FRP是否运行
if ! systemctl is-active --quiet frpc; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FRP客户端未运行，正在重启..." >> $LOG_FILE
    systemctl restart frpc
    sleep 10
    
    if systemctl is-active --quiet frpc; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] FRP客户端重启成功" >> $LOG_FILE
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] FRP客户端重启失败！" >> $LOG_FILE
    fi
fi
```

保存并设置权限：

```bash
# 设置执行权限
sudo chmod +x /opt/raspberrycloud/scripts/monitor_frpc.sh

# 创建日志文件
sudo touch /var/log/frpc_monitor.log
sudo chown pi:pi /var/log/frpc_monitor.log

# 添加定时任务
crontab -e

# 添加（每5分钟检查一次）
*/5 * * * * /opt/raspberrycloud/scripts/monitor_frpc.sh

# 查看监控日志
tail -f /var/log/frpc_monitor.log
```

---

## 🎉 配置完成！

现在你的RaspberryCloud私有云可以：

- ✅ 通过 `https://piowncloud.com` 从全球任何地方访问
- ✅ 使用HTTPS加密，安全可靠
- ✅ 树莓派可以连接任何网络（WiFi、热点、有线）
- ✅ 数据完全存储在自己的树莓派上
- ✅ 外网访问始终稳定
- ✅ 网站已备案，合法合规

### 成本总结

```
阿里云服务器：38-108元/年（仅做流量中转）
域名：已有，0元
树莓派：已有，0元
电费：~50元/年

总计：~88-158元/年
```

### 使用建议

1. **定期检查**
   - 每周检查FRP连接状态
   - 每月检查SSL证书有效期
   - 定期备份数据

2. **安全建议**
   - 修改FRP Token（定期更换）
   - 限制FRP控制台访问
   - 定期查看访问日志

3. **性能优化**
   - 监控阿里云流量使用
   - 优化FRP连接池配置
   - 根据使用情况调整带宽

---

## 📚 相关文档

- [FRP快速参考指南](FRP快速参考指南.md) - 常用命令速查
- [ICP备案完整指南](ICP备案完整指南.md) - 备案相关
- [04-安全加固指南](04-安全加固指南.md) - 安全配置
- [05-问题排查手册](05-问题排查手册.md) - 故障排查

---

## 💡 提示和技巧

### 查看实时流量

在阿里云服务器上：

```bash
# 安装iftop
apt install -y iftop

# 查看实时流量
iftop -i eth0
```

### 备份配置

定期备份重要配置：

```bash
# 阿里云服务器
cp /etc/frp/frps.ini ~/frps.ini.backup
cp /etc/letsencrypt/live/piowncloud.com/fullchain.pem ~/cert_backup/

# 树莓派
cp /etc/frp/frpc.ini ~/frpc.ini.backup
```

### 日志轮转

防止日志文件过大：

```bash
# 在阿里云服务器上
nano /etc/logrotate.d/frps
```

添加：

```
/var/log/frp/frps.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
```

---

祝你使用愉快！🎊

如有问题，随时查阅本文档或相关文档。







