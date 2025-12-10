# 从GitHub重新部署完整步骤

本文档提供从GitHub重新下载项目并完整重新部署的详细操作步骤。

## 📋 操作概览

```
1. 清理旧部署 → 2. 从GitHub下载 → 3. 配置环境 → 4. 部署后端 → 5. 部署前端 → 6. 配置Nginx → 7. 启动服务
```

---

## 🧹 步骤1：清理旧部署

**操作位置**：在树莓派上通过SSH连接

### 1.1 停止并删除系统服务

```bash
# 当前位置：任意目录（建议在用户主目录 ~）

# 停止服务
sudo systemctl stop raspberrycloud

# 禁用服务（取消开机自启）
sudo systemctl disable raspberrycloud

# 删除服务文件
sudo rm /etc/systemd/system/raspberrycloud.service

# 重新加载systemd
sudo systemctl daemon-reload
```

### 1.2 删除项目目录和前端文件

```bash
# 当前位置：任意目录

# 删除项目目录（包含代码、虚拟环境等）
sudo rm -rf /opt/raspberrycloud

# 删除前端文件
sudo rm -rf /var/www/raspberrycloud

# 删除日志目录
sudo rm -rf /var/log/raspberrycloud
```

### 1.3 删除Nginx配置

```bash
# 当前位置：任意目录

# 删除Nginx配置软链接
sudo rm /etc/nginx/sites-enabled/raspberrycloud

# 删除Nginx配置文件
sudo rm /etc/nginx/sites-available/raspberrycloud

# 恢复默认配置（如果存在备份）
if [ -f "/etc/nginx/sites-available/default.backup" ]; then
    sudo cp /etc/nginx/sites-available/default.backup /etc/nginx/sites-available/default
    sudo ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
fi

# 测试Nginx配置并重启
sudo nginx -t
sudo systemctl restart nginx
```

**✅ 步骤1完成检查**：
- 运行 `sudo systemctl status raspberrycloud` 应该显示 "could not be found"
- 运行 `ls /opt/raspberrycloud` 应该显示 "No such file or directory"

---

## 📥 步骤2：从GitHub下载项目

**操作位置**：在树莓派上，准备创建项目目录

### 2.1 创建项目目录

```bash
# 当前位置：任意目录（建议在用户主目录 ~）

# 创建应用目录
sudo mkdir -p /opt/raspberrycloud

# 设置目录所有者（$USER 是当前登录用户，通常是 pi）
sudo chown -R $USER:$USER /opt/raspberrycloud

# 进入项目目录
cd /opt/raspberrycloud
```

### 2.2 从GitHub克隆项目

```bash
# 当前位置：/opt/raspberrycloud

# 从GitHub克隆项目到当前目录（注意末尾的 . 表示当前目录）
git clone https://github.com/lyf-workshop/RaspiOwnCloud.git .

# 如果提示需要安装git，先安装：
# sudo apt install -y git
```

### 2.3 验证文件结构

```bash
# 当前位置：/opt/raspberrycloud

# 查看目录结构
ls -la

# 应该看到以下目录：
# backend/  frontend/  config/  scripts/  docs/

# 或者使用tree命令（如果已安装）
tree -L 2
# 如果未安装tree：sudo apt install -y tree
```

**✅ 步骤2完成检查**：
- `/opt/raspberrycloud` 目录存在
- 目录中包含 `backend/`、`frontend/`、`config/`、`scripts/`、`docs/` 等文件夹

---

## 🐍 步骤3：部署后端服务

**操作位置**：在项目目录下操作

### 3.1 创建Python虚拟环境

```bash
# 当前位置：/opt/raspberrycloud

# 确保在项目根目录
pwd
# 应该显示：/opt/raspberrycloud

# 创建虚拟环境（会在当前目录创建 venv 文件夹）
python3 -m venv venv

# 激活虚拟环境（注意：每次新开终端都需要重新激活）
source venv/bin/activate

# 激活后，命令提示符前会显示 (venv)

# 升级pip到最新版本
pip install --upgrade pip
```

### 3.2 安装Python依赖

```bash
# 当前位置：/opt/raspberrycloud
# 确保虚拟环境已激活（命令提示符前有 (venv)）

# 进入backend目录
cd backend

# 安装所有依赖（需要5-10分钟，请耐心等待）
pip install -r requirements.txt

# 如果安装过程中出错，可以尝试单独安装主要依赖：
# pip install fastapi==0.104.1
# pip install uvicorn[standard]==0.24.0
# pip install python-multipart==0.0.6
# pip install aiofiles==23.2.1
# pip install python-jose[cryptography]==3.3.0
# pip install passlib[bcrypt]==1.7.4
# pip install sqlalchemy==2.0.23
```

### 3.3 配置环境变量

```bash
# 当前位置：/opt/raspberrycloud/backend
# 确保虚拟环境已激活

# 复制配置模板
cp ../config/env.example .env

# 生成随机密钥
openssl rand -hex 32
# 复制输出的密钥（类似：a1b2c3d4e5f6...）

# 编辑配置文件
nano .env
```

**在nano编辑器中，修改以下内容**：

```bash
# 应用配置
APP_NAME=RaspberryCloud
APP_VERSION=1.0.0
DEBUG=false

# 安全配置（将刚才生成的密钥粘贴到SECRET_KEY）
SECRET_KEY=粘贴刚才生成的密钥
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080

# 数据库配置（SQLite，推荐）
DATABASE_URL=sqlite:////opt/raspberrycloud/backend/raspberrycloud.db

# 存储配置（根据你的存储方案调整）
# 如果使用SD卡存储：
STORAGE_PATH=/mnt/cloud_storage/users
SHARE_PATH=/mnt/cloud_storage/shares
TEMP_PATH=/mnt/cloud_storage/temp
BACKUP_PATH=/mnt/cloud_storage/backups

# 文件限制
MAX_FILE_SIZE=10737418240  # 10GB
MAX_UPLOAD_THREADS=5

# 默认管理员账户
ADMIN_USERNAME=admin
ADMIN_PASSWORD=RaspberryCloud2024!
ADMIN_EMAIL=admin@raspberrycloud.local
```

**保存并退出nano**：
- 按 `Ctrl + O` 保存
- 按 `Enter` 确认文件名
- 按 `Ctrl + X` 退出

### 3.4 初始化数据库

```bash
# 当前位置：/opt/raspberrycloud/backend
# 确保虚拟环境已激活

# 方法1：使用Python初始化（推荐）
python -c "from models import init_db; init_db()"

# 方法2：如果方法1失败，使用SQL脚本（SQLite）
# sqlite3 raspberrycloud.db < database.sql

# 验证数据库文件已创建
ls -lh raspberrycloud.db
# 应该看到 raspberrycloud.db 文件
```

### 3.5 测试后端服务

```bash
# 当前位置：/opt/raspberrycloud/backend
# 确保虚拟环境已激活

# 启动测试服务器
uvicorn main:app --host 0.0.0.0 --port 8000

# 看到类似以下输出表示启动成功：
# INFO:     Started server process [xxxx]
# INFO:     Uvicorn running on http://0.0.0.0:8000
```

**在另一个SSH终端窗口测试**（保持上面的服务器运行）：

```bash
# 在新终端中测试
curl http://localhost:8000/api/health

# 应该返回：{"status":"healthy","version":"1.0.0"}
```

**测试完成后，回到运行服务器的终端，按 `Ctrl + C` 停止服务器**

**✅ 步骤3完成检查**：
- 虚拟环境已创建（`/opt/raspberrycloud/venv` 存在）
- Python依赖已安装（`pip list` 可以看到 fastapi、uvicorn 等）
- `.env` 配置文件已创建并配置
- 数据库文件已创建（`raspberrycloud.db` 存在）
- 后端服务可以正常启动

---

## 🌐 步骤4：部署前端

**操作位置**：在项目目录下操作

### 4.1 复制前端文件

```bash
# 当前位置：/opt/raspberrycloud（项目根目录）

# 创建Web根目录
sudo mkdir -p /var/www/raspberrycloud

# 复制前端文件
sudo cp -r frontend/* /var/www/raspberrycloud/

# 设置权限
sudo chown -R www-data:www-data /var/www/raspberrycloud
sudo chmod -R 755 /var/www/raspberrycloud
```

### 4.2 配置前端API地址

```bash
# 当前位置：任意目录

# 编辑前端配置文件
sudo nano /var/www/raspberrycloud/js/config.js
```

**确保文件内容如下**（通常已经是正确的，检查即可）：

```javascript
const API_BASE_URL = window.location.protocol + '//' + window.location.host + '/api';
const WS_BASE_URL = (window.location.protocol === 'https:' ? 'wss:' : 'ws:') + '//' + window.location.host + '/ws';
const MAX_FILE_SIZE = 10 * 1024 * 1024 * 1024; // 10GB
const CHUNK_SIZE = 5 * 1024 * 1024; // 5MB 分块上传
```

**保存并退出**：`Ctrl + O` → `Enter` → `Ctrl + X`

**✅ 步骤4完成检查**：
- `/var/www/raspberrycloud` 目录存在
- 目录中包含 `index.html`、`login.html`、`css/`、`js/` 等文件

---

## 🔧 步骤5：配置Nginx

**操作位置**：在项目目录下操作

### 5.1 备份默认配置

```bash
# 当前位置：任意目录

# 备份Nginx默认配置
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
```

### 5.2 创建应用配置

```bash
# 当前位置：任意目录

# 创建Nginx配置文件
sudo nano /etc/nginx/sites-available/raspberrycloud
```

**粘贴以下配置内容**：

```nginx
# 上游后端服务
upstream backend {
    server 127.0.0.1:8000;
}

# HTTP服务器
server {
    listen 80;
    listen [::]:80;
    server_name _;  # 后续替换为你的域名

    # 客户端最大请求体（允许大文件上传）
    client_max_body_size 10G;
    client_body_buffer_size 128k;
    client_body_timeout 3600s;
    
    # 代理超时设置
    proxy_connect_timeout 3600s;
    proxy_send_timeout 3600s;
    proxy_read_timeout 3600s;

    # 前端静态文件
    location / {
        root /var/www/raspberrycloud;
        index index.html;
        try_files $uri $uri/ /index.html;
        
        # 静态资源缓存
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2)$ {
            expires 7d;
            add_header Cache-Control "public, immutable";
        }
    }

    # API代理到后端
    location /api/ {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 支持大文件上传
        proxy_request_buffering off;
    }

    # WebSocket代理（文件同步）
    location /ws/ {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 日志
    access_log /var/log/nginx/raspberrycloud_access.log;
    error_log /var/log/nginx/raspberrycloud_error.log;
}
```

**保存并退出**：`Ctrl + O` → `Enter` → `Ctrl + X`

### 5.3 启用配置

```bash
# 当前位置：任意目录

# 创建软链接启用配置
sudo ln -s /etc/nginx/sites-available/raspberrycloud /etc/nginx/sites-enabled/

# 删除默认配置（如果存在）
sudo rm /etc/nginx/sites-enabled/default

# 测试配置语法
sudo nginx -t

# 应该显示：
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful

# 重启Nginx
sudo systemctl restart nginx
```

**✅ 步骤5完成检查**：
- Nginx配置测试通过（`nginx -t` 无错误）
- Nginx服务运行正常（`sudo systemctl status nginx` 显示 active）

---

## 🚀 步骤6：配置系统服务（开机自启）

**操作位置**：在项目目录下操作

### 6.1 创建systemd服务文件

```bash
# 当前位置：任意目录

# 创建服务文件
sudo nano /etc/systemd/system/raspberrycloud.service
```

**粘贴以下内容**：

```ini
[Unit]
Description=RaspberryCloud Private Cloud Storage Service
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/raspberrycloud/backend
Environment="PATH=/opt/raspberrycloud/venv/bin"
Environment="PYTHONUNBUFFERED=1"

# 启动命令
ExecStart=/opt/raspberrycloud/venv/bin/uvicorn main:app \
    --host 127.0.0.1 \
    --port 8000 \
    --workers 2 \
    --log-level info

# 自动重启
Restart=always
RestartSec=10

# 资源限制
LimitNOFILE=65536
MemoryLimit=512M

# 日志
StandardOutput=append:/var/log/raspberrycloud/backend.log
StandardError=append:/var/log/raspberrycloud/backend_error.log
SyslogIdentifier=raspberrycloud

[Install]
WantedBy=multi-user.target
```

**保存并退出**：`Ctrl + O` → `Enter` → `Ctrl + X`

### 6.2 创建日志目录

```bash
# 当前位置：任意目录

# 创建日志目录
sudo mkdir -p /var/log/raspberrycloud

# 设置权限
sudo chown -R www-data:www-data /var/log/raspberrycloud
```

### 6.3 启动服务

```bash
# 当前位置：任意目录

# 重新加载systemd配置
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start raspberrycloud

# 检查服务状态
sudo systemctl status raspberrycloud

# 应该显示：
# ● raspberrycloud.service - RaspberryCloud Private Cloud Storage Service
#    Loaded: loaded (/etc/systemd/system/raspberrycloud.service; disabled)
#    Active: active (running) since ...

# 设置开机自启
sudo systemctl enable raspberrycloud
```

**✅ 步骤6完成检查**：
- 服务状态为 `active (running)`
- 服务已设置为开机自启（`enabled`）

---

## 🧪 步骤7：测试部署

**操作位置**：在任意位置测试

### 7.1 测试后端API

```bash
# 当前位置：任意目录

# 健康检查
curl http://localhost/api/health

# 应该返回：{"status":"healthy","version":"1.0.0"}

# 测试登录API
curl -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"RaspberryCloud2024!"}'

# 应该返回包含 "access_token" 的JSON
```

### 7.2 测试Web界面

1. **在浏览器中访问**：`http://树莓派IP地址`
   - 应该看到登录页面

2. **使用默认账户登录**：
   - 用户名：`admin`
   - 密码：`RaspberryCloud2024!`

3. **测试功能**：
   - 上传小文件（<10MB）
   - 创建文件夹
   - 文件重命名
   - 文件删除
   - 文件预览

### 7.3 查看服务日志

```bash
# 查看服务状态
sudo systemctl status raspberrycloud

# 查看实时日志
sudo journalctl -u raspberrycloud -f

# 查看应用日志
sudo tail -f /var/log/raspberrycloud/backend.log

# 查看错误日志
sudo tail -f /var/log/raspberrycloud/backend_error.log
```

---

## ✅ 部署完成检查清单

- [ ] 项目代码已从GitHub下载到 `/opt/raspberrycloud`
- [ ] Python虚拟环境已创建并激活
- [ ] 所有Python依赖已安装
- [ ] `.env` 配置文件已创建并配置
- [ ] 数据库已初始化（`raspberrycloud.db` 存在）
- [ ] 前端文件已复制到 `/var/www/raspberrycloud`
- [ ] Nginx配置正确（`nginx -t` 通过）
- [ ] 系统服务已创建并启动（`systemctl status raspberrycloud` 显示 active）
- [ ] Web界面可访问（浏览器打开 `http://树莓派IP`）
- [ ] 可以登录默认管理员账户
- [ ] 文件上传/下载功能正常

---

## 🔧 常见问题

### 问题1：服务无法启动

```bash
# 查看详细错误
sudo journalctl -u raspberrycloud -n 50 --no-pager

# 检查端口是否被占用
sudo lsof -i :8000

# 检查虚拟环境
source /opt/raspberrycloud/venv/bin/activate
python -c "import fastapi"
```

### 问题2：Nginx 502错误

```bash
# 检查后端服务是否运行
sudo systemctl status raspberrycloud

# 检查后端端口
curl http://localhost:8000/api/health

# 查看Nginx错误日志
sudo tail -f /var/log/nginx/raspberrycloud_error.log
```

### 问题3：无法访问Web界面

```bash
# 检查Nginx状态
sudo systemctl status nginx

# 检查防火墙
sudo ufw status

# 如果防火墙开启，允许HTTP端口
sudo ufw allow 80/tcp
```

---

## 📝 重要提示

1. **修改默认密码**：首次登录后立即修改管理员密码！
2. **备份配置**：建议备份 `.env` 文件和数据库文件
3. **定期更新**：使用 `git pull` 更新代码，然后重启服务
4. **查看日志**：遇到问题时先查看日志文件

---

## 🎉 部署完成！

现在你的私有云存储系统已经重新部署完成。可以开始使用了！

**下一步**：
- [配置多端访问](03-多端访问配置.md) - 设置外网访问、HTTPS
- [安全加固](04-安全加固指南.md) - 增强系统安全性



