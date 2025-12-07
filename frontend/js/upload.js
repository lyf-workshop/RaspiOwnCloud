/**
 * 文件上传模块
 */

// 上传队列
const uploadQueue = [];
let uploadingCount = 0;
const MAX_CONCURRENT_UPLOADS = 3;

/**
 * 初始化上传功能
 */
document.addEventListener('DOMContentLoaded', () => {
    const uploadArea = document.getElementById('upload-area');
    const fileInput = document.getElementById('file-input');
    
    if (!uploadArea || !fileInput) return;
    
    // 点击上传区域
    uploadArea.addEventListener('click', () => {
        fileInput.click();
    });
    
    // 文件选择
    fileInput.addEventListener('change', (e) => {
        handleFiles(e.target.files);
        fileInput.value = ''; // 清空，允许重复上传同一文件
    });
    
    // 拖拽上传
    uploadArea.addEventListener('dragover', (e) => {
        e.preventDefault();
        uploadArea.classList.add('dragover');
    });
    
    uploadArea.addEventListener('dragleave', () => {
        uploadArea.classList.remove('dragover');
    });
    
    uploadArea.addEventListener('drop', (e) => {
        e.preventDefault();
        uploadArea.classList.remove('dragover');
        handleFiles(e.dataTransfer.files);
    });
});

/**
 * 处理文件
 */
function handleFiles(files) {
    if (!files || files.length === 0) return;
    
    // 检查文件大小
    for (let file of files) {
        if (file.size > MAX_FILE_SIZE) {
            utils.showNotification(`文件 ${file.name} 超过大小限制（最大10GB）`);
            continue;
        }
        
        // 添加到上传队列
        const uploadTask = {
            id: Date.now() + Math.random(),
            file: file,
            progress: 0,
            status: 'pending', // pending, uploading, success, error
            error: null
        };
        
        uploadQueue.push(uploadTask);
        addUploadItem(uploadTask);
    }
    
    // 开始上传
    processUploadQueue();
}

/**
 * 添加上传项到UI
 */
function addUploadItem(task) {
    const uploadList = document.getElementById('upload-list');
    
    const item = document.createElement('div');
    item.className = 'upload-item';
    item.id = `upload-item-${task.id}`;
    
    item.innerHTML = `
        <div class="upload-info">
            <i class="fas fa-file"></i>
            <span class="upload-filename">${task.file.name}</span>
            <span class="upload-size">(${utils.formatFileSize(task.file.size)})</span>
        </div>
        <div class="upload-progress">
            <div class="progress-text">
                <span class="progress-percent">0%</span>
                <span class="progress-status">等待中...</span>
            </div>
            <div class="progress-bar">
                <div class="progress-fill" style="width: 0%"></div>
            </div>
        </div>
        <button class="btn-icon" onclick="cancelUpload('${task.id}')" title="取消">
            <i class="fas fa-times"></i>
        </button>
    `;
    
    uploadList.appendChild(item);
}

/**
 * 更新上传进度
 */
function updateUploadProgress(taskId, progress, status) {
    const item = document.getElementById(`upload-item-${taskId}`);
    if (!item) return;
    
    const progressFill = item.querySelector('.progress-fill');
    const progressPercent = item.querySelector('.progress-percent');
    const progressStatus = item.querySelector('.progress-status');
    
    progressFill.style.width = progress + '%';
    progressPercent.textContent = Math.round(progress) + '%';
    progressStatus.textContent = status;
}

/**
 * 处理上传队列
 */
async function processUploadQueue() {
    // 检查是否有待上传的任务
    const pendingTasks = uploadQueue.filter(t => t.status === 'pending');
    
    if (pendingTasks.length === 0 || uploadingCount >= MAX_CONCURRENT_UPLOADS) {
        return;
    }
    
    // 获取下一个任务
    const task = pendingTasks[0];
    task.status = 'uploading';
    uploadingCount++;
    
    updateUploadProgress(task.id, 0, '上传中...');
    
    try {
        await uploadFile(task);
        task.status = 'success';
        task.progress = 100;
        updateUploadProgress(task.id, 100, '上传成功');
        
        // 延迟移除成功项
        setTimeout(() => {
            const item = document.getElementById(`upload-item-${task.id}`);
            if (item) item.remove();
        }, 2000);
        
        // 刷新文件列表
        if (typeof refreshFiles === 'function') {
            refreshFiles();
        }
        
        // 更新存储空间
        if (typeof loadUserInfo === 'function') {
            loadUserInfo();
        }
    } catch (error) {
        task.status = 'error';
        task.error = error.message;
        updateUploadProgress(task.id, 0, '上传失败: ' + error.message);
    } finally {
        uploadingCount--;
        // 继续处理队列
        processUploadQueue();
    }
}

/**
 * 上传文件
 */
async function uploadFile(task) {
    const formData = new FormData();
    formData.append('file', task.file);
    
    if (state.currentFolder !== null) {
        formData.append('parent_id', state.currentFolder);
    }
    
    return new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        
        // 上传进度
        xhr.upload.addEventListener('progress', (e) => {
            if (e.lengthComputable) {
                const progress = (e.loaded / e.total) * 100;
                task.progress = progress;
                updateUploadProgress(task.id, progress, '上传中...');
            }
        });
        
        // 上传完成
        xhr.addEventListener('load', () => {
            if (xhr.status === 200) {
                try {
                    const response = JSON.parse(xhr.responseText);
                    if (response.success) {
                        resolve(response);
                    } else {
                        reject(new Error(response.message || '上传失败'));
                    }
                } catch (e) {
                    reject(new Error('解析响应失败'));
                }
            } else {
                try {
                    const error = JSON.parse(xhr.responseText);
                    reject(new Error(error.detail || `上传失败 (${xhr.status})`));
                } catch (e) {
                    reject(new Error(`上传失败 (${xhr.status})`));
                }
            }
        });
        
        // 上传错误
        xhr.addEventListener('error', () => {
            reject(new Error('网络错误'));
        });
        
        // 上传取消
        xhr.addEventListener('abort', () => {
            reject(new Error('上传已取消'));
        });
        
        // 保存xhr以便取消
        task.xhr = xhr;
        
        // 发送请求
        const token = utils.getToken();
        xhr.open('POST', API_BASE_URL + '/files/upload');
        xhr.setRequestHeader('Authorization', `Bearer ${token}`);
        xhr.send(formData);
    });
}

/**
 * 取消上传
 */
function cancelUpload(taskId) {
    const task = uploadQueue.find(t => t.id == taskId);
    
    if (!task) return;
    
    if (task.xhr && task.status === 'uploading') {
        task.xhr.abort();
    }
    
    // 从队列移除
    const index = uploadQueue.indexOf(task);
    if (index > -1) {
        uploadQueue.splice(index, 1);
    }
    
    // 移除UI
    const item = document.getElementById(`upload-item-${taskId}`);
    if (item) item.remove();
}


