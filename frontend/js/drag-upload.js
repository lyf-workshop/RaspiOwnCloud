/**
 * 拖拽上传功能模块
 */

let dragCounter = 0;

/**
 * 初始化拖拽上传
 */
function initDragUpload() {
    const dropZone = document.querySelector('.file-list');
    const overlay = createDragOverlay();
    
    if (!dropZone) return;
    
    // 拖拽进入
    dropZone.addEventListener('dragenter', (e) => {
        e.preventDefault();
        dragCounter++;
        
        if (dragCounter === 1) {
            overlay.classList.add('active');
        }
    });
    
    // 拖拽经过
    dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'copy';
    });
    
    // 拖拽离开
    dropZone.addEventListener('dragleave', (e) => {
        e.preventDefault();
        dragCounter--;
        
        if (dragCounter === 0) {
            overlay.classList.remove('active');
        }
    });
    
    // 放置文件
    dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        dragCounter = 0;
        overlay.classList.remove('active');
        
        const files = e.dataTransfer.files;
        if (files.length > 0) {
            handleDroppedFiles(files);
        }
    });
    
    // 全局拖拽防止打开文件
    document.addEventListener('dragover', (e) => {
        e.preventDefault();
    });
    
    document.addEventListener('drop', (e) => {
        e.preventDefault();
    });
}

/**
 * 创建拖拽遮罩层
 */
function createDragOverlay() {
    let overlay = document.getElementById('drag-overlay');
    
    if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'drag-overlay';
        overlay.className = 'drag-overlay';
        overlay.innerHTML = `
            <div class="drag-overlay-content">
                <i class="fas fa-cloud-upload-alt"></i>
                <h3>松开鼠标上传文件</h3>
                <p>支持多文件同时上传</p>
            </div>
        `;
        document.body.appendChild(overlay);
    }
    
    return overlay;
}

/**
 * 处理拖拽的文件
 */
async function handleDroppedFiles(files) {
    const fileArray = Array.from(files);
    
    // 过滤掉文件夹
    const validFiles = fileArray.filter(file => file.size > 0);
    
    if (validFiles.length === 0) {
        utils.showNotification('不支持上传文件夹');
        return;
    }
    
    // 检查文件大小
    const oversizedFiles = validFiles.filter(file => file.size > MAX_FILE_SIZE);
    if (oversizedFiles.length > 0) {
        utils.showNotification(`有 ${oversizedFiles.length} 个文件超过大小限制`);
        return;
    }
    
    // 显示上传对话框并开始上传
    showUploadDialog();
    
    // 使用现有的上传功能
    for (const file of validFiles) {
        if (window.uploadManager) {
            window.uploadManager.addFile(file);
        }
    }
    
    utils.showNotification(`开始上传 ${validFiles.length} 个文件`);
}

/**
 * 显示上传对话框
 */
function showUploadDialog() {
    const modal = document.getElementById('upload-modal');
    if (modal) {
        modal.classList.add('active');
    }
}

// 页面加载时初始化
document.addEventListener('DOMContentLoaded', initDragUpload);

// 导出函数
window.dragUpload = {
    init: initDragUpload
};

