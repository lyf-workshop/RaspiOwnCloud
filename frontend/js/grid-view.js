/**
 * 网格视图切换功能
 */

let currentView = 'list'; // 'list' or 'grid'

/**
 * 初始化视图切换
 */
function initGridView() {
    // 从本地存储读取用户偏好
    const savedView = localStorage.getItem('fileView') || 'list';
    currentView = savedView;
    
    // 应用保存的视图
    applyView(currentView);
    
    // 绑定切换按钮事件
    document.addEventListener('click', (e) => {
        if (e.target.closest('[data-view]')) {
            const btn = e.target.closest('[data-view]');
            const view = btn.dataset.view;
            switchView(view);
        }
    });
}

/**
 * 切换视图
 */
function switchView(view) {
    if (view === currentView) return;
    
    currentView = view;
    localStorage.setItem('fileView', view);
    
    applyView(view);
    updateViewButtons();
}

/**
 * 应用视图样式
 */
function applyView(view) {
    const fileList = document.getElementById('file-list');
    const fileItems = document.getElementById('file-items');
    
    if (!fileList || !fileItems) return;
    
    if (view === 'grid') {
        fileList.classList.add('grid-view');
        fileList.classList.remove('list-view');
    } else {
        fileList.classList.add('list-view');
        fileList.classList.remove('grid-view');
    }
    
    // 重新渲染文件列表以适应新视图
    const files = state.files;
    if (files && files.length > 0) {
        renderFiles(files);
    }
    
    updateViewButtons();
}

/**
 * 更新视图按钮状态
 */
function updateViewButtons() {
    const buttons = document.querySelectorAll('[data-view]');
    buttons.forEach(btn => {
        const view = btn.dataset.view;
        if (view === currentView) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });
}

/**
 * 渲染网格视图文件项
 */
function renderGridItem(file) {
    const icon = utils.getFileIcon(file);
    const isFolder = file.is_folder;
    
    return `
        <div class="grid-item" onclick="handleFileClick(${file.id})">
            <div class="grid-item-checkbox">
                <input type="checkbox" 
                       class="file-checkbox" 
                       data-file-id="${file.id}"
                       onclick="event.stopPropagation(); batchOperations.toggleSelection(${file.id}, this)">
            </div>
            <div class="grid-item-preview">
                ${isFolder ? 
                    `<i class="fas ${icon} grid-item-icon"></i>` :
                    (file.category === 'image' ? 
                        `<img src="${API_BASE_URL}/files/preview/${file.id}" 
                              alt="${file.filename}" 
                              class="grid-item-image"
                              onerror="this.style.display='none'; this.nextElementSibling.style.display='block';">
                         <i class="fas ${icon} grid-item-icon" style="display:none;"></i>` :
                        `<i class="fas ${icon} grid-item-icon"></i>`)
                }
            </div>
            <div class="grid-item-info">
                <div class="grid-item-name" title="${file.original_filename || file.filename}">
                    ${file.original_filename || file.filename}
                </div>
                <div class="grid-item-meta">
                    ${isFolder ? '文件夹' : utils.formatFileSize(file.size)}
                </div>
            </div>
            <div class="grid-item-actions">
                ${!isFolder ? `
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
    `;
}

/**
 * 渲染列表视图文件项
 */
function renderListItem(file) {
    const icon = utils.getFileIcon(file);
    
    return `
        <div class="file-item" onclick="handleFileClick(${file.id})">
            <div class="file-col-checkbox">
                <input type="checkbox" 
                       class="file-checkbox" 
                       data-file-id="${file.id}"
                       onclick="event.stopPropagation(); batchOperations.toggleSelection(${file.id}, this)">
            </div>
            <div class="file-name">
                <i class="fas ${icon} file-icon ${file.category || ''}"></i>
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
    `;
}

/**
 * 获取当前视图
 */
function getCurrentView() {
    return currentView;
}

// 页面加载时初始化
document.addEventListener('DOMContentLoaded', initGridView);

// 导出函数
window.gridView = {
    init: initGridView,
    switch: switchView,
    getCurrent: getCurrentView,
    renderGridItem: renderGridItem,
    renderListItem: renderListItem
};



