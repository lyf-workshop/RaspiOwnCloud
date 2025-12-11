# Crontab 错误排查指南

## 错误：`bad command` 在第27行

### 问题原因

crontab 文件格式非常严格，常见错误包括：
1. **格式错误**：crontab 每行必须是以下格式之一：
   - 注释行：以 `#` 开头
   - 定时任务：`分钟 小时 日 月 星期 命令`
   - 空行（会被忽略）

2. **路径错误**：路径中包含空格或特殊字符未转义

3. **命令格式错误**：命令中包含未转义的字符

### 解决步骤

#### 步骤1：查看当前 crontab 内容

```bash
# 查看当前的 crontab 内容
crontab -l
```

#### 步骤2：检查第27行

找到第27行，检查是否有以下问题：
- 格式不正确（不是注释也不是有效的 crontab 行）
- 路径错误
- 特殊字符未转义

#### 步骤3：修复方法

**方法A：重新编辑（推荐）**

```bash
# 输入 n（不重试），退出当前编辑
n

# 重新编辑
crontab -e

# 找到第27行，删除或修正错误的内容
```

**方法B：直接编辑临时文件**

如果知道问题所在，可以直接编辑：

```bash
# 查看当前内容
crontab -l > /tmp/my_crontab.txt

# 编辑文件
nano /tmp/my_crontab.txt

# 修正第27行的错误

# 重新安装
crontab /tmp/my_crontab.txt
```

### 正确的 crontab 格式示例

```bash
# 这是注释行（可以任意添加）

# 每5分钟执行一次
*/5 * * * * /opt/raspberrycloud/scripts/update_aliyun_dns.sh >/dev/null 2>&1

# 每10分钟执行一次
*/10 * * * * /opt/raspberrycloud/scripts/update_aliyun_dns.sh >/dev/null 2>&1
```

### 常见错误示例

❌ **错误1：缺少命令部分**
```bash
*/5 * * * *
```

✅ **正确：**
```bash
*/5 * * * * /opt/raspberrycloud/scripts/update_aliyun_dns.sh
```

❌ **错误2：路径包含空格未加引号**
```bash
*/5 * * * * /home/pi/my scripts/update.sh
```

✅ **正确：**
```bash
*/5 * * * * "/home/pi/my scripts/update.sh"
# 或使用绝对路径，避免空格
*/5 * * * * /opt/raspberrycloud/scripts/update_aliyun_dns.sh
```

❌ **错误3：注释格式错误**
```bash
# 这是注释 */5 * * * * command
```

✅ **正确：**
```bash
# 这是注释
*/5 * * * * command
```

### 快速修复命令

如果第27行是多余的或错误的，可以这样快速修复：

```bash
# 1. 导出当前 crontab
crontab -l > /tmp/crontab_backup.txt

# 2. 编辑备份文件，删除或修正第27行
nano /tmp/crontab_backup.txt

# 3. 重新安装
crontab /tmp/crontab_backup.txt

# 4. 验证
crontab -l
```

### 验证 crontab 语法

```bash
# 查看 crontab 内容
crontab -l

# 如果显示正常，说明语法正确
# 如果有错误，会直接显示错误信息
```

