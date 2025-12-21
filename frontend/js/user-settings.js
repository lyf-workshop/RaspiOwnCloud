/**
 * 用户设置和个人中心模块
 */

/**
 * 显示用户设置对话框
 */
function showUserSettings() {
    const modal = document.getElementById('settings-modal');
    if (!modal) {
        createSettingsModal();
    }
    
    // 加载当前设置
    loadCurrentSettings();
    
    document.getElementById('settings-modal').classList.add('active');
}

/**
 * 创建设置对话框
 */
function createSettingsModal() {
    const modalHTML = `
        <div class="modal" id="settings-modal">
            <div class="modal-content modal-large">
                <div class="modal-header">
                    <h2><i class="fas fa-cog"></i> 个人中心与设置</h2>
                    <button class="close-btn" onclick="closeSettingsModal()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                
                <div class="settings-container">
                    <!-- 左侧导航 -->
                    <div class="settings-sidebar">
                        <nav class="settings-nav">
                            <a href="#" class="settings-nav-item active" data-tab="profile">
                                <i class="fas fa-user"></i> 个人信息
                            </a>
                            <a href="#" class="settings-nav-item" data-tab="storage">
                                <i class="fas fa-database"></i> 存储管理
                            </a>
                            <a href="#" class="settings-nav-item" data-tab="security">
                                <i class="fas fa-shield-alt"></i> 安全设置
                            </a>
                            <a href="#" class="settings-nav-item" data-tab="appearance">
                                <i class="fas fa-palette"></i> 外观设置
                            </a>
                            <a href="#" class="settings-nav-item" data-tab="about">
                                <i class="fas fa-info-circle"></i> 关于
                            </a>
                        </nav>
                    </div>
                    
                    <!-- 右侧内容 -->
                    <div class="settings-content">
                        <!-- 个人信息 -->
                        <div class="settings-panel active" id="panel-profile">
                            <h3>个人信息</h3>
                            
                            <div class="settings-section">
                                <div class="user-avatar-section">
                                    <div class="user-avatar-large">
                                        <i class="fas fa-user-circle"></i>
                                    </div>
                                    <button class="btn btn-secondary" disabled>
                                        <i class="fas fa-camera"></i> 更换头像（即将推出）
                                    </button>
                                </div>
                            </div>
                            
                            <div class="settings-section">
                                <label class="settings-label">用户名</label>
                                <input type="text" id="settings-username" class="input-text" readonly>
                            </div>
                            
                            <div class="settings-section">
                                <label class="settings-label">邮箱</label>
                                <input type="email" id="settings-email" class="input-text" placeholder="未设置">
                            </div>
                            
                            <div class="settings-section">
                                <label class="settings-label">注册时间</label>
                                <input type="text" id="settings-created-at" class="input-text" readonly>
                            </div>
                            
                            <div class="settings-section">
                                <button class="btn btn-primary" onclick="updateProfile()" disabled>
                                    <i class="fas fa-save"></i> 保存更改（即将推出）
                                </button>
                            </div>
                        </div>
                        
                        <!-- 存储管理 -->
                        <div class="settings-panel" id="panel-storage">
                            <h3>存储管理</h3>
                            
                            <div class="settings-section">
                                <div class="storage-overview">
                                    <div class="storage-chart">
                                        <canvas id="storage-chart-canvas"></canvas>
                                    </div>
                                    <div class="storage-stats">
                                        <div class="storage-stat-item">
                                            <div class="stat-label">已使用</div>
                                            <div class="stat-value" id="stat-used">计算中...</div>
                                        </div>
                                        <div class="storage-stat-item">
                                            <div class="stat-label">可用</div>
                                            <div class="stat-value" id="stat-available">计算中...</div>
                                        </div>
                                        <div class="storage-stat-item">
                                            <div class="stat-label">总容量</div>
                                            <div class="stat-value" id="stat-total">计算中...</div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="settings-section">
                                <h4>文件类型分布</h4>
                                <div class="file-type-list" id="file-type-list">
                                    <div class="loading-small">
                                        <i class="fas fa-spinner fa-spin"></i> 统计中...
                                    </div>
                                </div>
                            </div>
                            
                            <div class="settings-section">
                                <h4>存储清理</h4>
                                <button class="btn btn-secondary" disabled>
                                    <i class="fas fa-broom"></i> 清理缓存（即将推出）
                                </button>
                                <button class="btn btn-secondary" disabled>
                                    <i class="fas fa-trash-restore"></i> 回收站管理（即将推出）
                                </button>
                            </div>
                        </div>
                        
                        <!-- 安全设置 -->
                        <div class="settings-panel" id="panel-security">
                            <h3>安全设置</h3>
                            
                            <div class="settings-section">
                                <h4>修改密码</h4>
                                <label class="settings-label">当前密码</label>
                                <input type="password" id="current-password" class="input-text" placeholder="请输入当前密码">
                                
                                <label class="settings-label">新密码</label>
                                <input type="password" id="new-password" class="input-text" placeholder="请输入新密码">
                                
                                <label class="settings-label">确认新密码</label>
                                <input type="password" id="confirm-password" class="input-text" placeholder="再次输入新密码">
                                
                                <button class="btn btn-primary" onclick="changePassword()">
                                    <i class="fas fa-key"></i> 修改密码
                                </button>
                            </div>
                            
                            <div class="settings-section">
                                <h4>登录设备</h4>
                                <div class="device-list">
                                    <div class="device-item current">
                                        <i class="fas fa-desktop"></i>
                                        <div class="device-info">
                                            <div class="device-name">当前设备</div>
                                            <div class="device-time">最后活动：刚刚</div>
                                        </div>
                                        <span class="badge">当前</span>
                                    </div>
                                </div>
                                <p class="text-muted">多设备登录管理功能即将推出</p>
                            </div>
                        </div>
                        
                        <!-- 外观设置 -->
                        <div class="settings-panel" id="panel-appearance">
                            <h3>外观设置</h3>
                            
                            <div class="settings-section">
                                <h4>主题模式</h4>
                                <div class="theme-options">
                                    <label class="theme-option">
                                        <input type="radio" name="theme" value="light" checked>
                                        <div class="theme-preview theme-light">
                                            <i class="fas fa-sun"></i>
                                            <span>浅色</span>
                                        </div>
                                    </label>
                                    <label class="theme-option">
                                        <input type="radio" name="theme" value="dark" disabled>
                                        <div class="theme-preview theme-dark">
                                            <i class="fas fa-moon"></i>
                                            <span>深色（即将推出）</span>
                                        </div>
                                    </label>
                                    <label class="theme-option">
                                        <input type="radio" name="theme" value="auto" disabled>
                                        <div class="theme-preview theme-auto">
                                            <i class="fas fa-adjust"></i>
                                            <span>跟随系统（即将推出）</span>
                                        </div>
                                    </label>
                                </div>
                            </div>
                            
                            <div class="settings-section">
                                <h4>默认视图</h4>
                                <select class="input-text" id="default-view" onchange="saveDefaultView()">
                                    <option value="list">列表视图</option>
                                    <option value="grid">网格视图</option>
                                </select>
                            </div>
                            
                            <div class="settings-section">
                                <h4>文件排序</h4>
                                <select class="input-text" id="default-sort" disabled>
                                    <option value="name">按名称</option>
                                    <option value="date">按日期</option>
                                    <option value="size">按大小</option>
                                    <option value="type">按类型</option>
                                </select>
                                <p class="text-muted">即将推出</p>
                            </div>
                        </div>
                        
                        <!-- 关于 -->
                        <div class="settings-panel" id="panel-about">
                            <h3>关于 RaspberryCloud</h3>
                            
                            <div class="settings-section about-section">
                                <div class="about-logo">
                                    <i class="fas fa-raspberry-pi"></i>
                                </div>
                                <h2>RaspberryCloud</h2>
                                <p class="version">版本 1.0.0</p>
                                <p class="description">基于树莓派的私有云存储系统</p>
                            </div>
                            
                            <div class="settings-section">
                                <h4>系统信息</h4>
                                <div class="info-grid">
                                    <div class="info-item">
                                        <span class="info-label">后端框架</span>
                                        <span class="info-value">FastAPI + Python</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">前端技术</span>
                                        <span class="info-value">HTML5 + CSS3 + JavaScript</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">数据库</span>
                                        <span class="info-value">SQLite</span>
                                    </div>
                                    <div class="info-item">
                                        <span class="info-label">服务器</span>
                                        <span class="info-value">Nginx + Uvicorn</span>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="settings-section">
                                <h4>功能特性</h4>
                                <ul class="feature-list">
                                    <li><i class="fas fa-check"></i> 文件上传/下载/预览</li>
                                    <li><i class="fas fa-check"></i> 文件夹管理</li>
                                    <li><i class="fas fa-check"></i> 文件分享（链接+提取码）</li>
                                    <li><i class="fas fa-check"></i> 批量操作（多选+批量下载）</li>
                                    <li><i class="fas fa-check"></i> 拖拽上传</li>
                                    <li><i class="fas fa-check"></i> 二维码分享</li>
                                    <li><i class="fas fa-check"></i> 网格视图切换</li>
                                    <li><i class="fas fa-check"></i> 响应式设计（支持移动端）</li>
                                </ul>
                            </div>
                            
                            <div class="settings-section">
                                <button class="btn btn-secondary" onclick="checkUpdate()" disabled>
                                    <i class="fas fa-sync-alt"></i> 检查更新（即将推出）
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `;
    
    document.body.insertAdjacentHTML('beforeend', modalHTML);
    
    // 初始化标签切换
    initSettingsTabs();
}

/**
 * 初始化设置标签切换
 */
function initSettingsTabs() {
    const navItems = document.querySelectorAll('.settings-nav-item');
    
    navItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            
            const tab = item.dataset.tab;
            
            // 更新导航状态
            navItems.forEach(nav => nav.classList.remove('active'));
            item.classList.add('active');
            
            // 更新面板显示
            document.querySelectorAll('.settings-panel').forEach(panel => {
                panel.classList.remove('active');
            });
            document.getElementById(`panel-${tab}`).classList.add('active');
            
            // 加载对应面板数据
            loadPanelData(tab);
        });
    });
}

/**
 * 加载当前设置
 */
async function loadCurrentSettings() {
    try {
        const userInfo = await utils.apiRequest('/auth/me');
        
        // 个人信息
        document.getElementById('settings-username').value = userInfo.username || '';
        document.getElementById('settings-email').value = userInfo.email || '';
        
        const createdDate = new Date(userInfo.created_at);
        document.getElementById('settings-created-at').value = 
            createdDate.toLocaleString('zh-CN', {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            });
        
        // 存储信息
        loadStorageStats(userInfo);
        
        // 外观设置
        const savedView = localStorage.getItem('fileView') || 'list';
        document.getElementById('default-view').value = savedView;
        
    } catch (error) {
        console.error('加载设置失败:', error);
        utils.showNotification('加载设置失败');
    }
}

/**
 * 加载面板数据
 */
function loadPanelData(tab) {
    switch(tab) {
        case 'storage':
            loadStorageStats();
            break;
        // 其他面板可以在这里添加
    }
}

/**
 * 加载存储统计
 */
async function loadStorageStats(userInfo) {
    if (!userInfo) {
        try {
            userInfo = await utils.apiRequest('/auth/me');
        } catch (error) {
            console.error('加载存储信息失败:', error);
            return;
        }
    }
    
    const used = userInfo.used_space || 0;
    const total = userInfo.quota || 0;
    const available = total - used;
    
    // 更新统计数据
    document.getElementById('stat-used').textContent = utils.formatFileSize(used);
    document.getElementById('stat-available').textContent = utils.formatFileSize(available);
    document.getElementById('stat-total').textContent = utils.formatFileSize(total);
    
    // 绘制存储图表
    drawStorageChart(used, available);
    
    // 加载文件类型统计
    loadFileTypeStats();
}

/**
 * 绘制存储图表
 */
function drawStorageChart(used, available) {
    const canvas = document.getElementById('storage-chart-canvas');
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    const size = 150;
    canvas.width = size;
    canvas.height = size;
    
    const centerX = size / 2;
    const centerY = size / 2;
    const radius = 60;
    const lineWidth = 15;
    
    const total = used + available;
    const percentage = total > 0 ? (used / total) : 0;
    
    // 背景圆
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
    ctx.strokeStyle = '#f0f0f0';
    ctx.lineWidth = lineWidth;
    ctx.stroke();
    
    // 已使用部分
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius, -0.5 * Math.PI, (-0.5 + 2 * percentage) * Math.PI);
    const gradient = ctx.createLinearGradient(0, 0, size, size);
    gradient.addColorStop(0, '#667eea');
    gradient.addColorStop(1, '#764ba2');
    ctx.strokeStyle = gradient;
    ctx.lineWidth = lineWidth;
    ctx.stroke();
    
    // 中心文字
    ctx.fillStyle = '#333';
    ctx.font = 'bold 20px Arial';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(Math.round(percentage * 100) + '%', centerX, centerY);
}

/**
 * 加载文件类型统计
 */
async function loadFileTypeStats() {
    const container = document.getElementById('file-type-list');
    if (!container) return;
    
    try {
        const data = await utils.apiRequest('/files/list');
        const files = data.files || [];
        
        // 统计各类型文件
        const stats = {};
        let totalSize = 0;
        
        files.forEach(file => {
            if (file.is_folder) return;
            
            const category = file.category || 'other';
            if (!stats[category]) {
                stats[category] = { count: 0, size: 0 };
            }
            stats[category].count++;
            stats[category].size += file.size || 0;
            totalSize += file.size || 0;
        });
        
        // 渲染统计
        const categoryNames = {
            'image': '图片',
            'video': '视频',
            'audio': '音频',
            'document': '文档',
            'archive': '压缩包',
            'other': '其他'
        };
        
        const categoryIcons = {
            'image': 'fa-image',
            'video': 'fa-video',
            'audio': 'fa-music',
            'document': 'fa-file-alt',
            'archive': 'fa-file-archive',
            'other': 'fa-file'
        };
        
        let html = '';
        for (const [category, stat] of Object.entries(stats)) {
            const percentage = totalSize > 0 ? (stat.size / totalSize * 100).toFixed(1) : 0;
            html += `
                <div class="file-type-item">
                    <i class="fas ${categoryIcons[category] || 'fa-file'}"></i>
                    <div class="file-type-info">
                        <div class="file-type-name">${categoryNames[category] || category}</div>
                        <div class="file-type-detail">${stat.count} 个文件 · ${utils.formatFileSize(stat.size)}</div>
                    </div>
                    <div class="file-type-percentage">${percentage}%</div>
                </div>
            `;
        }
        
        container.innerHTML = html || '<p class="text-muted">暂无文件</p>';
        
    } catch (error) {
        console.error('加载文件类型统计失败:', error);
        container.innerHTML = '<p class="text-muted">加载失败</p>';
    }
}

/**
 * 修改密码
 */
async function changePassword() {
    const currentPassword = document.getElementById('current-password').value;
    const newPassword = document.getElementById('new-password').value;
    const confirmPassword = document.getElementById('confirm-password').value;
    
    if (!currentPassword || !newPassword || !confirmPassword) {
        utils.showNotification('请填写完整信息');
        return;
    }
    
    if (newPassword !== confirmPassword) {
        utils.showNotification('两次输入的新密码不一致');
        return;
    }
    
    if (newPassword.length < 6) {
        utils.showNotification('密码长度至少6位');
        return;
    }
    
    try {
        await utils.apiRequest('/auth/change-password', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                old_password: currentPassword,
                new_password: newPassword
            })
        });
        
        utils.showNotification('密码修改成功，请重新登录');
        
        // 清空表单
        document.getElementById('current-password').value = '';
        document.getElementById('new-password').value = '';
        document.getElementById('confirm-password').value = '';
        
        // 延迟跳转到登录页
        setTimeout(() => {
            logout();
        }, 2000);
        
    } catch (error) {
        utils.showNotification('密码修改失败: ' + error.message);
    }
}

/**
 * 保存默认视图
 */
function saveDefaultView() {
    const view = document.getElementById('default-view').value;
    localStorage.setItem('fileView', view);
    
    // 应用视图
    if (window.gridView) {
        window.gridView.switch(view);
    }
    
    utils.showNotification('默认视图已保存');
}

/**
 * 关闭设置对话框
 */
function closeSettingsModal() {
    document.getElementById('settings-modal').classList.remove('active');
}

// 点击对话框外部关闭
document.addEventListener('click', (e) => {
    const modal = document.getElementById('settings-modal');
    if (modal && e.target === modal) {
        closeSettingsModal();
    }
});

// 导出函数
window.userSettings = {
    show: showUserSettings,
    close: closeSettingsModal
};

