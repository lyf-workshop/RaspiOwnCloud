# 阿里云DNS自动更新脚本使用说明

## ✅ 当前状态

**DNS更新功能已成功配置并运行！**

从测试结果可以看到：
- ✅ AccessKey配置正确
- ✅ RR参数问题已解决（主域名使用`@`）
- ✅ DNS记录成功更新：`piowncloud.com -> 202.99.220.179`

## 📋 功能说明

这个脚本会自动检测你的公网IP变化，并更新阿里云DNS记录。

### 工作原理

1. **获取当前公网IP**：从多个IP查询服务获取
2. **查询现有DNS记录**：从阿里云获取当前DNS记录的IP
3. **比较IP**：如果IP变化，则更新DNS记录
4. **更新DNS**：调用阿里云API更新A记录

## 🔧 配置检查

### 1. 确认配置正确

```bash
# 检查配置
bash scripts/check_aliyun_config.sh
```

应该显示：
- ✅ AccessKey ID已配置
- ✅ AccessKey Secret已配置
- ✅ 域名已配置
- ✅ 子域名已配置

### 2. 手动测试

```bash
# 手动运行一次
bash scripts/update_aliyun_dns.sh
```

**成功输出示例：**
```
[2025-12-11 16:32:51] 正在获取当前公网IP...
[INFO] 当前公网IP: 202.99.220.179
[INFO] 正在查询DNS记录: @.piowncloud.com
[DEBUG] 找到主域名记录: RecordId=1998288633480385536, RR='@', Value=119.237.255.92
[INFO] DNS记录当前IP: 119.237.255.92
[INFO] IP已变化，正在更新DNS记录...
[DEBUG] 更新参数: RecordId=1998288633480385536, RR='@', Value=202.99.220.179, TTL=600
[SUCCESS] DNS记录已更新: piowncloud.com -> 202.99.220.179
```

## ⚙️ 设置定时任务

### 方法一：使用crontab（推荐）

```bash
# 编辑定时任务
crontab -e

# 添加以下行（每5分钟检查一次）
*/5 * * * * /opt/raspberrycloud/scripts/update_aliyun_dns.sh

# 或者每10分钟检查一次（更节省API调用）
*/10 * * * * /opt/raspberrycloud/scripts/update_aliyun_dns.sh
```

### 方法二：使用systemd timer（更可靠）

创建timer文件：

```bash
sudo nano /etc/systemd/system/aliyun-dns-update.timer
```

内容：
```ini
[Unit]
Description=Aliyun DNS Update Timer
After=network.target

[Timer]
OnBootSec=5min
OnUnitActiveSec=10min
Unit=aliyun-dns-update.service

[Install]
WantedBy=timers.target
```

创建service文件：

```bash
sudo nano /etc/systemd/system/aliyun-dns-update.service
```

内容：
```ini
[Unit]
Description=Aliyun DNS Update Service
After=network.target

[Service]
Type=oneshot
User=pi
Environment="ALIYUN_ACCESS_KEY_ID=你的AccessKey ID"
Environment="ALIYUN_ACCESS_KEY_SECRET=你的AccessKey Secret"
Environment="ALIYUN_DOMAIN=piowncloud.com"
Environment="ALIYUN_SUBDOMAIN=@"
ExecStart=/usr/bin/python3 /opt/raspberrycloud/scripts/update_aliyun_dns.py
StandardOutput=journal
StandardError=journal
```

启用并启动：

```bash
sudo systemctl daemon-reload
sudo systemctl enable aliyun-dns-update.timer
sudo systemctl start aliyun-dns-update.timer

# 查看状态
sudo systemctl status aliyun-dns-update.timer
```

## 📊 查看日志

### 方法一：查看系统日志（如果使用systemd）

```bash
# 查看最近10条日志
sudo journalctl -u aliyun-dns-update.service -n 10

# 实时查看日志
sudo journalctl -u aliyun-dns-update.service -f
```

### 方法二：查看文件日志（如果使用crontab）

```bash
# 查看日志文件
sudo tail -f /var/log/aliyun_dns_update.log

# 如果没有权限，可以修改日志路径
# 编辑 scripts/update_aliyun_dns.sh，修改 LOG_FILE 变量
```

## ⚠️ 常见问题

### Q1: 网络错误 - DNS解析失败

**现象：**
```
[WARNING] 网络错误: DNS解析失败，可能是临时网络问题
```

**原因：** 临时网络不稳定，DNS解析失败

**解决方法：**
- 这是正常现象，脚本会在下次定时任务时自动重试
- 如果频繁出现，检查网络连接稳定性
- 可以增加重试间隔（如改为每10分钟检查一次）

### Q2: IP未变化，无需更新

**现象：**
```
[INFO] IP未变化，无需更新
```

**说明：** 这是正常情况，说明你的公网IP没有变化，DNS记录已经是正确的。

### Q3: 无法获取当前公网IP

**现象：**
```
[ERROR] 无法获取当前公网IP，可能是网络问题
```

**解决方法：**
1. 检查网络连接：`ping -c 3 8.8.8.8`
2. 检查DNS解析：`nslookup api.ip.sb`
3. 如果所有IP查询服务都失败，可能是网络完全断开

### Q4: 未找到DNS记录

**现象：**
```
[ERROR] 未找到DNS记录: @.piowncloud.com
```

**解决方法：**
1. 登录阿里云DNS控制台
2. 确认域名 `piowncloud.com` 下是否有A记录
3. 确认主机记录（RR）是 `@`（主域名）
4. 如果不存在，请先创建DNS记录

## 🔍 验证DNS更新

### 方法一：使用nslookup

```bash
# 查询DNS记录
nslookup piowncloud.com

# 应该显示更新后的IP地址
```

### 方法二：使用dig

```bash
# 查询DNS记录
dig piowncloud.com +short

# 应该返回更新后的IP地址
```

### 方法三：在线工具

访问以下网站查询：
- https://www.whatsmydns.net/
- https://dnschecker.org/
- https://tool.chinaz.com/dns/

输入域名 `piowncloud.com`，查看A记录是否已更新。

## 📝 注意事项

1. **API调用限制**：阿里云DNS API有调用频率限制，建议不要设置太频繁（建议5-10分钟一次）

2. **网络稳定性**：如果网络不稳定，可能会出现临时错误，这是正常的，脚本会在下次运行时重试

3. **IP变化频率**：如果你的公网IP变化不频繁，可以设置更长的检查间隔（如30分钟或1小时）

4. **日志管理**：定期清理日志文件，避免占用过多磁盘空间

5. **安全性**：AccessKey具有DNS管理权限，请妥善保管，建议使用RAM子账号（参考《阿里云RAM子账号配置指南.md》）

## 🎉 完成

现在你的DNS记录会自动更新了！当你的公网IP变化时，脚本会自动检测并更新DNS记录，确保域名始终指向正确的IP地址。

