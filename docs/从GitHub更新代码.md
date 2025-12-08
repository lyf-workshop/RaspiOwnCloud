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

```bash
# 如果有未提交的修改，先保存
git stash

# 或者提交本地修改
git add .
git commit -m "本地修改"
```

### 步骤3：拉取最新代码

```bash
# 拉取最新代码
git pull origin main

# 或者指定分支
git pull origin master
```

### 步骤4：处理冲突（如果有）

如果出现冲突：

```bash
# 查看冲突文件
git status

# 手动解决冲突后
git add <冲突文件>
git commit -m "解决冲突"
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

### Q1: Git pull 失败，提示需要配置用户信息

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Q2: 提示需要输入密码

```bash
# 使用 SSH 方式（推荐）
git remote set-url origin git@github.com:用户名/仓库名.git

# 或使用 Personal Access Token
git remote set-url origin https://用户名:token@github.com/用户名/仓库名.git
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

