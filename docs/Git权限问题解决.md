# Git权限问题解决指南

## 🔍 问题：dubious ownership

### 错误信息

```bash
fatal: detected dubious ownership in repository at '/opt/raspberrycloud'

To add an exception for this directory, call:
	git config --global --add safe.directory /opt/raspberrycloud
```

### 原因

Git 2.35.2+ 版本引入了安全机制，当检测到仓库目录的所有者与当前用户不匹配时，会拒绝操作。这是为了防止恶意代码执行。

**常见场景：**
- 目录由 `root` 或 `www-data` 创建
- 当前用户是 `pi`
- Git 检测到所有者不匹配，拒绝操作

---

## ✅ 解决方案

### 方案1：添加安全目录（推荐）⭐

**适用于：** 目录所有者是其他用户，但你想保持现状

```bash
# 为当前用户（pi）添加安全目录
git config --global --add safe.directory /opt/raspberrycloud

# 如果使用sudo运行git命令，也需要为root用户添加
sudo git config --global --add safe.directory /opt/raspberrycloud
```

**验证：**

```bash
# 查看配置
git config --global --get-all safe.directory

# 应该显示：/opt/raspberrycloud
```

**优点：**
- ✅ 快速解决
- ✅ 不需要修改文件权限
- ✅ 不影响服务运行

**缺点：**
- ⚠️ 需要为每个用户单独配置
- ⚠️ 如果使用sudo，需要配置两次

---

### 方案2：修改目录所有者

**适用于：** 希望目录所有者与当前用户一致

```bash
# 将目录所有者改为pi用户（包括.git目录）
sudo chown -R pi:pi /opt/raspberrycloud

# 或者改为www-data（如果服务以www-data运行）
sudo chown -R www-data:www-data /opt/raspberrycloud
```

**如果只修改.git目录：**

```bash
# 只修改.git目录的所有者
sudo chown -R $USER:$USER /opt/raspberrycloud/.git

# 验证
ls -la /opt/raspberrycloud/.git
```

**验证：**

```bash
# 查看目录所有者
ls -ld /opt/raspberrycloud

# 应该显示：drwxr-xr-x ... pi pi ... /opt/raspberrycloud
```

**优点：**
- ✅ 一劳永逸
- ✅ 不需要配置Git

**缺点：**
- ⚠️ 可能影响服务运行（如果服务需要特定用户权限）
- ⚠️ 需要确保服务用户有权限

---

### 方案3：在开发目录操作（最佳实践）⭐

**适用于：** 有独立的开发目录

**工作流程：**

```bash
# 1. 在开发目录中操作（不需要sudo）
cd ~/Desktop/Github/RaspiOwnCloud
git pull origin main

# 2. 然后复制到部署目录
sudo cp -r backend/* /opt/raspberrycloud/
sudo cp -r frontend/* /var/www/raspberrycloud/

# 3. 重启服务
sudo systemctl restart raspberrycloud
```

**优点：**
- ✅ 完全避免权限问题
- ✅ 符合开发-部署分离的最佳实践
- ✅ 可以保留开发历史

**缺点：**
- ⚠️ 需要手动复制文件（但可以用脚本自动化）

---

## 🛠️ 推荐配置

### 推荐方案：开发目录 + 自动部署脚本

**目录结构：**

```
~/Desktop/Github/RaspiOwnCloud/  # 开发目录（pi用户所有）
    ├── backend/
    ├── frontend/
    └── scripts/

/opt/raspberrycloud/              # 部署目录（www-data用户所有）
    ├── backend/
    └── .env

/var/www/raspberrycloud/          # 前端部署目录（www-data用户所有）
    └── frontend/
```

**更新流程：**

```bash
# 1. 在开发目录更新代码
cd ~/Desktop/Github/RaspiOwnCloud
git pull origin main

# 2. 使用自动部署脚本
bash scripts/quick_update.sh
# 或
sudo bash scripts/update_from_github.sh
```

**这样配置的好处：**
- ✅ 开发目录权限清晰（pi用户）
- ✅ 部署目录权限正确（www-data用户）
- ✅ 不需要配置Git安全目录
- ✅ 符合生产环境最佳实践

---

## 🔍 检查当前状态

### 查看目录所有者

```bash
# 查看目录所有者
ls -ld /opt/raspberrycloud

# 查看.git目录所有者
ls -ld /opt/raspberrycloud/.git

# 查看当前用户
whoami

# 查看Git配置
git config --global --get-all safe.directory
```

### 常见权限错误

**错误1：`cannot open '.git/FETCH_HEAD': Permission denied`**

```bash
# 解决方法：修改.git目录所有者
sudo chown -R $USER:$USER /opt/raspberrycloud/.git

# 或者修改整个目录
sudo chown -R $USER:$USER /opt/raspberrycloud
```

**错误2：`dubious ownership`**

```bash
# 解决方法：添加安全目录
git config --global --add safe.directory /opt/raspberrycloud
```

**错误3：`Permission denied (publickey)`**

```bash
# 错误信息：
# git@github.com: Permission denied (publickey).
# fatal: Could not read from remote repository.

# 解决方法1：改用HTTPS（推荐）⭐
cd /opt/raspberrycloud
git remote set-url origin https://github.com/lyf-workshop/RaspiOwnCloud.git
git pull origin main

# 解决方法2：配置SSH密钥
ssh-keygen -t ed25519 -C "your.email@example.com"
cat ~/.ssh/id_ed25519.pub
# 复制公钥，添加到GitHub → Settings → SSH and GPG keys
ssh -T git@github.com  # 测试连接
git pull origin main
```

**错误4：`Your local changes would be overwritten by merge`**

```bash
# 错误信息：
# error: Your local changes to the following files would be overwritten by merge:
#   backend/email_verification.py
#   ...

# 解决方法1：保存本地修改（推荐）⭐
cd /opt/raspberrycloud
git stash                    # 保存本地修改
git pull origin main         # 拉取最新代码
git stash pop               # 恢复本地修改（可能有冲突）

# 解决方法2：丢弃本地修改（如果本地更改不重要）⚠️
cd /opt/raspberrycloud
git reset --hard HEAD       # 丢弃所有本地修改
git pull origin main        # 拉取最新代码

# 解决方法3：提交本地修改
cd /opt/raspberrycloud
git add .
git commit -m "本地修改说明"
git pull origin main        # 可能有冲突需要解决
```

### 查看Git仓库信息

```bash
# 查看远程仓库
cd /opt/raspberrycloud
git remote -v

# 查看Git状态
git status
```

---

## ⚠️ 注意事项

### 1. 服务用户权限

如果服务以 `www-data` 用户运行，确保：

```bash
# 部署目录的所有者应该是www-data
sudo chown -R www-data:www-data /opt/raspberrycloud

# 但开发目录可以是pi用户
sudo chown -R pi:pi ~/Desktop/Github/RaspiOwnCloud
```

### 2. 使用sudo时的配置

如果使用 `sudo git` 命令，需要为root用户也配置：

```bash
# 为root用户配置
sudo git config --global --add safe.directory /opt/raspberrycloud

# 为pi用户配置
git config --global --add safe.directory /opt/raspberrycloud
```

### 3. 多个目录

如果有多个Git仓库，需要分别添加：

```bash
git config --global --add safe.directory /opt/raspberrycloud
git config --global --add safe.directory /opt/another-repo
```

---

## 📝 快速修复命令

**一键修复（方案1）：**

```bash
# 为当前用户添加安全目录
git config --global --add safe.directory /opt/raspberrycloud

# 如果使用sudo，也为root添加
sudo git config --global --add safe.directory /opt/raspberrycloud

# 验证
git pull origin main
```

**一键修复（方案2）：**

```bash
# 修改目录所有者
sudo chown -R $USER:$USER /opt/raspberrycloud

# 验证
git pull origin main
```

---

## 🎯 最佳实践总结

1. **开发目录**：使用 `~/Desktop/Github/RaspiOwnCloud`（pi用户所有）
2. **部署目录**：使用 `/opt/raspberrycloud`（www-data用户所有）
3. **更新流程**：在开发目录操作 → 使用脚本部署
4. **避免**：直接在部署目录使用git（除非必要）

这样配置可以：
- ✅ 避免权限问题
- ✅ 保持代码和部署分离
- ✅ 便于版本管理
- ✅ 符合生产环境规范

---

**现在你可以正常使用Git了！** 🎉

