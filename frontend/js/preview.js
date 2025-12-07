/**
 * 文件预览模块
 */

/**
 * 预览文件
 */
async function previewFile(fileId) {
    const file = state.files.find(f => f.id === fileId);
    
    if (!file || file.is_folder) return;
    
    const modal = document.getElementById('preview-modal');
    const title = document.getElementById('preview-title');
    const content = document.getElementById('preview-content');
    
    title.textContent = file.original_filename || file.filename;
    content.innerHTML = '<div class="loading"><i class="fas fa-spinner fa-spin"></i><p>加载中...</p></div>';
    
    modal.classList.add('active');
    
    const ext = utils.getFileExtension(file.filename);
    const token = utils.getToken();
    const previewUrl = `${API_BASE_URL}/files/preview/${fileId}?token=${token}`;
    const downloadUrl = `${API_BASE_URL}/files/download/${fileId}?token=${token}`;
    
    try {
        // 图片预览
        if (PREVIEW_TYPES.image.includes(ext)) {
            content.innerHTML = `
                <div class="preview-image">
                    <img src="${previewUrl}" alt="${file.filename}" 
                         style="max-width: 100%; max-height: 70vh; display: block; margin: 0 auto;">
                </div>
                <div class="preview-actions" style="margin-top: 20px; text-align: center;">
                    <button class="btn btn-primary" onclick="window.open('${downloadUrl}', '_blank')">
                        <i class="fas fa-download"></i> 下载原图
                    </button>
                </div>
            `;
        }
        // 视频预览
        else if (PREVIEW_TYPES.video.includes(ext)) {
            content.innerHTML = `
                <div class="preview-video">
                    <video controls style="max-width: 100%; max-height: 70vh; display: block; margin: 0 auto;">
                        <source src="${downloadUrl}" type="${file.mime_type}">
                        您的浏览器不支持视频播放。
                    </video>
                </div>
                <div class="preview-actions" style="margin-top: 20px; text-align: center;">
                    <button class="btn btn-primary" onclick="window.open('${downloadUrl}', '_blank')">
                        <i class="fas fa-download"></i> 下载视频
                    </button>
                </div>
            `;
        }
        // 音频预览
        else if (PREVIEW_TYPES.audio.includes(ext)) {
            content.innerHTML = `
                <div class="preview-audio" style="padding: 40px 20px; text-align: center;">
                    <i class="fas fa-music" style="font-size: 80px; color: #9933cc; margin-bottom: 20px;"></i>
                    <h3>${file.filename}</h3>
                    <audio controls style="width: 100%; max-width: 500px; margin: 20px auto;">
                        <source src="${downloadUrl}" type="${file.mime_type}">
                        您的浏览器不支持音频播放。
                    </audio>
                </div>
                <div class="preview-actions" style="margin-top: 20px; text-align: center;">
                    <button class="btn btn-primary" onclick="window.open('${downloadUrl}', '_blank')">
                        <i class="fas fa-download"></i> 下载音频
                    </button>
                </div>
            `;
        }
        // PDF预览
        else if (ext === '.pdf') {
            content.innerHTML = `
                <div class="preview-pdf">
                    <iframe src="${downloadUrl}" 
                            style="width: 100%; height: 70vh; border: none;">
                    </iframe>
                </div>
                <div class="preview-actions" style="margin-top: 20px; text-align: center;">
                    <button class="btn btn-primary" onclick="window.open('${downloadUrl}', '_blank')">
                        <i class="fas fa-download"></i> 下载PDF
                    </button>
                </div>
            `;
        }
        // 文本文件预览
        else if (ext === '.txt') {
            // 获取文本内容
            const response = await fetch(downloadUrl);
            const text = await response.text();
            
            content.innerHTML = `
                <div class="preview-text">
                    <pre style="padding: 20px; background: #f5f5f5; border-radius: 8px; 
                                overflow: auto; max-height: 60vh; white-space: pre-wrap;">${escapeHtml(text)}</pre>
                </div>
                <div class="preview-actions" style="margin-top: 20px; text-align: center;">
                    <button class="btn btn-primary" onclick="window.open('${downloadUrl}', '_blank')">
                        <i class="fas fa-download"></i> 下载文件
                    </button>
                </div>
            `;
        }
        // 其他文件类型
        else {
            content.innerHTML = `
                <div class="preview-unsupported" style="padding: 60px 20px; text-align: center;">
                    <i class="fas fa-file" style="font-size: 80px; color: #ccc; margin-bottom: 20px;"></i>
                    <h3>无法预览此文件类型</h3>
                    <p style="color: #666; margin: 15px 0;">文件名: ${file.filename}</p>
                    <p style="color: #666; margin: 15px 0;">大小: ${utils.formatFileSize(file.size)}</p>
                    <button class="btn btn-primary" onclick="window.open('${downloadUrl}', '_blank')" 
                            style="margin-top: 20px;">
                        <i class="fas fa-download"></i> 下载文件
                    </button>
                </div>
            `;
        }
    } catch (error) {
        console.error('预览失败:', error);
        content.innerHTML = `
            <div class="preview-error" style="padding: 60px 20px; text-align: center;">
                <i class="fas fa-exclamation-circle" style="font-size: 80px; color: #dc3545; margin-bottom: 20px;"></i>
                <h3>预览失败</h3>
                <p style="color: #666; margin: 15px 0;">${error.message}</p>
                <button class="btn btn-primary" onclick="window.open('${downloadUrl}', '_blank')" 
                        style="margin-top: 20px;">
                    <i class="fas fa-download"></i> 下载文件
                </button>
            </div>
        `;
    }
}

/**
 * HTML转义
 */
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

/**
 * 显示我的分享
 */
async function showMyShares() {
    try {
        const data = await utils.apiRequest('/shares/my-shares');
        
        const fileItems = document.getElementById('file-items');
        
        if (data.shares.length === 0) {
            fileItems.innerHTML = `
                <div class="empty-state">
                    <i class="fas fa-share-nodes"></i>
                    <p>暂无分享</p>
                </div>
            `;
            return;
        }
        
        fileItems.innerHTML = data.shares.map(share => `
            <div class="file-item">
                <div class="file-name">
                    <i class="fas fa-link file-icon"></i>
                    <span>分享码: ${share.share_code}</span>
                </div>
                <div class="file-col-size">${share.download_count}次下载</div>
                <div class="file-col-date">
                    ${share.expire_at ? '过期时间: ' + utils.formatDateTime(share.expire_at) : '永久有效'}
                </div>
                <div class="file-actions">
                    <button class="action-btn" onclick="copyText('${window.location.origin}/share/${share.share_code}')" title="复制链接">
                        <i class="fas fa-copy"></i>
                    </button>
                    <button class="action-btn" onclick="cancelShareLink('${share.share_code}')" title="取消分享">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            </div>
        `).join('');
    } catch (error) {
        console.error('加载分享列表失败:', error);
        utils.showNotification('加载失败: ' + error.message);
    }
}

/**
 * 取消分享
 */
async function cancelShareLink(shareCode) {
    if (!utils.confirm('确定要取消此分享吗？')) {
        return;
    }
    
    try {
        await utils.apiRequest(`/shares/${shareCode}`, {
            method: 'DELETE'
        });
        
        utils.showNotification('分享已取消');
        showMyShares(); // 刷新列表
    } catch (error) {
        utils.showNotification('取消失败: ' + error.message);
    }
}

/**
 * 复制文本到剪贴板
 */
function copyText(text) {
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    document.body.removeChild(textarea);
    utils.showNotification('已复制到剪贴板');
}

/**
 * 显示用户设置
 */
function showUserSettings() {
    alert('用户设置功能开发中...');
}


