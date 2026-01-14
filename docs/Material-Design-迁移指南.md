# Material Design 风格迁移指南

## 📋 概述

RaspberryCloud 已经完成从 Apple 风格到 **Material Design 3** 风格的全面改造！

参考项目：[Cloudreve](https://github.com/cloudreve/cloudreve) - 优秀的开源网盘项目

---

## 🎨 Material Design 特性

### ✨ 核心特性

1. **Material You 配色系统**
   - 动态色彩系统
   - 完整的明暗模式
   - 语义化颜色变量

2. **Material Components**
   - Top App Bar（顶部应用栏）
   - Navigation Drawer（导航抽屉）
   - FAB（浮动操作按钮）
   - Cards（卡片）
   - Buttons（按钮）
   - Text Fields（文本框）
   - Snackbar（提示条）

3. **Material Motion**
   - Emphasized easing（强调缓动）
   - 统一的动画时长
   - 波纹效果（Ripple）

4. **Elevation System**
   - 5级阴影系统
   - 动态高程变化

---

## 📁 文件结构

### 新增文件

```
frontend/
├── login.html                   # ✅ Material Design 登录页
├── index-material.html          # ✅ Material Design 主界面（新版）
├── index.html                   # ⚠️ 旧版（保留，可删除）
├── css/
│   ├── material-design.css     # ✅ MD 基础样式系统
│   ├── material-icons.css      # ✅ MD 图标系统
│   ├── material-main.css       # ✅ MD 主界面样式
│   ├── style.css               # ⚠️ 旧版样式
│   └── modern.css              # ⚠️ 旧版现代样式
└── js/
    ├── material-app.js         # ✅ MD 应用逻辑
    ├── main.js                 # 旧版逻辑（部分复用）
    ├── upload.js               # 上传逻辑（复用）
    └── preview.js              # 预览逻辑（复用）
```

---

## 🚀 部署步骤

### 方式A：直接替换（推荐）

在树莓派上执行：

```bash
cd ~/Desktop/Github/RaspiOwnCloud

# 备份旧版（可选）
cp frontend/index.html frontend/index-old.html

# 替换为 Material Design 版本
mv frontend/index-material.html frontend/index.html

# 更新前端到生产环境
sudo cp -r frontend/* /var/www/raspberrycloud/

# 修复权限
sudo chown -R www-data:www-data /var/www/raspberrycloud/

# 重启服务
sudo systemctl restart nginx
sudo systemctl restart raspberrycloud
```

### 方式B：保留两个版本

保持文件名不变，通过以下方式访问：

- **旧版**：`https://piowncloud.com/index.html`
- **新版**：`https://piowncloud.com/index-material.html`

---

## 🎯 主要变化

### 1. 登录页面

**Apple 风格 → Material Design**

| 变化项 | Apple 风格 | Material Design |
|-------|-----------|----------------|
| 卡片设计 | 毛玻璃效果 | 纯色卡片 + 阴影 |
| 输入框 | 简约边框 | Floating Label |
| 按钮 | 圆角渐变 | Material Filled Button |
| 图标 | Font Awesome | Material Symbols |
| 配色 | 蓝紫渐变 | MD Primary Color |

### 2. 主界面布局

**侧边栏 → Navigation Drawer**

```
旧版:                      新版:
┌──────────┬────────┐      ┌───────┬──────────┐
│          │ Header │      │ Drawer│ App Bar  │
│ Sidebar  ├────────┤  →   ├───────┼──────────┤
│          │        │      │       │          │
│          │ Content│      │ Items │ Content  │
└──────────┴────────┘      └───────┴──────────┘
```

### 3. 文件列表

**简约列表 → Material Cards**

- 更大的点击区域
- 清晰的视觉层次
- 完整的操作按钮

### 4. 交互优化

1. **波纹效果**：所有按钮都有 Material Ripple
2. **FAB 按钮**：浮动在右下角，快速上传
3. **Snackbar**：底部提示条替代弹窗
4. **主题切换**：顶部按钮一键切换明暗模式

---

## 🌓 暗色模式

### 自动切换

点击顶部 `🌙` 图标即可切换主题。

### 手动设置

```javascript
// 设置为暗色模式
document.documentElement.setAttribute('data-theme', 'dark');
localStorage.setItem('theme', 'dark');

// 设置为亮色模式
document.documentElement.setAttribute('data-theme', 'light');
localStorage.setItem('theme', 'light');
```

---

## 📱 响应式设计

### 断点

- **Mobile**: < 600px
- **Tablet**: 600px - 840px
- **Desktop**: > 840px

### 移动端特性

1. **汉堡菜单**：`☰` 按钮打开/关闭导航抽屉
2. **触摸优化**：44px 最小触摸区域
3. **简化布局**：隐藏次要信息
4. **底部操作栏**：批量操作显示在底部

---

## 🎨 自定义配色

### 修改主题色

编辑 `frontend/css/material-design.css`：

```css
:root {
  /* 修改主色调（参考 Cloudreve 的蓝紫色）*/
  --md-primary: #6750A4;        /* 主色 */
  --md-primary-container: #EADDFF; /* 主色容器 */
  
  /* 或者改成你喜欢的颜色，例如蓝色：*/
  --md-primary: #1976D2;
  --md-primary-container: #BBDEFB;
}
```

### 使用 Material Theme Builder

1. 访问 [Material Theme Builder](https://m3.material.io/theme-builder)
2. 选择你的品牌颜色
3. 导出 CSS 变量
4. 替换 `material-design.css` 中的颜色变量

---

## 🔧 开发指南

### 添加新的 Material 组件

```html
<!-- Filled Button -->
<button class="md-button-filled md-ripple">
  <span class="material-symbols-outlined">add</span>
  <span>添加</span>
</button>

<!-- Outlined Button -->
<button class="md-button-outlined md-ripple">
  <span class="material-symbols-outlined">edit</span>
  <span>编辑</span>
</button>

<!-- Icon Button -->
<button class="md-icon-button">
  <span class="material-symbols-outlined">more_vert</span>
</button>

<!-- Text Field -->
<div class="text-field">
  <input type="text" id="my-input" placeholder=" ">
  <label>标签</label>
</div>

<!-- Card -->
<div class="md-card md-elevation-2">
  <div class="md-card-content">
    内容
  </div>
</div>
```

### 使用 Material Icons

```html
<!-- Outlined Style (默认) -->
<span class="material-symbols-outlined">search</span>

<!-- 调整大小 -->
<span class="material-symbols-outlined md-48">favorite</span>

<!-- 颜色 -->
<span class="material-symbols-outlined" style="color: var(--md-primary);">
  cloud
</span>
```

---

## ❓ 常见问题

### Q1: 为什么有两个 HTML 文件？

**A:** 
- `index.html`：旧版（Apple 风格），可以删除
- `index-material.html`：新版（Material Design）

如果确定使用新版，直接替换即可。

### Q2: 图标显示不正常？

**A:** 检查网络连接，Material Icons 从 Google Fonts 加载：
```css
@import url('https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined');
```

如果无法访问 Google，可以下载字体文件到本地。

### Q3: 主题切换不生效？

**A:** 检查浏览器控制台是否有错误，确保 `material-app.js` 正确加载。

### Q4: 移动端菜单打不开？

**A:** 
1. 检查 JavaScript 控制台错误
2. 确认 `initDrawer()` 正确执行
3. 检查 CSS 中的断点设置

### Q5: 如何完全删除旧版样式？

**A:** 
```bash
cd ~/Desktop/Github/RaspiOwnCloud/frontend

# 删除旧版文件
rm index-old.html
rm css/style.css
rm css/modern.css

# 只保留 Material Design 文件
```

---

## 📚 参考资料

### Material Design 官方文档
- [Material Design 3](https://m3.material.io/)
- [Material Components](https://m3.material.io/components)
- [Material Symbols](https://fonts.google.com/icons)
- [Color System](https://m3.material.io/styles/color/overview)

### 参考项目
- [Cloudreve](https://github.com/cloudreve/cloudreve) - 多云存储管理系统
- [Cloudreve Demo](https://demo.cloudreve.org/) - 在线演示

---

## 🎉 完成！

Material Design 风格已经全面应用到 RaspberryCloud！

享受全新的现代化、优雅的用户界面！🚀

---

**最后更新**: 2026-01-14  
**版本**: Material Design 3  
**作者**: RaspberryCloud Team

