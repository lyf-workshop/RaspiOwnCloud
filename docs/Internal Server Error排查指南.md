# Internal Server Error 排查指南

当遇到 `Internal Server Error` 时，按照以下步骤排查：

## 🔍 步骤1：查看错误日志

### 1.1 查看应用错误日志

```bash
# 查看最近的错误日志（最重要！）
sudo tail -50 /var/log/raspberrycloud/backend_error.log

# 查看完整错误日志
sudo cat /var/log/raspberrycloud/backend_error.log
```

### 1.2 查看systemd日志

```bash
# 查看最近的系统日志
sudo journalctl -u raspberrycloud -n 50 --no-pager

# 查看实时日志
sudo journalctl -u raspberrycloud -f
```

### 1.3 查看应用日志

```bash
# 查看应用输出日志
sudo tail -50 /var/log/raspberrycloud/backend.log
```

---

## 🔧 步骤2：常见错误及解决方案

### 错误1：数据库未初始化或表不存在

**错误信息示例**：
```
sqlalchemy.exc.OperationalError: no such table: users
```

**解决方案**：

```bash
# 当前位置：/opt/raspberrycloud/backend
cd /opt/raspberrycloud/backend

# 激活虚拟环境
source ../venv/bin/activate

# 重新初始化数据库
python -c "from models import init_db; init_db()"

# 或者使用SQL脚本（如果Python方法失败）
sqlite3 raspberrycloud.db < database.sql

# 验证数据库
sqlite3 raspberrycloud.db ".tables"
# 应该看到：users  files  shares 等表

# 重启服务
sudo systemctl restart raspberrycloud
```

### 错误2：环境变量配置错误

**错误信息示例**：
```
KeyError: 'SECRET_KEY'
或
sqlalchemy.exc.OperationalError: unable to open database file
```

**解决方案**：

```bash
# 检查.env文件是否存在
ls -la /opt/raspberrycloud/backend/.env

# 如果不存在，创建它
cd /opt/raspberrycloud/backend
cp ../config/env.example .env

# 生成密钥
openssl rand -hex 32
# 复制输出的密钥

# 编辑配置文件
nano .env

# 确保以下配置正确：
# SECRET_KEY=你的密钥（必须填写）
# DATABASE_URL=sqlite:////opt/raspberrycloud/backend/raspberrycloud.db
# STORAGE_PATH=/mnt/cloud_storage/users（或你的存储路径）

# 重启服务
sudo systemctl restart raspberrycloud
```

### 错误3：Python依赖缺失

**错误信息示例**：
```
ModuleNotFoundError: No module named 'xxx'
ImportError: cannot import name 'xxx'
```

**解决方案**：

```bash
# 当前位置：/opt/raspberrycloud
cd /opt/raspberrycloud

# 激活虚拟环境
source venv/bin/activate

# 重新安装依赖
cd backend
pip install -r requirements.txt

# 如果安装失败，尝试单独安装主要依赖
pip install fastapi==0.104.1
pip install uvicorn[standard]==0.24.0
pip install python-multipart==0.0.6
pip install aiofiles==23.2.1
pip install python-jose[cryptography]==3.3.0
pip install passlib[bcrypt]==1.7.4
pip install sqlalchemy==2.0.23

# 重启服务
sudo systemctl restart raspberrycloud
```

### 错误4：数据库文件权限问题

**错误信息示例**：
```
sqlalchemy.exc.OperationalError: unable to open database file
```

**解决方案**：

```bash
# 检查数据库文件权限
ls -la /opt/raspberrycloud/backend/raspberrycloud.db

# 修复权限（服务以www-data用户运行）
sudo chown -R www-data:www-data /opt/raspberrycloud
sudo chmod -R 755 /opt/raspberrycloud
sudo chmod 664 /opt/raspberrycloud/backend/raspberrycloud.db

# 重启服务
sudo systemctl restart raspberrycloud
```

### 错误5：存储目录不存在或权限问题

**错误信息示例**：
```
FileNotFoundError: [Errno 2] No such file or directory: '/mnt/cloud_storage/users'
```

**解决方案**：

```bash
# 检查存储目录是否存在
ls -la /mnt/cloud_storage/

# 如果不存在，创建目录
sudo mkdir -p /mnt/cloud_storage/{users,shares,temp,backups}
sudo chown -R www-data:www-data /mnt/cloud_storage
sudo chmod -R 755 /mnt/cloud_storage

# 或者修改.env中的存储路径（如果使用SD卡存储）
# 编辑配置文件
nano /opt/raspberrycloud/backend/.env

# 修改为SD卡存储路径（如果适用）：
# STORAGE_PATH=/home/pi/cloud_storage/users
# SHARE_PATH=/home/pi/cloud_storage/shares
# TEMP_PATH=/home/pi/cloud_storage/temp
# BACKUP_PATH=/home/pi/cloud_storage/backups

# 创建对应目录
sudo mkdir -p /home/pi/cloud_storage/{users,shares,temp,backups}
sudo chown -R www-data:www-data /home/pi/cloud_storage
sudo chmod -R 755 /home/pi/cloud_storage

# 重启服务
sudo systemctl restart raspberrycloud
```

### 错误6：密码哈希问题

**错误信息示例**：
```
ValueError: Invalid bcrypt hash
或
passlib.exc.UnknownHashError
```

**解决方案**：

```bash
# 重新初始化数据库（会重置所有用户，包括管理员）
cd /opt/raspberrycloud/backend
source ../venv/bin/activate

# 备份旧数据库（可选）
cp raspberrycloud.db raspberrycloud.db.backup

# 删除旧数据库
rm raspberrycloud.db

# 重新初始化
python -c "from models import init_db; init_db()"

# 重启服务
sudo systemctl restart raspberrycloud
```

---

## 🧪 步骤3：快速诊断脚本

运行以下命令进行快速诊断：

```bash
# 创建诊断脚本
cat > /tmp/diagnose.sh << 'EOF'
#!/bin/bash
echo "=== 服务状态 ==="
sudo systemctl status raspberrycloud --no-pager -l | head -20

echo ""
echo "=== 最近错误日志 ==="
sudo tail -20 /var/log/raspberrycloud/backend_error.log 2>/dev/null || echo "错误日志文件不存在"

echo ""
echo "=== 数据库文件 ==="
ls -la /opt/raspberrycloud/backend/raspberrycloud.db 2>/dev/null || echo "数据库文件不存在"

echo ""
echo "=== 环境变量文件 ==="
ls -la /opt/raspberrycloud/backend/.env 2>/dev/null || echo ".env文件不存在"

echo ""
echo "=== 存储目录 ==="
ls -la /mnt/cloud_storage/ 2>/dev/null || echo "存储目录不存在"

echo ""
echo "=== 端口占用 ==="
sudo lsof -i :8000 2>/dev/null || echo "端口8000未被占用"
EOF

chmod +x /tmp/diagnose.sh
/tmp/diagnose.sh
```

---

## 📝 步骤4：手动测试后端

如果服务有问题，可以手动启动后端进行测试：

```bash
# 停止服务
sudo systemctl stop raspberrycloud

# 手动启动（可以看到实时错误信息）
cd /opt/raspberrycloud/backend
source ../venv/bin/activate

# 启动服务器（会显示详细错误）
uvicorn main:app --host 0.0.0.0 --port 8000

# 在另一个终端测试
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"RaspberryCloud2024!"}'
```

---

## 🔄 步骤5：完全重置（最后手段）

如果以上方法都不行，可以完全重置：

```bash
# 1. 停止服务
sudo systemctl stop raspberrycloud
sudo systemctl disable raspberrycloud

# 2. 备份数据库（如果想保留数据）
sudo cp /opt/raspberrycloud/backend/raspberrycloud.db /tmp/raspberrycloud.db.backup

# 3. 删除数据库
sudo rm /opt/raspberrycloud/backend/raspberrycloud.db

# 4. 重新初始化数据库
cd /opt/raspberrycloud/backend
source ../venv/bin/activate
python -c "from models import init_db; init_db()"

# 5. 检查.env配置
nano .env
# 确保所有配置都正确

# 6. 重启服务
sudo systemctl start raspberrycloud
sudo systemctl enable raspberrycloud
sudo systemctl status raspberrycloud
```

---

## ✅ 验证修复

修复后，测试登录：

```bash
# 测试健康检查
curl http://localhost/api/health

# 测试登录
curl -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"RaspberryCloud2024!"}'

# 应该返回包含 "access_token" 的JSON
```

---

## 📞 获取帮助

如果以上方法都无法解决问题，请提供以下信息：

1. 错误日志的完整内容（`sudo tail -50 /var/log/raspberrycloud/backend_error.log`）
2. 服务状态（`sudo systemctl status raspberrycloud`）
3. 数据库文件是否存在（`ls -la /opt/raspberrycloud/backend/raspberrycloud.db`）
4. .env文件内容（隐藏敏感信息后）




