/**
 * 批量操作功能模块
 */

// 选中文件集合
const selectedFiles = new Set();

/**
 * 初始化批量操作
 */
function initBatchOperations() {
    // 监听全选按钮
    const selectAllBtn = document.getElementById('select-all-btn');
    if (selectAllBtn) {
        selectAllBtn.addEventListener('click', toggleSelectAll);
    }
    
    // 批量操作按钮事件
    document.addEventListener('click', (e) => {
        if (e.target.closest('#batch-download-btn')) {
            batchDownload();
        }
        if (e.target.closest('#batch-delete-btn')) {
            batchDelete();
        }
        if (e.target.closest('#batch-move-btn')) {
            batchMove();
        }
        if (e.target.closest('#cancel-selection-btn')) {
            cancelSelection();
        }
    });
}

/**
 * 切换文件选中状态
 */
function toggleFileSelection(fileId, checkbox) {
    if (checkbox.checked) {
        selectedFiles.add(fileId);
    } else {
        selectedFiles.delete(fileId);
    }
    
    updateBatchToolbar();
    updateSelectAllState();
}

/**
 * 全选/取消全选
 */
function toggleSelectAll() {
    const checkboxes = document.querySelectorAll('.file-checkbox');
    const selectAllBtn = document.getElementById('select-all-btn');
    const isSelectAll = selectedFiles.size < checkboxes.length;
    
    checkboxes.forEach(checkbox => {
        const fileId = parseInt(checkbox.dataset.fileId);
        checkbox.checked = isSelectAll;
        
        if (isSelectAll) {
            selectedFiles.add(fileId);
        } else {
            selectedFiles.delete(fileId);
        }
    });
    
    updateBatchToolbar();
    updateSelectAllState();
}

/**
 * 更新全选按钮状态
 */
function updateSelectAllState() {
    const checkboxes = document.querySelectorAll('.file-checkbox');
    const selectAllBtn = document.getElementById('select-all-btn');
    
    if (!selectAllBtn) return;
    
    if (selectedFiles.size === 0) {
        selectAllBtn.innerHTML = '<i class="fas fa-check-square"></i> 全选';
    } else if (selectedFiles.size === checkboxes.length) {
        selectAllBtn.innerHTML = '<i class="fas fa-minus-square"></i> 取消全选';
    } else {
        selectAllBtn.innerHTML = `<i class="fas fa-check-square"></i> 已选 ${selectedFiles.size}`;
    }
}

/**
 * 更新批量操作工具栏
 */
function updateBatchToolbar() {
    const toolbar = document.getElementById('batch-toolbar');
    const count = document.getElementById('selected-count');
    
    if (!toolbar) return;
    
    if (selectedFiles.size > 0) {
        toolbar.classList.add('active');
        if (count) {
            count.textContent = selectedFiles.size;
        }
    } else {
        toolbar.classList.remove('active');
    }
}

/**
 * 批量下载
 */
async function batchDownload() {
    if (selectedFiles.size === 0) {
        utils.showNotification('请先选择文件');
        return;
    }
    
    const fileIds = Array.from(selectedFiles);
    
    if (fileIds.length === 1) {
        // 单个文件直接下载
        downloadFile(fileIds[0]);
    } else {
        // 多个文件打包下载
        utils.showNotification('正在打包下载...');
        
        try {
            const token = utils.getToken();
            const response = await fetch(`${API_BASE_URL}/files/batch-download`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ file_ids: fileIds })
            });
            
            if (!response.ok) {
                throw new Error('批量下载失败');
            }
            
            // 下载ZIP文件
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `批量下载_${new Date().getTime()}.zip`;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            document.body.removeChild(a);
            
            utils.showNotification('下载完成');
        } catch (error) {
            console.error('批量下载错误:', error);
            utils.showNotification('批量下载失败: ' + error.message);
        }
    }
}

/**
 * 批量删除
 */
async function batchDelete() {
    if (selectedFiles.size === 0) {
        utils.showNotification('请先选择文件');
        return;
    }
    
    if (!utils.confirm(`确定要删除选中的 ${selectedFiles.size} 个文件吗？`)) {
        return;
    }
    
    const fileIds = Array.from(selectedFiles);
    let successCount = 0;
    let failCount = 0;
    
    for (const fileId of fileIds) {
        try {
            await utils.apiRequest(`/files/${fileId}`, {
                method: 'DELETE'
            });
            successCount++;
        } catch (error) {
            console.error(`删除文件 ${fileId} 失败:`, error);
            failCount++;
        }
    }
    
    utils.showNotification(`删除完成：成功 ${successCount} 个，失败 ${failCount} 个`);
    
    // 清空选择并刷新列表
    cancelSelection();
    refreshFiles();
    loadUserInfo();
}

/**
 * 批量移动
 */
function batchMove() {
    if (selectedFiles.size === 0) {
        utils.showNotification('请先选择文件');
        return;
    }
    
    utils.showNotification('批量移动功能开发中...');
    // TODO: 实现批量移动到文件夹的功能
}

/**
 * 取消选择
 */
function cancelSelection() {
    selectedFiles.clear();
    
    const checkboxes = document.querySelectorAll('.file-checkbox');
    checkboxes.forEach(checkbox => {
        checkbox.checked = false;
    });
    
    updateBatchToolbar();
    updateSelectAllState();
}

/**
 * 获取选中的文件ID列表
 */
function getSelectedFileIds() {
    return Array.from(selectedFiles);
}

// 导出函数
window.batchOperations = {
    init: initBatchOperations,
    toggleSelection: toggleFileSelection,
    getSelected: getSelectedFileIds,
    clearSelection: cancelSelection
};

// 页面加载时初始化
document.addEventListener('DOMContentLoaded', initBatchOperations);

