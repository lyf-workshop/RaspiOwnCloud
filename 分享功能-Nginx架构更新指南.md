# 分享功能修复 - Nginx+双文件夹架构更新指南

## 🏗️ 系统架构说明

你的系统使用的是：
- **Nginx** → 前端静态文件服务器（位于 `/var/www/raspberrycloud/`）
- **FastAPI** → 后端API服务器（位于 `/opt/raspberrycloud/backend/`）
- **双文件夹部署** → 更新目录 + 生产目录

```
用户请求
    ↓
  Nginx (:80)
    ├─ /api/*     → 代理到 FastAPI (:8000)
    ├─ /share/*   → 需要配置（新增）
    └─ /*         → 静态文件 (/var/www/raspberrycloud/)
```

## 📋 需要修改的文件

### 更新文件夹（你的开发目录）
- ✅ `frontend/share.html` - 分享页面（新增）
- ✅ `frontend/js/share.js` - 分享逻辑（新增）
- ✅ `config/nginx.conf` - Nginx配置（需要修改）

### 生产环境（自动部署）
- `/var/www/raspberrycloud/share.html` - 由脚本自动复制
- `/var/www/raspberrycloud/js/share.js` - 由脚本自动复制
- `/etc/nginx/sites-available/raspberrycloud` - 需要手动更新

## 🚀 完整更新步骤

### 步骤1: 更新Nginx配置文件（重要！）

首先修改项目中的Nginx配置模板：

```bash
# 在更新文件夹中编辑
cd ~/Desktop/Github/RaspiOwnCloud
nano config/nginx.conf
```

在 **第70行**（`# 前端静态文件` 之前）添加以下内容：

```nginx
    # 分享页面路由（在 location / 之前添加）
    location ~ ^/share/[a-zA-Z0-9]+$ {
        root /var/www/raspberrycloud;
        try_files /share.html =404;
    }
```

**完整的Nginx配置应该是这样的顺序**：

```nginx
    # ... 前面的配置 ...

    # 静态资源缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2)$ {
        root /var/www/raspberrycloud;
        expires 7d;
        add_header Cache-Control "public, immutable";
    }

    # 分享页面路由（新增这部分）
    location ~ ^/share/[a-zA-Z0-9]+$ {
        root /var/www/raspberrycloud;
        try_files /share.html =404;
    }

    # 前端静态文件（放在最后，作为默认）
    location / {
        root /var/www/raspberrycloud;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
```

保存并退出（Ctrl+O，Enter，Ctrl+X）。

### 步骤2: 拉取或创建前端文件

#### 选项A: 从GitHub拉取（如果已提交）

```bash
cd ~/Desktop/Github/RaspiOwnCloud
git pull origin main
```

#### 选项B: 手动创建文件（如果还未提交）

```bash
cd ~/Desktop/Github/RaspiOwnCloud

# 创建分享页面
nano frontend/share.html
# 粘贴完整的share.html内容（见附录）

# 创建分享脚本
nano frontend/js/share.js
# 粘贴完整的share.js内容（见附录）
```

### 步骤3: 运行快速更新脚本

```bash
cd ~/Desktop/Github/RaspiOwnCloud
bash scripts/quick_update.sh
```

这个脚本会：
- ✅ 复制 `frontend/*` 到 `/var/www/raspberrycloud/`
- ✅ 复制 `backend/*` 到 `/opt/raspberrycloud/backend/`
- ✅ 设置正确的权限
- ✅ 重启FastAPI服务

### 步骤4: 更新Nginx配置（需要手动）

```bash
# 编辑Nginx配置
sudo nano /etc/nginx/sites-available/raspberrycloud
```

找到 `# 前端静态文件` 这一行（大约第70行），在它**之前**添加：

```nginx
    # 分享页面路由
    location ~ ^/share/[a-zA-Z0-9]+$ {
        root /var/www/raspberrycloud;
        try_files /share.html =404;
    }
```

保存并退出。

### 步骤5: 测试Nginx配置

```bash
# 测试配置是否正确
sudo nginx -t

# 应该看到：
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 步骤6: 重载Nginx

```bash
# 重载Nginx配置
sudo systemctl reload nginx

# 查看Nginx状态
sudo systemctl status nginx
```

### 步骤7: 验证文件是否存在

```bash
# 检查前端文件
ls -lh /var/www/raspberrycloud/share.html
ls -lh /var/www/raspberrycloud/js/share.js

# 应该看到文件存在且有最新的时间戳
```

## ✅ 验证更新成功

### 1. 检查文件

```bash
# 运行检查脚本
cat << 'EOF' | bash
echo "=== 检查分享功能文件 ==="
echo ""

# 检查前端文件
if [ -f "/var/www/raspberrycloud/share.html" ]; then
    echo "✅ share.html 存在"
    ls -lh /var/www/raspberrycloud/share.html
else
    echo "❌ share.html 不存在"
fi

if [ -f "/var/www/raspberrycloud/js/share.js" ]; then
    echo "✅ share.js 存在"
    ls -lh /var/www/raspberrycloud/js/share.js
else
    echo "❌ share.js 不存在"
fi

# 检查Nginx配置
echo ""
echo "=== 检查Nginx配置 ==="
if grep -q "location ~ \^/share/" /etc/nginx/sites-available/raspberrycloud; then
    echo "✅ Nginx分享路由已配置"
else
    echo "❌ Nginx分享路由未配置"
fi

# 检查服务状态
echo ""
echo "=== 检查服务状态 ==="
echo -n "Nginx: "
systemctl is-active nginx
echo -n "RaspberryCloud: "
systemctl is-active raspberrycloud

echo ""
EOF
```

### 2. 浏览器测试

```bash
# 测试分享页面是否可访问（会显示404是正常的，因为分享码不存在）
curl -I http://localhost/share/test123

# 应该返回 200 OK
```

### 3. 完整功能测试

1. 浏览器访问：`http://树莓派IP/` 或 `http://raspberrycloud.local/`
2. 登录账号
3. 选择一个文件，点击"分享"按钮
4. 创建分享（勾选"需要提取码"）
5. 复制分享链接
6. 在新标签页打开分享链接
7. ✅ 应该看到分享页面
8. 输入提取码
9. ✅ 点击下载，文件应该开始下载

## 🎯 更新后的架构

```
用户访问分享链接: http://your-ip/share/abc123
         ↓
    Nginx (:80)
         ↓
    匹配规则: location ~ ^/share/[a-zA-Z0-9]+$
         ↓
    返回: /var/www/raspberrycloud/share.html
         ↓
    share.html 加载 share.js
         ↓
    share.js 调用 API: /api/shares/info/abc123
         ↓
    Nginx代理到 FastAPI (:8000)
         ↓
    返回文件信息
         ↓
    显示分享页面 + 下载按钮
```

## 🔧 故障排查

### 问题1: 分享链接显示404

**原因**: Nginx配置未更新

**解决**:
```bash
# 检查Nginx配置
sudo nginx -t

# 查看配置文件
sudo nano /etc/nginx/sites-available/raspberrycloud

# 确认有分享路由配置
grep -A 3 "location ~ \^/share/" /etc/nginx/sites-available/raspberrycloud

# 重载Nginx
sudo systemctl reload nginx
```

### 问题2: share.html 文件不存在

**原因**: 更新脚本未执行或文件未复制

**解决**:
```bash
# 检查更新文件夹中是否有文件
ls -lh ~/Desktop/Github/RaspiOwnCloud/frontend/share.html

# 手动复制
sudo cp ~/Desktop/Github/RaspiOwnCloud/frontend/share.html /var/www/raspberrycloud/
sudo cp ~/Desktop/Github/RaspiOwnCloud/frontend/js/share.js /var/www/raspberrycloud/js/

# 设置权限
sudo chown www-data:www-data /var/www/raspberrycloud/share.html
sudo chown www-data:www-data /var/www/raspberrycloud/js/share.js
```

### 问题3: API请求失败

**原因**: 后端服务未运行

**解决**:
```bash
# 检查后端服务
sudo systemctl status raspberrycloud

# 查看日志
sudo journalctl -u raspberrycloud -n 50

# 重启服务
sudo systemctl restart raspberrycloud
```

### 问题4: 显示"加载分享信息失败"

**原因**: JavaScript配置问题

**解决**:
```bash
# 检查share.js中的API_BASE_URL
grep "API_BASE_URL" /var/www/raspberrycloud/js/config.js

# 应该是相对路径或正确的域名
# 正确: const API_BASE_URL = window.location.protocol + '//' + window.location.host + '/api';
```

## 📝 完整命令参考

```bash
# === 准备更新 ===
cd ~/Desktop/Github/RaspiOwnCloud
git pull origin main

# === 部署前端和后端 ===
bash scripts/quick_update.sh

# === 更新Nginx配置 ===
sudo nano /etc/nginx/sites-available/raspberrycloud
# 添加分享路由配置

# === 测试并重载Nginx ===
sudo nginx -t
sudo systemctl reload nginx

# === 验证文件 ===
ls -lh /var/www/raspberrycloud/share.html
ls -lh /var/www/raspberrycloud/js/share.js

# === 查看服务状态 ===
sudo systemctl status nginx
sudo systemctl status raspberrycloud

# === 查看日志 ===
sudo journalctl -u raspberrycloud -f
sudo tail -f /var/log/nginx/raspberrycloud_access.log
sudo tail -f /var/log/nginx/raspberrycloud_error.log
```

## 🎨 Nginx配置详解

### 为什么需要特殊的location规则？

```nginx
# ❌ 错误：没有特殊规则
location / {
    try_files $uri $uri/ /index.html;
}
# 访问 /share/abc123 会fallback到 index.html（错误页面）

# ✅ 正确：添加分享路由
location ~ ^/share/[a-zA-Z0-9]+$ {
    try_files /share.html =404;
}
location / {
    try_files $uri $uri/ /index.html;
}
# 访问 /share/abc123 会返回 share.html（正确）
```

### location规则解释

```nginx
location ~ ^/share/[a-zA-Z0-9]+$ {
    root /var/www/raspberrycloud;
    try_files /share.html =404;
}
```

- `~` - 使用正则表达式匹配
- `^/share/` - URL以 `/share/` 开头
- `[a-zA-Z0-9]+` - 后面跟着一个或多个字母或数字（分享码）
- `$` - URL结尾（不允许有其他路径）
- `try_files /share.html` - 返回share.html文件
- `=404` - 如果文件不存在，返回404

## 📊 更新前后对比

### 更新前 ❌
```
访问: http://your-ip/share/abc123
  ↓
Nginx: 没有特殊规则
  ↓
fallback到: /index.html
  ↓
显示: 首页（需要登录）或404
```

### 更新后 ✅
```
访问: http://your-ip/share/abc123
  ↓
Nginx: 匹配分享路由规则
  ↓
返回: /share.html
  ↓
JavaScript: 解析URL中的分享码
  ↓
API请求: /api/shares/info/abc123
  ↓
显示: 分享页面（文件信息+下载按钮）
```

## 🎯 快速测试清单

```bash
# 1. 文件检查
[ ] /var/www/raspberrycloud/share.html 存在
[ ] /var/www/raspberrycloud/js/share.js 存在
[ ] /var/www/raspberrycloud/js/config.js 存在

# 2. Nginx配置
[ ] /etc/nginx/sites-available/raspberrycloud 包含分享路由
[ ] sudo nginx -t 测试通过
[ ] Nginx已重载

# 3. 服务状态
[ ] nginx 运行中
[ ] raspberrycloud 运行中

# 4. 功能测试
[ ] 可以创建分享
[ ] 复制分享链接
[ ] 打开分享链接显示分享页面
[ ] 可以下载文件
[ ] 提取码验证正常
```

## 💡 重要提示

### 1. Nginx vs FastAPI静态文件

你的系统使用Nginx提供静态文件，**不需要**在`backend/main.py`中添加`StaticFiles`挂载。

如果你之前添加了以下代码，可以**删除**：

```python
# 这些在Nginx架构中不需要
app.mount("/css", StaticFiles(directory="../frontend/css"), name="css")
app.mount("/js", StaticFiles(directory="../frontend/js"), name="js")

@app.get("/share/{share_code}")
async def share_page(share_code: str):
    # 这个路由不需要，Nginx会处理
    ...
```

### 2. 配置更新顺序

正确的顺序是：
1. 更新代码文件（share.html, share.js）
2. 运行 quick_update.sh（复制文件）
3. 更新Nginx配置
4. 重载Nginx

### 3. 备份配置

更新前备份Nginx配置：

```bash
sudo cp /etc/nginx/sites-available/raspberrycloud /etc/nginx/sites-available/raspberrycloud.backup.$(date +%Y%m%d)
```

## 📚 相关文档

- [双文件夹部署架构说明](docs/双文件夹部署架构说明.md)
- [系统部署教程](docs/02-系统部署教程.md)
- [Nginx配置详解](config/nginx.conf)

---

## 附录：完整的Nginx配置示例

```nginx
# 完整的HTTP服务器配置
server {
    listen 80;
    listen [::]:80;
    server_name _;

    # Let's Encrypt验证
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # 客户端最大请求体
    client_max_body_size 10G;
    client_body_buffer_size 128k;
    client_body_timeout 3600s;
    
    # 代理超时设置
    proxy_connect_timeout 3600s;
    proxy_send_timeout 3600s;
    proxy_read_timeout 3600s;

    # API代理
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
        proxy_request_buffering off;
    }

    # WebSocket代理
    location /ws/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }

    # 静态资源缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2)$ {
        root /var/www/raspberrycloud;
        expires 7d;
        add_header Cache-Control "public, immutable";
    }

    # 分享页面路由（新增）
    location ~ ^/share/[a-zA-Z0-9]+$ {
        root /var/www/raspberrycloud;
        try_files /share.html =404;
    }

    # 前端静态文件（默认）
    location / {
        root /var/www/raspberrycloud;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # 日志
    access_log /var/log/nginx/raspberrycloud_access.log;
    error_log /var/log/nginx/raspberrycloud_error.log;
}
```

好了！按照这个指南更新，分享功能就能正常工作了！🎉




