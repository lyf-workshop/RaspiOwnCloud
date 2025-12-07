/**
 * 配置文件
 */

// API基础URL（自动检测）
const API_BASE_URL = window.location.protocol + '//' + window.location.host + '/api';

// WebSocket URL
const WS_BASE_URL = (window.location.protocol === 'https:' ? 'wss:' : 'ws:') + '//' + window.location.host + '/ws';

// 文件大小限制
const MAX_FILE_SIZE = 10 * 1024 * 1024 * 1024; // 10GB

// 分块上传大小
const CHUNK_SIZE = 5 * 1024 * 1024; // 5MB

// 支持的预览文件类型
const PREVIEW_TYPES = {
    image: ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'],
    video: ['.mp4', '.webm', '.ogg'],
    audio: ['.mp3', '.wav', '.ogg', '.m4a'],
    document: ['.pdf', '.txt']
};

// 文件图标映射
const FILE_ICONS = {
    folder: 'fa-folder',
    image: 'fa-image',
    video: 'fa-video',
    audio: 'fa-music',
    document: 'fa-file-alt',
    pdf: 'fa-file-pdf',
    zip: 'fa-file-archive',
    code: 'fa-file-code',
    default: 'fa-file'
};

// 工具函数
const utils = {
    /**
     * 格式化文件大小
     */
    formatFileSize(bytes) {
        if (bytes === 0) return '0 B';
        
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        
        return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
    },
    
    /**
     * 格式化日期时间
     */
    formatDateTime(dateString) {
        const date = new Date(dateString);
        const now = new Date();
        const diff = now - date;
        
        // 小于1分钟
        if (diff < 60000) {
            return '刚刚';
        }
        
        // 小于1小时
        if (diff < 3600000) {
            return Math.floor(diff / 60000) + '分钟前';
        }
        
        // 小于24小时
        if (diff < 86400000) {
            return Math.floor(diff / 3600000) + '小时前';
        }
        
        // 小于7天
        if (diff < 604800000) {
            return Math.floor(diff / 86400000) + '天前';
        }
        
        // 显示完整日期
        return date.toLocaleDateString('zh-CN', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        });
    },
    
    /**
     * 获取文件扩展名
     */
    getFileExtension(filename) {
        return '.' + filename.split('.').pop().toLowerCase();
    },
    
    /**
     * 获取文件图标
     */
    getFileIcon(file) {
        if (file.is_folder) {
            return 'fa-folder';
        }
        
        const ext = this.getFileExtension(file.filename);
        
        if (PREVIEW_TYPES.image.includes(ext)) return FILE_ICONS.image;
        if (PREVIEW_TYPES.video.includes(ext)) return FILE_ICONS.video;
        if (PREVIEW_TYPES.audio.includes(ext)) return FILE_ICONS.audio;
        if (ext === '.pdf') return FILE_ICONS.pdf;
        if (['.zip', '.rar', '.7z'].includes(ext)) return FILE_ICONS.zip;
        if (['.js', '.py', '.html', '.css'].includes(ext)) return FILE_ICONS.code;
        if (PREVIEW_TYPES.document.includes(ext)) return FILE_ICONS.document;
        
        return FILE_ICONS.default;
    },
    
    /**
     * 获取token
     */
    getToken() {
        return localStorage.getItem('access_token') || sessionStorage.getItem('access_token');
    },
    
    /**
     * 获取用户信息
     */
    getUserInfo() {
        const userInfo = localStorage.getItem('user_info') || sessionStorage.getItem('user_info');
        return userInfo ? JSON.parse(userInfo) : null;
    },
    
    /**
     * API请求封装
     */
    async apiRequest(url, options = {}) {
        const token = this.getToken();
        
        const defaultOptions = {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        };
        
        // 合并选项
        const finalOptions = {
            ...defaultOptions,
            ...options,
            headers: {
                ...defaultOptions.headers,
                ...options.headers
            }
        };
        
        try {
            const response = await fetch(API_BASE_URL + url, finalOptions);
            
            // 处理401未授权
            if (response.status === 401) {
                localStorage.removeItem('access_token');
                sessionStorage.removeItem('access_token');
                window.location.href = 'login.html';
                return null;
            }
            
            // 检查响应是否成功
            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.detail || '请求失败');
            }
            
            return await response.json();
        } catch (error) {
            console.error('API请求错误:', error);
            throw error;
        }
    },
    
    /**
     * 显示通知
     */
    showNotification(message, type = 'info') {
        // 简单的alert实现，可以替换为更美观的通知组件
        alert(message);
    },
    
    /**
     * 确认对话框
     */
    confirm(message) {
        return window.confirm(message);
    }
};


