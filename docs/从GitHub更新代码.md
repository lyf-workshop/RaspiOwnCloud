# 从 GitHub 更新代码指南

## 📋 前置条件

- 树莓派已安装 git
- 项目已推送到 GitHub 仓库
- 已配置 Git 用户信息（可选）

## 🚀 方法一：使用更新脚本（推荐）

### 如果代码在 `/opt/raspberrycloud`

```bash
# 使用内置的更新脚本
cd /opt/raspberrycloud
sudo bash scripts/update.sh
```

### 如果代码在其他位置（如 `~/Desktop/Github/RaspiOwnCloud`）

```bash
# 1. 进入项目目录
cd ~/Desktop/Github/RaspiOwnCloud

# 2. 拉取最新代码
git pull origin main

# 3. 复制更新后的文件到部署目录
sudo cp -r backend/* /opt/raspberrycloud/
sudo cp -r frontend/* /var/www/raspberrycloud/

# 4. 更新 Python 依赖（如果需要）
cd /opt/raspberrycloud
source venv/bin/activate
pip install -r requirements.txt --upgrade

# 5. 重启服务
sudo systemctl restart raspberrycloud
sudo systemctl restart nginx
```

## 📝 方法二：手动更新步骤

### 步骤1：检查当前 Git 状态

```bash
# 进入项目目录
cd ~/Desktop/Github/RaspiOwnCloud

# 查看当前状态
git status

# 查看远程仓库
git remote -v
```

### 步骤2：保存本地修改（如果有）

**如果出现错误：`Your local changes to the following files would be overwritten by merge`**

**方案1：保存本地修改后拉取（推荐，保留本地更改）⭐**

```bash
# 1. 保存本地修改到临时区域
git stash

# 2. 拉取最新代码
git pull origin main

# 3. 恢复本地修改（如果有冲突需要手动解决）
git stash pop

# 4. 如果stash pop有冲突，解决冲突后：
git add .
git commit -m "合并本地修改和远程更新"
```

**方案2：丢弃本地修改，使用远程版本（如果本地更改不重要）**

```bash
# ⚠️ 警告：这会永久删除本地未提交的修改！

# 1. 查看哪些文件会被覆盖
git status

# 2. 丢弃所有本地修改
git reset --hard HEAD

# 3. 拉取最新代码
git pull origin main
```

**方案3：提交本地修改后拉取**

```bash
# 1. 提交本地修改
git add .
git commit -m "本地修改说明"

# 2. 拉取最新代码（可能有冲突需要解决）
git pull origin main

# 3. 如果有冲突，解决冲突后：
git add .
git commit -m "解决冲突"
```

**方案4：只保存特定文件的修改**

```bash
# 1. 只保存重要文件的修改
git stash push -m "保存重要修改" backend/email_verification.py

# 2. 拉取最新代码
git pull origin main

# 3. 恢复保存的文件
git stash pop
```

### 步骤3：拉取最新代码

```bash
# 拉取最新代码
git pull origin main

# 或者指定分支
git pull origin master
```

### 步骤4：处理冲突（如果有）

**如果 `git pull` 或 `git stash pop` 后出现冲突：**

```bash
# 1. 查看冲突文件
git status

# 2. 打开冲突文件，查找冲突标记：
#    <<<<<<< HEAD
#    本地代码
#    =======
#    远程代码
#    >>>>>>> origin/main

# 3. 手动编辑文件，删除冲突标记，保留需要的代码

# 4. 标记冲突已解决
git add <冲突文件>

# 5. 完成合并
git commit -m "解决冲突"
```

**快速解决冲突（使用远程版本）：**

```bash
# 如果冲突太多，想直接使用远程版本
git checkout --theirs <冲突文件>
git add <冲突文件>
git commit -m "使用远程版本解决冲突"
```

**快速解决冲突（使用本地版本）：**

```bash
# 如果想保留本地版本
git checkout --ours <冲突文件>
git add <冲突文件>
git commit -m "保留本地版本"
```

### 步骤5：更新部署文件

```bash
# 复制后端文件
sudo cp -r ~/Desktop/Github/RaspiOwnCloud/backend/* /opt/raspberrycloud/

# 复制前端文件
sudo cp -r ~/Desktop/Github/RaspiOwnCloud/frontend/* /var/www/raspberrycloud/

# 复制配置文件（如果需要）
sudo cp ~/Desktop/Github/RaspiOwnCloud/config/raspberrycloud.service /etc/systemd/system/
sudo cp ~/Desktop/Github/RaspiOwnCloud/config/nginx.conf /etc/nginx/sites-available/raspberrycloud
```

### 步骤6：更新依赖

```bash
cd /opt/raspberrycloud
source venv/bin/activate

# 更新 Python 依赖
pip install --upgrade pip
pip install -r requirements.txt --upgrade
```

### 步骤7：重启服务

```bash
# 重新加载 systemd（如果修改了服务文件）
sudo systemctl daemon-reload

# 重启服务
sudo systemctl restart raspberrycloud
sudo systemctl restart nginx

# 检查服务状态
sudo systemctl status raspberrycloud
```

## 🔄 方法三：完全重新克隆（如果 Git 仓库损坏）

```bash
# 1. 备份当前配置
sudo cp /opt/raspberrycloud/.env /tmp/raspberrycloud.env.backup

# 2. 备份数据库
sudo cp /opt/raspberrycloud/raspberrycloud.db /tmp/raspberrycloud.db.backup

# 3. 停止服务
sudo systemctl stop raspberrycloud

# 4. 删除旧目录
sudo rm -rf /opt/raspberrycloud

# 5. 重新克隆
cd /opt
sudo git clone <你的GitHub仓库地址> raspberrycloud

# 6. 恢复配置
sudo cp /tmp/raspberrycloud.env.backup /opt/raspberrycloud/.env
sudo cp /tmp/raspberrycloud.db.backup /opt/raspberrycloud/raspberrycloud.db

# 7. 设置权限
sudo chown -R www-data:www-data /opt/raspberrycloud

# 8. 重新安装依赖
cd /opt/raspberrycloud
sudo python3 -m venv venv
sudo chown -R www-data:www-data venv
source venv/bin/activate
pip install -r requirements.txt

# 9. 重启服务
sudo systemctl start raspberrycloud
```

## 🛠️ 快速更新脚本

创建一个快速更新脚本：

```bash
#!/bin/bash
# 快速更新脚本

PROJECT_DIR="$HOME/Desktop/Github/RaspiOwnCloud"
DEPLOY_DIR="/opt/raspberrycloud"
FRONTEND_DIR="/var/www/raspberrycloud"

echo "开始更新..."

# 1. 拉取代码
cd "$PROJECT_DIR"
git pull origin main

# 2. 复制文件
sudo cp -r "$PROJECT_DIR/backend"/* "$DEPLOY_DIR/"
sudo cp -r "$PROJECT_DIR/frontend"/* "$FRONTEND_DIR/"

# 3. 更新依赖
cd "$DEPLOY_DIR"
source venv/bin/activate
pip install -r requirements.txt --upgrade

# 4. 重启服务
sudo systemctl restart raspberrycloud
sudo systemctl restart nginx

echo "更新完成！"
```

保存为 `~/update_from_github.sh`，然后：

```bash
chmod +x ~/update_from_github.sh
~/update_from_github.sh
```

## ⚠️ 注意事项

1. **备份重要数据**：更新前备份 `.env` 文件和数据库
2. **检查依赖变化**：如果 `requirements.txt` 有更新，需要重新安装依赖
3. **数据库迁移**：如果有数据库结构变化，可能需要运行迁移脚本
4. **配置文件**：`.env` 文件不会被覆盖，但其他配置文件可能需要手动更新
5. **服务重启**：更新代码后必须重启服务才能生效

## 🔍 验证更新

```bash
# 检查服务状态
sudo systemctl status raspberrycloud

# 查看服务日志
sudo journalctl -u raspberrycloud -n 50

# 测试 API
curl http://localhost:8000/api/health

# 访问 Web 界面
# 浏览器打开: http://树莓派IP
```

## 🐛 常见问题

### Q1: Git pull 失败 - "dubious ownership"

**错误信息：**
```
fatal: detected dubious ownership in repository at '/opt/raspberrycloud'
```

**解决方法：**

```bash
# 方法1：添加安全目录（推荐）
git config --global --add safe.directory /opt/raspberrycloud

# 如果使用sudo，也需要为root添加
sudo git config --global --add safe.directory /opt/raspberrycloud
```

**或者修改目录所有者：**

```bash
# 将目录所有者改为当前用户
sudo chown -R $USER:$USER /opt/raspberrycloud
```

### Q2: Git pull 失败，提示需要配置用户信息

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Q2: Git pull 失败 - "Permission denied (publickey)"

**错误信息：**
```
git@github.com: Permission denied (publickey).
fatal: Could not read from remote repository.
```

**原因：** 远程仓库配置为SSH方式（`git@github.com:...`），但没有配置SSH密钥。

**解决方法1：改用HTTPS方式（推荐，最简单）⭐**

```bash
# 1. 查看当前远程URL
cd /opt/raspberrycloud
git remote -v

# 2. 将SSH URL改为HTTPS URL
# 格式：git@github.com:用户名/仓库名.git → https://github.com/用户名/仓库名.git
git remote set-url origin https://github.com/lyf-workshop/RaspiOwnCloud.git

# 3. 验证
git remote -v

# 4. 重试拉取（公开仓库不需要认证）
git pull origin main
```

**解决方法2：配置SSH密钥（如果必须使用SSH）**

```bash
# 1. 生成SSH密钥（如果还没有）
ssh-keygen -t ed25519 -C "your.email@example.com"
# 按回车使用默认路径，可以设置密码或留空

# 2. 查看公钥
cat ~/.ssh/id_ed25519.pub

# 3. 复制公钥内容，添加到GitHub：
#    GitHub → Settings → SSH and GPG keys → New SSH key
#    粘贴公钥内容，保存

# 4. 测试SSH连接
ssh -T git@github.com

# 5. 重试git pull
cd /opt/raspberrycloud
git pull origin main
```

**解决方法3：使用Personal Access Token（私有仓库）**

```bash
# 1. 在GitHub生成Token：
#    GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
#    生成新token，勾选repo权限

# 2. 使用Token配置远程URL
git remote set-url origin https://你的用户名:你的token@github.com/用户名/仓库名.git

# 3. 重试拉取
git pull origin main
```

### Q3: 更新后服务无法启动

```bash
# 查看错误日志
sudo journalctl -u raspberrycloud -n 50

# 检查 Python 依赖
cd /opt/raspberrycloud
source venv/bin/activate
pip install -r requirements.txt
```

### Q4: 前端文件没有更新

```bash
# 清除浏览器缓存（Ctrl+F5）
# 或检查文件权限
sudo chown -R www-data:www-data /var/www/raspberrycloud
```

### Q5: Git pull 失败 - "Failed to connect to github.com"

**错误信息：**
```
error: RPC failed; curl 28 Failed to connect to github.com port 443 after 133701 ms: Couldn't connect to server
fatal: expected flush after ref listing
```

**原因：** 树莓派无法连接到GitHub（网络问题、防火墙、DNS解析失败、代理问题）

**诊断步骤：**

```bash
# 1. 测试网络连接
ping -c 4 8.8.8.8

# 2. 测试DNS解析
nslookup github.com

# 3. 测试HTTPS连接
curl -I https://github.com

# 4. 检查代理设置
echo $http_proxy
echo $https_proxy
git config --global --get http.proxy
git config --global --get https.proxy
```

**解决方法1：从Windows传输文件（推荐，最简单）⭐**

如果树莓派无法访问GitHub，但Windows可以：

**Windows端操作：**

```powershell
# 1. 在Windows上拉取最新代码
cd F:\Github\RaspiOwnCloud
git pull origin main

# 2. 使用scp传输文件到树莓派
# 传输后端文件
scp -r backend/* pi@树莓派IP:/opt/raspberrycloud/backend/

# 传输前端文件
scp -r frontend/* pi@树莓派IP:/var/www/raspberrycloud/

# 传输配置文件（如果需要）
scp config/raspberrycloud.service pi@树莓派IP:/tmp/
# 然后在树莓派上：sudo mv /tmp/raspberrycloud.service /etc/systemd/system/
```

**或者使用rsync（更高效）：**

```powershell
# Windows需要安装rsync（Git for Windows自带）
# 传输后端文件
rsync -avz --exclude='__pycache__' --exclude='*.pyc' backend/ pi@树莓派IP:/opt/raspberrycloud/backend/

# 传输前端文件
rsync -avz frontend/ pi@树莓派IP:/var/www/raspberrycloud/
```

**树莓派端操作：**

```bash
# 1. 更新Python依赖（如果有新依赖）
cd /opt/raspberrycloud
source venv/bin/activate
pip install -r requirements.txt --upgrade

# 2. 重启服务
sudo systemctl restart raspberrycloud
sudo systemctl restart nginx
```

**解决方法2：配置HTTP代理（如果树莓派通过代理上网）**

```bash
# 1. 设置Git代理（替换为你的代理地址和端口）
git config --global http.proxy http://代理IP:端口
git config --global https.proxy http://代理IP:端口

# 例如：如果通过电脑的代理
git config --global http.proxy http://192.168.1.2:7890
git config --global https.proxy http://192.168.1.2:7890

# 2. 重试拉取
cd /opt/raspberrycloud
git pull origin main

# 3. 如果不再需要代理，取消设置
git config --global --unset http.proxy
git config --global --unset https.proxy
```

**解决方法3：使用GitHub镜像（如果在中国大陆）**

```bash
# 使用GitHub镜像站点（如：ghproxy.com）
cd /opt/raspberrycloud
git remote set-url origin https://ghproxy.com/https://github.com/lyf-workshop/RaspiOwnCloud.git

# 或使用其他镜像
git remote set-url origin https://mirror.ghproxy.com/https://github.com/lyf-workshop/RaspiOwnCloud.git

# 重试拉取
git pull origin main
```

**解决方法4：增加Git超时时间**

```bash
# 增加超时时间（默认可能太短）
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

# 重试拉取
cd /opt/raspberrycloud
git pull origin main
```

**解决方法5：检查防火墙和DNS**

```bash
# 1. 检查防火墙是否阻止443端口
sudo ufw status
# 如果443端口被阻止，允许HTTPS：
sudo ufw allow 443/tcp

# 2. 更换DNS服务器
sudo nano /etc/resolv.conf
# 添加：
nameserver 8.8.8.8
nameserver 8.8.4.4

# 或使用国内DNS：
nameserver 114.114.114.114
nameserver 223.5.5.5

# 3. 刷新DNS缓存
sudo systemd-resolve --flush-caches
```






