# 阿里云RAM子账号配置指南

## 📋 为什么使用RAM子账号？

使用RAM（Resource Access Management）子账号是阿里云推荐的安全最佳实践：

### ✅ 优势

1. **最小权限原则**
   - 只授予必要的权限（DNS管理）
   - 即使AccessKey泄露，也只能操作DNS，不能操作其他服务

2. **安全隔离**
   - 不影响主账号和其他服务
   - 可以随时禁用，不影响主账号使用

3. **易于管理**
   - 可以创建多个子账号，分别用于不同用途
   - 可以查看操作日志，追踪谁做了什么

### ⚠️ 主账号AccessKey的风险

- ❌ 拥有账户的完全权限
- ❌ 如果泄露，可能导致整个账户被控制
- ❌ 无法细粒度控制权限

---

## 🚀 完整配置步骤

### 步骤1：创建RAM用户

1. **登录RAM控制台**
   - 访问：https://ram.console.aliyun.com
   - 或：阿里云控制台 → 产品与服务 → 访问控制（RAM）

2. **创建用户**
   - 点击左侧菜单"用户" → "创建用户"
   - 或直接访问：https://ram.console.aliyun.com/users

3. **填写用户信息**
   - **登录名称**：`ddns-user`（或自定义，如：`dns-updater`）
   - **显示名称**：`DDNS更新用户`（或自定义）
   - **访问方式**：
     - ✅ 勾选"编程访问"（会生成AccessKey）
     - ❌ 不勾选"控制台访问"（不需要登录控制台）

4. **点击"确定"创建**

### 步骤2：保存AccessKey

创建用户后，会立即显示AccessKey信息：

1. **立即保存以下信息**（只显示一次！）
   - **AccessKey ID**：`LTAI5t...`（以LTAI开头）
   - **AccessKey Secret**：`xxxx...`（长字符串）

2. **保存方式建议**
   - 复制到密码管理器（如1Password、LastPass）
   - 或保存到本地加密文件
   - ⚠️ **不要**保存到代码仓库或明文文件

3. **如果忘记保存**
   - 需要删除用户重新创建
   - 或创建新的AccessKey（旧Key会失效）

### 步骤3：授予DNS管理权限

1. **在用户列表中，找到刚创建的用户**
   - 点击用户名进入详情页

2. **添加权限**
   - 点击"权限"标签页
   - 点击"添加权限"按钮

3. **选择权限策略**

**方案A：完全管理权限（推荐，简单）**
- 搜索并选择：`AliyunDNSFullAccess`
- 这是系统预设策略，包含所有DNS操作权限
- 点击"确定"

**方案B：自定义权限（更安全，复杂）**
- 点击"创建自定义策略"
- 策略名称：`DNS-Update-Only`
- 策略内容（JSON）：
```json
{
  "Version": "1",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "alidns:DescribeDomainRecords",
        "alidns:UpdateDomainRecord"
      ],
      "Resource": "*"
    }
  ]
}
```
- 保存策略后，在用户权限中选择该策略

4. **确认权限已添加**
   - 在用户权限列表中应该看到DNS相关权限

### 步骤4：测试AccessKey

可以使用以下方法测试AccessKey是否正常工作：

**方法1：使用阿里云CLI**

```bash
# 安装阿里云CLI（如果还没有）
# Windows: 下载 https://aliyuncli.alicdn.com/aliyun-cli-windows-latest-amd64.zip
# Linux: wget https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz

# 配置AccessKey
aliyun configure set \
  --profile ddns \
  --mode AK \
  --region cn-hangzhou \
  --access-key-id 你的AccessKeyID \
  --access-key-secret 你的AccessKeySecret

# 测试查询DNS记录
aliyun alidns DescribeDomainRecords --DomainName 你的域名.com
```

**方法2：使用Python脚本测试**

```python
# test_accesskey.py
import os
os.environ['ALIYUN_ACCESS_KEY_ID'] = '你的AccessKey ID'
os.environ['ALIYUN_ACCESS_KEY_SECRET'] = '你的AccessKey Secret'
os.environ['ALIYUN_DOMAIN'] = '你的域名.com'
os.environ['ALIYUN_SUBDOMAIN'] = '@'

# 运行更新脚本
exec(open('scripts/update_aliyun_dns.py').read())
```

**方法3：直接运行更新脚本**

```bash
# 配置环境变量
export ALIYUN_ACCESS_KEY_ID="你的AccessKey ID"
export ALIYUN_ACCESS_KEY_SECRET="你的AccessKey Secret"
export ALIYUN_DOMAIN="你的域名.com"
export ALIYUN_SUBDOMAIN="@"

# 运行脚本
bash scripts/update_aliyun_dns.sh
```

### 步骤5：配置到脚本

将AccessKey配置到更新脚本中：

```bash
# 编辑脚本
nano scripts/update_aliyun_dns.sh
```

修改以下行：
```bash
export ALIYUN_ACCESS_KEY_ID="你的RAM用户AccessKey ID"
export ALIYUN_ACCESS_KEY_SECRET="你的RAM用户AccessKey Secret"
export ALIYUN_DOMAIN="你的域名.com"
export ALIYUN_SUBDOMAIN="@"
```

---

## 🔒 安全最佳实践

### 1. 权限最小化

- ✅ 只授予必要的权限（DNS管理）
- ❌ 不要授予其他服务的权限
- ❌ 不要使用主账号AccessKey

### 2. 定期轮换

- 建议每3-6个月更换一次AccessKey
- 更换步骤：
  1. 创建新的AccessKey
  2. 更新脚本配置
  3. 测试新Key是否正常
  4. 删除旧AccessKey

### 3. 保护AccessKey

- ✅ 使用密码管理器保存
- ✅ 使用环境变量（不要硬编码）
- ✅ 设置文件权限（chmod 600）
- ❌ 不要提交到Git仓库
- ❌ 不要分享给他人
- ❌ 不要保存在日志中

### 4. 监控和审计

- 定期查看RAM用户的操作日志
- 访问：RAM控制台 → 审计 → 操作日志
- 检查是否有异常操作

### 5. 启用MFA（可选）

如果启用了控制台访问，建议启用多因素认证（MFA）：
- RAM控制台 → 用户 → 安全设置 → 启用MFA

---

## 🛠️ 故障排查

### 问题1：AccessKey无效

**错误信息：**
```
InvalidAccessKeyId.NotFound
```

**解决方法：**
1. 检查AccessKey ID是否正确
2. 检查AccessKey是否已删除
3. 确认使用的是RAM用户的AccessKey，不是主账号的

### 问题2：权限不足

**错误信息：**
```
Forbidden.RAM
```

**解决方法：**
1. 检查RAM用户是否已授予DNS管理权限
2. 确认权限策略已正确添加
3. 检查权限策略是否包含 `alidns:UpdateDomainRecord`

### 问题3：找不到DNS记录

**错误信息：**
```
DomainRecordNotBelongToUser
```

**解决方法：**
1. 确认域名属于当前阿里云账号
2. 检查域名是否正确
3. 确认DNS记录已存在（需要先手动创建一条）

---

## 📝 快速参考

### 创建RAM用户的完整命令流程

1. 访问：https://ram.console.aliyun.com/users
2. 点击"创建用户"
3. 填写信息 → 创建
4. 保存AccessKey
5. 添加权限：`AliyunDNSFullAccess`
6. 完成

### 权限策略说明

| 策略名称 | 权限范围 | 推荐度 |
|---------|---------|--------|
| `AliyunDNSFullAccess` | DNS完全管理 | ⭐⭐⭐ 推荐（简单） |
| 自定义策略（仅更新） | 仅允许更新记录 | ⭐⭐⭐⭐ 更安全（复杂） |

---

## ✅ 配置检查清单

- [ ] RAM用户已创建
- [ ] AccessKey已保存（ID和Secret）
- [ ] DNS管理权限已授予
- [ ] AccessKey测试成功
- [ ] 脚本配置已更新
- [ ] 定时任务已设置
- [ ] DNS记录自动更新正常

---

**现在你已经安全地配置了RAM子账号，可以放心使用自动DNS更新功能了！** 🎉



