/**
 * 分享页面逻辑
 */

let shareCode = '';
let shareInfo = null;

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', () => {
    // 从URL获取分享码
    const path = window.location.pathname;
    const match = path.match(/\/share\/([a-zA-Z0-9]+)/);
    
    if (match && match[1]) {
        shareCode = match[1];
        loadShareInfo();
    } else {
        showError('无效的分享链接');
    }
});

/**
 * 加载分享信息
 */
async function loadShareInfo() {
    try {
        // 不需要登录即可访问分享信息
        const response = await fetch(`${API_BASE_URL}/shares/info/${shareCode}`);
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || '获取分享信息失败');
        }
        
        shareInfo = await response.json();
        renderShareInfo();
    } catch (error) {
        console.error('加载分享信息失败:', error);
        showError(error.message || '加载分享信息失败');
    }
}

/**
 * 渲染分享信息
 */
function renderShareInfo() {
    const content = document.getElementById('share-content');
    
    // 检查分享是否有效
    if (!shareInfo.is_active || shareInfo.is_expired) {
        content.innerHTML = `
            <div class="error-message">
                <i class="fas fa-exclamation-circle"></i>
                <p>${shareInfo.is_expired ? '分享已过期' : '分享已失效'}</p>
            </div>
        `;
        return;
    }
    
    // 构建文件信息HTML
    let html = `
        <div class="file-info">
            <div class="file-info-item">
                <i class="fas ${getFileIcon()}"></i>
                <div class="info-text">
                    <div class="info-label">文件名</div>
                    <div class="info-value">${escapeHtml(shareInfo.filename)}</div>
                </div>
            </div>
            <div class="file-info-item">
                <i class="fas fa-hdd"></i>
                <div class="info-text">
                    <div class="info-label">文件大小</div>
                    <div class="info-value">${utils.formatFileSize(shareInfo.size)}</div>
                </div>
            </div>
    `;
    
    // 显示过期时间
    if (shareInfo.expire_at) {
        const expireDate = new Date(shareInfo.expire_at);
        html += `
            <div class="file-info-item">
                <i class="fas fa-clock"></i>
                <div class="info-text">
                    <div class="info-label">有效期至</div>
                    <div class="info-value">
                        ${expireDate.toLocaleString('zh-CN')}
                    </div>
                </div>
            </div>
        `;
    }
    
    // 显示剩余下载次数
    if (shareInfo.downloads_remaining !== null) {
        html += `
            <div class="file-info-item">
                <i class="fas fa-download"></i>
                <div class="info-text">
                    <div class="info-label">剩余下载次数</div>
                    <div class="info-value">
                        ${shareInfo.downloads_remaining}
                        ${shareInfo.downloads_remaining === 0 ? '<span class="info-badge expired-badge">已达上限</span>' : ''}
                    </div>
                </div>
            </div>
        `;
    }
    
    html += `</div>`;
    
    // 如果需要提取码
    if (shareInfo.need_extract_code) {
        html += `
            <div class="extract-code-input">
                <label for="extract-code">
                    <i class="fas fa-key"></i> 请输入提取码
                </label>
                <input 
                    type="text" 
                    id="extract-code" 
                    placeholder="请输入4位提取码"
                    maxlength="4"
                    autocomplete="off"
                >
            </div>
        `;
    }
    
    // 下载按钮
    html += `
        <button 
            class="download-btn" 
            onclick="downloadFile()"
            ${shareInfo.downloads_remaining === 0 ? 'disabled' : ''}
        >
            <i class="fas fa-download"></i> 
            ${shareInfo.downloads_remaining === 0 ? '已达下载上限' : '下载文件'}
        </button>
    `;
    
    content.innerHTML = html;
}

/**
 * 下载文件
 */
async function downloadFile() {
    const downloadBtn = document.querySelector('.download-btn');
    
    // 如果需要提取码，验证提取码
    let extractCode = null;
    if (shareInfo.need_extract_code) {
        extractCode = document.getElementById('extract-code').value.trim();
        
        if (!extractCode) {
            alert('请输入提取码');
            return;
        }
        
        if (extractCode.length !== 4) {
            alert('提取码必须是4位');
            return;
        }
    }
    
    // 禁用按钮，防止重复点击
    downloadBtn.disabled = true;
    downloadBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> 准备下载...';
    
    try {
        // 验证访问权限
        const accessResponse = await fetch(`${API_BASE_URL}/shares/access`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                share_code: shareCode,
                extract_code: extractCode
            })
        });
        
        if (!accessResponse.ok) {
            const error = await accessResponse.json();
            throw new Error(error.detail || '验证失败');
        }
        
        // 构建下载URL
        let downloadUrl = `${API_BASE_URL}/shares/download/${shareCode}`;
        if (extractCode) {
            downloadUrl += `?extract_code=${encodeURIComponent(extractCode)}`;
        }
        
        // 创建隐藏的下载链接并触发下载
        const a = document.createElement('a');
        a.href = downloadUrl;
        a.download = shareInfo.filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        
        // 延迟后恢复按钮并更新信息
        setTimeout(() => {
            downloadBtn.innerHTML = '<i class="fas fa-check"></i> 下载已开始';
            
            // 如果有下载次数限制，更新显示
            if (shareInfo.downloads_remaining !== null && shareInfo.downloads_remaining > 0) {
                shareInfo.downloads_remaining -= 1;
                
                setTimeout(() => {
                    renderShareInfo();
                }, 2000);
            } else {
                setTimeout(() => {
                    downloadBtn.innerHTML = '<i class="fas fa-download"></i> 再次下载';
                    downloadBtn.disabled = false;
                }, 2000);
            }
        }, 1000);
        
    } catch (error) {
        console.error('下载失败:', error);
        alert('下载失败: ' + error.message);
        
        // 恢复按钮
        downloadBtn.disabled = false;
        downloadBtn.innerHTML = '<i class="fas fa-download"></i> 下载文件';
    }
}

/**
 * 显示错误信息
 */
function showError(message) {
    const content = document.getElementById('share-content');
    content.innerHTML = `
        <div class="error-message">
            <i class="fas fa-exclamation-circle"></i>
            <p>${escapeHtml(message)}</p>
        </div>
    `;
}

/**
 * 获取文件图标
 */
function getFileIcon() {
    if (!shareInfo) return 'fa-file';
    
    const category = shareInfo.category;
    const icons = {
        'image': 'fa-image',
        'video': 'fa-video',
        'audio': 'fa-music',
        'document': 'fa-file-alt',
        'other': 'fa-file'
    };
    
    return icons[category] || 'fa-file';
}

/**
 * HTML转义
 */
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}






