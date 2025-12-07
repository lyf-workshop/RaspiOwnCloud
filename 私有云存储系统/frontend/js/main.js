/**
 * 主应用逻辑
 */

// 全局状态
const state = {
    currentView: 'all',
    currentFolder: null,
    files: [],
    selectedFile: null
};

// 初始化
document.addEventListener('DOMContentLoaded', () => {
    // 检查登录状态
    if (!utils.getToken()) {
        window.location.href = 'login.html';
        return;
    }
    
    // 加载用户信息
    loadUserInfo();
    
    // 加载文件列表
    loadFiles();
    
    // 初始化事件监听
    initEventListeners();
});

/**
 * 加载用户信息
 */
async function loadUserInfo() {
    try {
        const userInfo = utils.getUserInfo();
        
        if (userInfo) {
            document.getElementById('username').textContent = userInfo.username;
            updateStorageInfo(userInfo.used_space, userInfo.quota);
        }
        
        // 从服务器更新用户信息
        const data = await utils.apiRequest('/auth/me');
        
        if (data) {
            document.getElementById('username').textContent = data.username;
            updateStorageInfo(data.used_space, data.quota);
            
            // 更新本地存储
            const storage = localStorage.getItem('access_token') ? localStorage : sessionStorage;
            storage.setItem('user_info', JSON.stringify(data));
        }
    } catch (error) {
        console.error('加载用户信息失败:', error);
    }
}

/**
 * 更新存储空间信息
 */
function updateStorageInfo(used, total) {
    const percentage = (used / total) * 100;
    document.getElementById('storage-used').style.width = percentage + '%';
    document.getElementById('storage-text').textContent = 
        `${utils.formatFileSize(used)} / ${utils.formatFileSize(total)}`;
}

/**
 * 加载文件列表
 */
async function loadFiles(parentId = null, category = null, search = null) {
    const fileItems = document.getElementById('file-items');
    fileItems.innerHTML = `
        <div class="loading">
            <i class="fas fa-spinner fa-spin"></i>
            <p>加载中...</p>
        </div>
    `;
    
    try {
        let url = '/files/list?';
        if (parentId !== null) url += `parent_id=${parentId}&`;
        if (category) url += `category=${category}&`;
        if (search) url += `search=${encodeURIComponent(search)}`;
        
        const data = await utils.apiRequest(url);
        
        state.files = data.files;
        state.currentFolder = parentId;
        
        renderFiles(data.files);
    } catch (error) {
        console.error('加载文件失败:', error);
        fileItems.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-exclamation-circle"></i>
                <p>加载失败: ${error.message}</p>
            </div>
        `;
    }
}

/**
 * 渲染文件列表
 */
function renderFiles(files) {
    const fileItems = document.getElementById('file-items');
    
    if (files.length === 0) {
        fileItems.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-folder-open"></i>
                <p>暂无文件</p>
            </div>
        `;
        return;
    }
    
    fileItems.innerHTML = files.map(file => `
        <div class="file-item" onclick="handleFileClick(${file.id})">
            <div class="file-name">
                <i class="fas ${utils.getFileIcon(file)} file-icon ${file.category}"></i>
                <span>${file.original_filename || file.filename}</span>
            </div>
            <div class="file-col-size">${file.is_folder ? '-' : utils.formatFileSize(file.size)}</div>
            <div class="file-col-date">${utils.formatDateTime(file.updated_at)}</div>
            <div class="file-actions">
                ${!file.is_folder ? `
                    <button class="action-btn" onclick="event.stopPropagation(); downloadFile(${file.id})" title="下载">
                        <i class="fas fa-download"></i>
                    </button>
                    <button class="action-btn" onclick="event.stopPropagation(); showShareDialog(${file.id})" title="分享">
                        <i class="fas fa-share-alt"></i>
                    </button>
                ` : ''}
                <button class="action-btn" onclick="event.stopPropagation(); showRenameDialog(${file.id}, '${file.filename}')" title="重命名">
                    <i class="fas fa-edit"></i>
                </button>
                <button class="action-btn" onclick="event.stopPropagation(); deleteFile(${file.id})" title="删除">
                    <i class="fas fa-trash"></i>
                </button>
            </div>
        </div>
    `).join('');
}

/**
 * 处理文件点击
 */
function handleFileClick(fileId) {
    const file = state.files.find(f => f.id === fileId);
    
    if (!file) return;
    
    if (file.is_folder) {
        navigateToFolder(fileId);
    } else {
        previewFile(fileId);
    }
}

/**
 * 导航到文件夹
 */
function navigateToFolder(folderId) {
    loadFiles(folderId);
    // TODO: 更新面包屑导航
}

/**
 * 切换视图
 */
function switchView(view) {
    state.currentView = view;
    
    // 更新导航高亮
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
    });
    event.target.closest('.nav-item').classList.add('active');
    
    // 加载对应分类文件
    const category = view === 'all' ? null : view;
    loadFiles(null, category);
}

/**
 * 刷新文件列表
 */
function refreshFiles() {
    const category = state.currentView === 'all' ? null : state.currentView;
    loadFiles(state.currentFolder, category);
}

/**
 * 显示上传对话框
 */
function showUploadDialog() {
    document.getElementById('upload-modal').classList.add('active');
}

/**
 * 显示新建文件夹对话框
 */
function showCreateFolderDialog() {
    document.getElementById('folder-modal').classList.add('active');
}

/**
 * 创建文件夹
 */
async function createFolder() {
    const folderName = document.getElementById('folder-name').value.trim();
    
    if (!folderName) {
        utils.showNotification('请输入文件夹名称');
        return;
    }
    
    try {
        const formData = new FormData();
        formData.append('folder_name', folderName);
        if (state.currentFolder !== null) {
            formData.append('parent_id', state.currentFolder);
        }
        
        await utils.apiRequest('/files/create-folder', {
            method: 'POST',
            body: formData
        });
        
        utils.showNotification('文件夹创建成功');
        closeModal('folder-modal');
        document.getElementById('folder-name').value = '';
        refreshFiles();
    } catch (error) {
        utils.showNotification('创建失败: ' + error.message);
    }
}

/**
 * 下载文件
 */
async function downloadFile(fileId) {
    const token = utils.getToken();
    window.open(`${API_BASE_URL}/files/download/${fileId}?token=${token}`, '_blank');
}

/**
 * 删除文件
 */
async function deleteFile(fileId) {
    if (!utils.confirm('确定要删除此文件吗？')) {
        return;
    }
    
    try {
        await utils.apiRequest(`/files/${fileId}`, {
            method: 'DELETE'
        });
        
        utils.showNotification('删除成功');
        refreshFiles();
        loadUserInfo(); // 更新存储空间
    } catch (error) {
        utils.showNotification('删除失败: ' + error.message);
    }
}

/**
 * 显示重命名对话框
 */
function showRenameDialog(fileId, currentName) {
    const newName = prompt('请输入新文件名:', currentName);
    
    if (newName && newName !== currentName) {
        renameFile(fileId, newName);
    }
}

/**
 * 重命名文件
 */
async function renameFile(fileId, newName) {
    try {
        const formData = new FormData();
        formData.append('new_name', newName);
        
        await utils.apiRequest(`/files/${fileId}/rename`, {
            method: 'PUT',
            body: formData
        });
        
        utils.showNotification('重命名成功');
        refreshFiles();
    } catch (error) {
        utils.showNotification('重命名失败: ' + error.message);
    }
}

/**
 * 显示分享对话框
 */
function showShareDialog(fileId) {
    state.selectedFile = fileId;
    document.getElementById('share-result').style.display = 'none';
    document.getElementById('create-share-btn').style.display = 'inline-flex';
    document.getElementById('share-modal').classList.add('active');
}

/**
 * 创建分享
 */
async function createShare() {
    const expireDays = parseInt(document.getElementById('share-expire').value);
    const needCode = document.getElementById('share-need-code').checked;
    
    try {
        const data = await utils.apiRequest('/shares/create', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                file_id: state.selectedFile,
                expire_days: expireDays,
                need_extract_code: needCode
            })
        });
        
        // 显示分享结果
        document.getElementById('share-link').value = data.share_url;
        document.getElementById('share-code-info').textContent = 
            data.extract_code ? `提取码: ${data.extract_code}` : '无需提取码';
        document.getElementById('share-result').style.display = 'block';
        document.getElementById('create-share-btn').style.display = 'none';
    } catch (error) {
        utils.showNotification('创建分享失败: ' + error.message);
    }
}

/**
 * 复制分享链接
 */
function copyShareLink() {
    const input = document.getElementById('share-link');
    input.select();
    document.execCommand('copy');
    utils.showNotification('链接已复制到剪贴板');
}

/**
 * 关闭对话框
 */
function closeModal(modalId) {
    document.getElementById(modalId).classList.remove('active');
}

/**
 * 退出登录
 */
function logout() {
    if (utils.confirm('确定要退出登录吗？')) {
        localStorage.removeItem('access_token');
        localStorage.removeItem('user_info');
        sessionStorage.removeItem('access_token');
        sessionStorage.removeItem('user_info');
        window.location.href = 'login.html';
    }
}

/**
 * 初始化事件监听
 */
function initEventListeners() {
    // 搜索
    const searchInput = document.getElementById('search-input');
    let searchTimeout;
    
    searchInput.addEventListener('input', (e) => {
        clearTimeout(searchTimeout);
        searchTimeout = setTimeout(() => {
            const keyword = e.target.value.trim();
            if (keyword) {
                loadFiles(null, null, keyword);
            } else {
                refreshFiles();
            }
        }, 500);
    });
}

