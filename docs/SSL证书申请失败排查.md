# SSL证书申请失败排查指南

## 错误分析

### 错误1：`www.piowncloud.com` - Connection refused (119.237.255.92)
**原因：** DNS记录指向旧IP，且该IP无法访问

### 错误2：`piowncloud.com` - Timeout (202.99.220.179)
**原因：** 端口转发未配置或防火墙阻止

## 🔍 排查步骤

### 步骤1：检查DNS记录

```bash
# 检查主域名DNS记录
nslookup piowncloud.com

# 检查www子域名DNS记录
nslookup www.piowncloud.com

# 应该都指向当前公网IP: 202.99.220.179
```

**如果DNS记录不正确：**

1. **检查DNS更新脚本是否运行：**
   ```bash
   # 手动运行DNS更新脚本
   bash /opt/raspberrycloud/scripts/update_aliyun_dns.sh
   ```

2. **检查www子域名是否配置了DNS记录：**
   - 登录阿里云DNS控制台
   - 确认是否有 `www` 的A记录
   - 如果没有，需要添加：
     - 记录类型：A
     - 主机记录：www
     - 记录值：202.99.220.179（当前公网IP）

3. **等待DNS传播（5-30分钟）**

### 步骤2：检查端口转发

**在笔记本上检查：**

```bash
# 检查80端口是否可以从外网访问
# 在树莓派上执行
curl -I http://localhost

# 应该返回HTTP响应
```

**检查Windows端口转发：**

1. 打开PowerShell（管理员）
2. 检查端口转发规则：
   ```powershell
   netsh interface portproxy show all
   ```
3. 确认是否有80端口的转发规则

**如果没有，添加端口转发：**

```powershell
# 获取树莓派内网IP（在树莓派上执行 hostname -I）
# 假设树莓派IP是 192.168.137.100

# 添加80端口转发
netsh interface portproxy add v4tov4 listenport=80 listenaddress=0.0.0.0 connectport=80 connectaddress=192.168.137.100

# 添加443端口转发
netsh interface portproxy add v4tov4 listenport=443 listenaddress=0.0.0.0 connectport=443 connectaddress=192.168.137.100

# 验证
netsh interface portproxy show all
```

### 步骤3：检查防火墙

**在树莓派上：**

```bash
# 检查UFW状态
sudo ufw status

# 如果80端口未开放，添加规则
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 重新加载
sudo ufw reload
```

**在Windows笔记本上：**

1. 打开"Windows Defender 防火墙"
2. 点击"高级设置"
3. 检查"入站规则"中是否有允许80和443端口的规则
4. 如果没有，创建新规则允许这些端口

### 步骤4：检查Nginx配置

```bash
# 检查Nginx配置
sudo nano /etc/nginx/sites-available/raspberrycloud
```

**确认配置包含：**

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name piowncloud.com www.piowncloud.com;  # 确认域名正确

    # Let's Encrypt验证（必须）
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # 其他配置...
}
```

**创建certbot目录（如果不存在）：**

```bash
sudo mkdir -p /var/www/certbot
sudo chown -R www-data:www-data /var/www/certbot
```

**测试并重载Nginx：**

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 步骤5：测试HTTP访问

**从外网测试（使用手机4G或朋友电脑）：**

```bash
# 测试主域名
curl -I http://piowncloud.com

# 测试www子域名
curl -I http://www.piowncloud.com

# 应该返回HTTP 200或301响应
```

**如果无法访问，检查：**
1. DNS是否正确解析
2. 端口转发是否正确
3. 防火墙是否开放

## 🔧 解决方案

### 方案A：先修复DNS和端口转发，再申请证书

1. **更新DNS记录（包括www子域名）**
2. **配置端口转发（80和443端口）**
3. **等待DNS传播（10-30分钟）**
4. **验证HTTP访问正常**
5. **重新申请证书**

### 方案B：只申请主域名证书（临时方案）

如果www子域名暂时无法配置，可以先只申请主域名：

```bash
# 只申请主域名证书
sudo certbot --nginx -d piowncloud.com

# 等www子域名配置好后再添加
sudo certbot --nginx -d piowncloud.com -d www.piowncloud.com --expand
```

### 方案C：使用standalone模式（如果端口转发有问题）

```bash
# 1. 临时停止Nginx
sudo systemctl stop nginx

# 2. 使用standalone模式申请证书
sudo certbot certonly --standalone -d piowncloud.com -d www.piowncloud.com

# 3. 启动Nginx
sudo systemctl start nginx

# 4. 手动配置Nginx使用证书（见下一步）
```

## 📝 完整修复流程

### 1. 更新DNS记录（包括www）

```bash
# 在树莓派上执行
cd /opt/raspberrycloud

# 检查当前公网IP
curl -s https://api.ip.sb/ip

# 手动更新DNS（如果需要）
# 登录阿里云DNS控制台，添加或更新：
# - @ (主域名) → 当前公网IP
# - www (子域名) → 当前公网IP
```

### 2. 配置Windows端口转发

```powershell
# 在Windows PowerShell（管理员）中执行
# 获取树莓派IP（在树莓派上执行 hostname -I）

# 添加端口转发
netsh interface portproxy add v4tov4 listenport=80 listenaddress=0.0.0.0 connectport=80 connectaddress=树莓派IP
netsh interface portproxy add v4tov4 listenport=443 listenaddress=0.0.0.0 connectport=443 connectaddress=树莓派IP

# 验证
netsh interface portproxy show all
```

### 3. 检查防火墙

```bash
# 在树莓派上
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

### 4. 等待DNS传播并验证

```bash
# 等待10-30分钟
# 然后验证DNS
nslookup piowncloud.com
nslookup www.piowncloud.com

# 验证HTTP访问
curl -I http://piowncloud.com
curl -I http://www.piowncloud.com
```

### 5. 重新申请证书

```bash
# 确认DNS和HTTP访问都正常后
sudo certbot --nginx -d piowncloud.com -d www.piowncloud.com
```

## ⚠️ 注意事项

1. **DNS传播时间：** 通常5-30分钟，最长48小时
2. **端口转发：** 确保80和443端口都正确转发
3. **防火墙：** 确保树莓派和Windows防火墙都允许这些端口
4. **Nginx配置：** 确保server_name包含两个域名
5. **certbot目录：** 确保 `/var/www/certbot` 目录存在且有正确权限

## 🎯 快速检查清单

- [ ] DNS记录已更新（主域名和www子域名）
- [ ] DNS解析正确（nslookup验证）
- [ ] 端口转发已配置（80和443）
- [ ] 防火墙已开放（树莓派和Windows）
- [ ] Nginx配置正确（server_name包含两个域名）
- [ ] certbot目录存在且有权限
- [ ] HTTP访问正常（从外网测试）
- [ ] 等待DNS传播完成

完成以上检查后，重新申请证书应该可以成功。

