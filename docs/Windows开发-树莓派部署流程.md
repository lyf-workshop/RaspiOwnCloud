# Windows开发 - 树莓派部署完整流程

## 📋 工作流程概览

```
Windows开发环境
    ↓ (开发、测试)
    ↓ (Git提交)
GitHub仓库
    ↓ (Git拉取)
树莓派生产环境
    ↓ (自动部署)
运行中的服务
```

---

## 🖥️ 第一部分：Windows开发环境设置

### 1. 安装必要工具

#### Git（如果还没有安装）

1. 下载：https://git-scm.com/download/win
2. 安装时选择：
   - ✅ 添加到PATH
   - ✅ Git Bash
   - ✅ Visual Studio Code作为默认编辑器（可选）

#### 验证安装

```powershell
# 打开 PowerShell 或 Git Bash
git --version
```

### 2. 克隆项目（首次）

```powershell
# 在Windows上选择一个工作目录，例如：
cd F:\Github

# 克隆项目
git clone https://github.com/你的用户名/RaspiOwnCloud.git

# 进入项目目录
cd RaspiOwnCloud
```

### 3. 配置Git用户信息（如果还没有）

```powershell
git config --global user.name "你的名字"
git config --global user.email "your.email@example.com"
```

---

## 💻 第二部分：日常开发流程

### 1. 开发前：拉取最新代码

```powershell
# 进入项目目录
cd F:\Github\RaspiOwnCloud

# 拉取最新代码（确保与远程同步）
git pull origin main
```

### 2. 开发：修改代码

在Windows上使用你喜欢的编辑器（VS Code、PyCharm等）进行开发：

- 修改 `backend/` 目录下的Python代码
- 修改 `frontend/` 目录下的HTML/CSS/JS文件
- 修改 `config/` 目录下的配置文件
- 修改 `docs/` 目录下的文档

### 3. 本地测试（可选）

```powershell
# 进入后端目录
cd backend

# 创建虚拟环境（如果还没有）
python -m venv venv

# 激活虚拟环境
.\venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt

# 运行开发服务器
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

访问：http://localhost:8000

### 4. 提交代码到Git

```powershell
# 回到项目根目录
cd F:\Github\RaspiOwnCloud

# 查看修改的文件
git status

# 添加所有修改的文件
git add .

# 或者只添加特定文件
git add backend/email_verification.py
git add frontend/login.html

# 提交（带描述信息）
git commit -m "添加邮箱验证码功能"

# 推送到GitHub
git push origin main
```

**提交信息建议格式：**

```
功能: 添加邮箱验证码功能
修复: 修复验证码发送失败的问题
文档: 更新部署流程文档
优化: 改进错误处理逻辑
```

---

## 🚀 第三部分：树莓派部署更新

### 方法一：使用自动化脚本（推荐）⭐

#### 1. 首次设置（只需一次）

在树莓派上，将项目克隆到开发目录：

```bash
# SSH连接到树莓派
ssh pi@树莓派IP

# 创建开发目录
mkdir -p ~/Desktop/Github
cd ~/Desktop/Github

# 克隆项目（如果还没有）
git clone https://github.com/你的用户名/RaspiOwnCloud.git

# 或者如果已经存在，进入目录
cd RaspiOwnCloud

# 确保Git配置正确
git config user.name "你的名字"
git config user.email "your.email@example.com"
```

#### 2. 使用更新脚本

```bash
# 进入项目目录
cd ~/Desktop/Github/RaspiOwnCloud

# 使用更新脚本（会自动拉取代码并部署）
sudo bash scripts/update_from_github.sh
```

脚本会自动完成：
- ✅ 拉取最新代码
- ✅ 备份当前版本
- ✅ 更新后端文件
- ✅ 更新前端文件
- ✅ 更新Python依赖
- ✅ 重启服务

### 方法二：手动更新步骤

#### 步骤1：拉取最新代码

```bash
# SSH连接到树莓派
ssh pi@树莓派IP

# 进入项目目录
cd ~/Desktop/Github/RaspiOwnCloud

# 拉取最新代码
git pull origin main
```

#### 步骤2：更新后端文件

```bash
# 复制后端文件到部署目录
sudo cp -r ~/Desktop/Github/RaspiOwnCloud/backend/* /opt/raspberrycloud/

# 设置正确的权限
sudo chown -R www-data:www-data /opt/raspberrycloud
```

#### 步骤3：更新前端文件

```bash
# 复制前端文件
sudo cp -r ~/Desktop/Github/RaspiOwnCloud/frontend/* /var/www/raspberrycloud/

# 设置正确的权限
sudo chown -R www-data:www-data /var/www/raspberrycloud
```

#### 步骤4：更新Python依赖（如果有新依赖）

```bash
# 进入部署目录
cd /opt/raspberrycloud

# 激活虚拟环境
source venv/bin/activate

# 更新依赖
pip install --upgrade pip
pip install -r requirements.txt --upgrade
```

#### 步骤5：重启服务

```bash
# 重启后端服务
sudo systemctl restart raspberrycloud

# 重启Nginx（如果需要）
sudo systemctl restart nginx

# 检查服务状态
sudo systemctl status raspberrycloud
```

---

## 🔄 完整工作流程示例

### 场景：添加新功能（邮箱验证码）

#### Windows端操作：

```powershell
# 1. 拉取最新代码
cd F:\Github\RaspiOwnCloud
git pull origin main

# 2. 创建新分支（可选，推荐）
git checkout -b feature/email-verification

# 3. 开发：修改代码
# - 编辑 backend/email_verification.py
# - 编辑 frontend/login.html
# - 测试功能

# 4. 提交代码
git add .
git commit -m "功能: 添加邮箱验证码功能"
git push origin feature/email-verification

# 5. 合并到主分支（在GitHub上创建Pull Request，或直接合并）
git checkout main
git merge feature/email-verification
git push origin main
```

#### 树莓派端操作：

**如果树莓派可以访问GitHub：**

```bash
# 1. SSH连接到树莓派
ssh pi@树莓派IP

# 2. 使用更新脚本
cd ~/Desktop/Github/RaspiOwnCloud
sudo bash scripts/update_from_github.sh

# 3. 验证更新
# - 访问 http://树莓派IP/login.html
# - 测试新功能
# - 查看日志：sudo journalctl -u raspberrycloud -f
```

**如果树莓派无法访问GitHub（网络问题）：**

使用Windows传输文件到树莓派（见下方"网络问题解决方案"）

---

## 📝 配置文件管理

### 重要：`.env` 文件不会被覆盖

`.env` 文件包含敏感配置（数据库密码、SMTP密码等），**不会被Git跟踪**，也不会被更新脚本覆盖。

### 如果添加了新的配置项：

1. **更新 `config/env.example`**（在Windows上）
   ```powershell
   # 编辑 config/env.example，添加新配置项
   ```

2. **提交到Git**
   ```powershell
   git add config/env.example
   git commit -m "配置: 添加SMTP配置示例"
   git push origin main
   ```

3. **在树莓派上手动添加配置**
   ```bash
   # 编辑 .env 文件
   sudo nano /opt/raspberrycloud/.env
   
   # 添加新配置项（参考 env.example）
   SMTP_HOST=smtp.qq.com
   SMTP_PORT=587
   # ...
   ```

---

## 🛠️ 高级技巧

### 1. 使用SSH密钥（免密码推送）

#### Windows端设置：

```powershell
# 生成SSH密钥（如果还没有）
ssh-keygen -t ed25519 -C "your.email@example.com"

# 复制公钥
cat ~/.ssh/id_ed25519.pub
```

#### GitHub端设置：

1. 登录GitHub
2. Settings → SSH and GPG keys
3. New SSH key
4. 粘贴公钥内容

#### 使用SSH URL：

```powershell
# 查看当前远程URL
git remote -v

# 如果使用HTTPS，改为SSH
git remote set-url origin git@github.com:用户名/RaspiOwnCloud.git
```

### 2. 使用Git分支管理

```powershell
# 创建开发分支
git checkout -b develop

# 开发完成后合并到主分支
git checkout main
git merge develop
git push origin main
```

### 3. 回滚到之前的版本

如果更新后出现问题，可以回滚：

```bash
# 在树莓派上
cd ~/Desktop/Github/RaspiOwnCloud

# 查看提交历史
git log --oneline

# 回滚到指定版本
git checkout <commit-hash>

# 重新部署
sudo bash scripts/update_from_github.sh
```

### 4. 查看更新日志

```bash
# 在树莓派上查看最近的更新
cd ~/Desktop/Github/RaspiOwnCloud
git log --oneline -10
```

---

## ⚠️ 注意事项

### 1. 不要提交敏感信息

**永远不要提交：**
- `.env` 文件
- 数据库文件（如果包含真实数据）
- 私钥、密码等

**使用 `.gitignore`：**

```gitignore
# 环境变量
.env
.env.local

# 数据库
*.db
*.sqlite

# Python
__pycache__/
*.pyc
venv/
```

### 2. 更新前备份

更新脚本会自动备份，但建议手动备份重要数据：

```bash
# 备份数据库
sudo cp /opt/raspberrycloud/raspberrycloud.db /tmp/backup_$(date +%Y%m%d).db

# 备份配置文件
sudo cp /opt/raspberrycloud/.env /tmp/backup.env
```

### 3. 测试后再部署

- ✅ 在Windows上本地测试
- ✅ 在树莓派上测试环境测试（如果有）
- ✅ 最后部署到生产环境

### 4. 数据库迁移

如果修改了数据库结构（`models.py`），可能需要：

```bash
# 在树莓派上
cd /opt/raspberrycloud
source venv/bin/activate

# 重新初始化数据库（⚠️ 会清空数据）
python -c "from models import init_db; init_db()"

# 或者使用迁移工具（如果配置了Alembic）
alembic upgrade head
```

---

## 🔍 故障排查

### 问题1：Git pull失败 - "dubious ownership"

**错误信息：**
```
fatal: detected dubious ownership in repository at '/opt/raspberrycloud'
```

**原因：** Git检测到仓库目录的所有者与当前用户不匹配（安全机制）

**解决方法：**

**方法1：添加安全目录（推荐）**

```bash
# 为当前用户添加安全目录
git config --global --add safe.directory /opt/raspberrycloud

# 如果使用sudo，需要为root用户也添加
sudo git config --global --add safe.directory /opt/raspberrycloud
```

**方法2：修改目录所有者**

```bash
# 将目录所有者改为pi用户
sudo chown -R pi:pi /opt/raspberrycloud

# 或者改为www-data（如果服务以www-data运行）
sudo chown -R www-data:www-data /opt/raspberrycloud
```

**方法3：在项目目录中操作（推荐）**

如果代码在 `~/Desktop/Github/RaspiOwnCloud`，直接在那里操作：

```bash
# 在开发目录中操作（不需要sudo）
cd ~/Desktop/Github/RaspiOwnCloud
git pull origin main

# 然后复制到部署目录
sudo cp -r backend/* /opt/raspberrycloud/
```

### 问题2：Git pull失败 - 网络问题

**错误信息：**
```
error: RPC failed; curl 28 Failed to connect to github.com port 443
fatal: expected flush after ref listing
```

**解决方法：从Windows传输文件（推荐）⭐**

如果树莓派无法访问GitHub，在Windows上拉取代码后传输：

```powershell
# Windows端：拉取最新代码
cd F:\Github\RaspiOwnCloud
git pull origin main

# 使用scp传输文件
scp -r backend/* pi@树莓派IP:/opt/raspberrycloud/backend/
scp -r frontend/* pi@树莓派IP:/var/www/raspberrycloud/

# 或使用rsync（更高效）
rsync -avz --exclude='__pycache__' --exclude='*.pyc' backend/ pi@树莓派IP:/opt/raspberrycloud/backend/
rsync -avz frontend/ pi@树莓派IP:/var/www/raspberrycloud/
```

**然后在树莓派上运行部署脚本：**

```bash
# 运行传输后的部署脚本
sudo bash /opt/raspberrycloud/scripts/transfer_from_windows.sh
```

**其他解决方法：**

```bash
# 检查网络连接
ping -c 4 8.8.8.8
ping -c 4 github.com

# 检查DNS解析
nslookup github.com

# 配置Git代理（如果通过代理上网）
git config --global http.proxy http://代理IP:端口
git config --global https.proxy http://代理IP:端口

# 使用GitHub镜像
git remote set-url origin https://ghproxy.com/https://github.com/lyf-workshop/RaspiOwnCloud.git
```

### 问题2：更新后服务无法启动

```bash
# 查看错误日志
sudo journalctl -u raspberrycloud -n 50

# 检查Python依赖
cd /opt/raspberrycloud
source venv/bin/activate
pip install -r requirements.txt

# 检查文件权限
sudo chown -R www-data:www-data /opt/raspberrycloud
```

### 问题3：前端文件没有更新

```bash
# 清除浏览器缓存（Ctrl+F5）
# 或检查文件权限
sudo chown -R www-data:www-data /var/www/raspberrycloud

# 检查Nginx配置
sudo nginx -t
sudo systemctl reload nginx
```

### 问题4：代码冲突

```bash
# 查看冲突
git status

# 解决冲突后
git add .
git commit -m "解决冲突"
git push origin main
```

---

## 📊 快速参考命令

### Windows端（开发）

```powershell
# 拉取最新代码
git pull origin main

# 查看修改
git status

# 提交代码
git add .
git commit -m "描述"
git push origin main

# 查看提交历史
git log --oneline
```

### 树莓派端（部署）

```bash
# 快速更新（推荐）
cd ~/Desktop/Github/RaspiOwnCloud
sudo bash scripts/update_from_github.sh

# 手动更新
git pull origin main
sudo cp -r backend/* /opt/raspberrycloud/
sudo cp -r frontend/* /var/www/raspberrycloud/
sudo systemctl restart raspberrycloud

# 查看服务状态
sudo systemctl status raspberrycloud

# 查看日志
sudo journalctl -u raspberrycloud -f
```

---

## ✅ 最佳实践

1. **频繁提交**：小步快跑，频繁提交代码
2. **清晰的提交信息**：描述清楚每次提交做了什么
3. **测试后再推送**：确保代码能正常运行
4. **使用分支**：新功能使用独立分支开发
5. **定期更新**：保持代码与远程同步
6. **备份重要数据**：更新前备份数据库和配置

---

**现在你可以愉快地在Windows上开发，然后在树莓派上轻松部署了！** 🎉

