/**
 * Material Design App 初始化和交互逻辑
 * RaspberryCloud - Private Cloud Storage
 */

// Global state
let currentTheme = localStorage.getItem('theme') || 'light';
let selectedFiles = new Set();

// Initialize Material App
function initMaterialApp() {
    initTheme();
    initDrawer();
    initUserMenu();
    initViewToggle();
    initFileSelection();
    loadUserInfo();
    loadFiles();
}

// ==================== Theme System ====================
function initTheme() {
    document.documentElement.setAttribute('data-theme', currentTheme);
    updateThemeIcon();
    
    const themeToggle = document.getElementById('theme-toggle');
    if (themeToggle) {
        themeToggle.addEventListener('click', toggleTheme);
    }
}

function toggleTheme() {
    currentTheme = currentTheme === 'light' ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', currentTheme);
    localStorage.setItem('theme', currentTheme);
    updateThemeIcon();
}

function updateThemeIcon() {
    const icon = document.querySelector('#theme-toggle .material-symbols-outlined');
    if (icon) {
        icon.textContent = currentTheme === 'light' ? 'dark_mode' : 'light_mode';
    }
}

// ==================== Navigation Drawer ====================
function initDrawer() {
    const menuBtn = document.getElementById('menu-btn');
    const drawer = document.getElementById('drawer');
    const drawerScrim = document.getElementById('drawer-scrim');
    const drawerItems = document.querySelectorAll('.md-drawer-item[data-view]');
    
    // Toggle drawer on mobile
    if (menuBtn) {
        menuBtn.addEventListener('click', () => {
            drawer.classList.toggle('open');
            drawerScrim.classList.toggle('active');
        });
    }
    
    // Close drawer when clicking scrim
    if (drawerScrim) {
        drawerScrim.addEventListener('click', () => {
            drawer.classList.remove('open');
            drawerScrim.classList.remove('active');
        });
    }
    
    // Handle drawer item selection
    drawerItems.forEach(item => {
        item.addEventListener('click', (e) => {
            // Remove active class from all items
            drawerItems.forEach(i => i.classList.remove('active'));
            // Add active class to clicked item
            item.classList.add('active');
            
            // Get view type
            const view = item.dataset.view;
            switchView(view);
            
            // Close drawer on mobile
            if (window.innerWidth <= 840) {
                drawer.classList.remove('open');
                drawerScrim.classList.remove('active');
            }
        });
    });
}

// ==================== User Menu ====================
function initUserMenu() {
    const userMenuBtn = document.getElementById('user-menu-btn');
    const userMenu = document.getElementById('user-menu');
    
    if (userMenuBtn && userMenu) {
        userMenuBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            userMenu.classList.toggle('active');
        });
        
        // Close menu when clicking outside
        document.addEventListener('click', (e) => {
            if (!userMenu.contains(e.target) && !userMenuBtn.contains(e.target)) {
                userMenu.classList.remove('active');
            }
        });
    }
}

// ==================== View Toggle ====================
function initViewToggle() {
    const gridBtn = document.getElementById('view-grid-btn');
    const listBtn = document.getElementById('view-list-btn');
    const listHeader = document.getElementById('list-header');
    const fileList = document.getElementById('file-list');
    
    if (gridBtn) {
        gridBtn.addEventListener('click', () => {
            listBtn.classList.remove('active');
            gridBtn.classList.add('active');
            listHeader.style.display = 'none';
            fileList.classList.add('grid-view');
            fileList.classList.remove('list-view');
        });
    }
    
    if (listBtn) {
        listBtn.addEventListener('click', () => {
            gridBtn.classList.remove('active');
            listBtn.classList.add('active');
            listHeader.style.display = 'grid';
            fileList.classList.remove('grid-view');
            fileList.classList.add('list-view');
        });
    }
}

// ==================== File Selection ====================
function initFileSelection() {
    const selectAllCheckbox = document.getElementById('select-all');
    
    if (selectAllCheckbox) {
        selectAllCheckbox.addEventListener('change', (e) => {
            const checkboxes = document.querySelectorAll('.md-file-item input[type="checkbox"]');
            checkboxes.forEach(checkbox => {
                checkbox.checked = e.target.checked;
                if (e.target.checked) {
                    selectedFiles.add(checkbox.value);
                } else {
                    selectedFiles.delete(checkbox.value);
                }
            });
            updateBatchToolbar();
        });
    }
}

function updateBatchToolbar() {
    const snackbar = document.getElementById('batch-snackbar');
    const selectedCount = document.getElementById('selected-count');
    
    if (selectedFiles.size > 0) {
        snackbar.classList.add('active');
        selectedCount.textContent = selectedFiles.size;
    } else {
        snackbar.classList.remove('active');
    }
}

function cancelSelection() {
    selectedFiles.clear();
    const checkboxes = document.querySelectorAll('.md-file-item input[type="checkbox"]');
    checkboxes.forEach(checkbox => {
        checkbox.checked = false;
    });
    document.getElementById('select-all').checked = false;
    updateBatchToolbar();
}

// ==================== Data Loading ====================
async function loadUserInfo() {
    try {
        const token = localStorage.getItem('access_token') || sessionStorage.getItem('access_token');
        if (!token) {
            window.location.href = 'login.html';
            return;
        }
        
        const response = await fetch(`${API_BASE_URL}/users/me`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });
        
        if (response.ok) {
            const user = await response.json();
            document.getElementById('username').textContent = user.username;
            
            // Load storage info
            await loadStorageInfo();
        } else {
            throw new Error('Failed to load user info');
        }
    } catch (error) {
        console.error('Error loading user info:', error);
        window.location.href = 'login.html';
    }
}

async function loadStorageInfo() {
    try {
        const token = localStorage.getItem('access_token') || sessionStorage.getItem('access_token');
        
        const response = await fetch(`${API_BASE_URL}/storage/info`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            const used = data.used_storage || 0;
            const total = data.total_storage || 107374182400; // 100GB default
            const percentage = (used / total * 100).toFixed(1);
            
            const storageBar = document.getElementById('storage-bar');
            const storageText = document.getElementById('storage-text');
            
            if (storageBar) {
                storageBar.style.width = percentage + '%';
            }
            
            if (storageText) {
                storageText.textContent = `${formatFileSize(used)} / ${formatFileSize(total)}`;
            }
        }
    } catch (error) {
        console.error('Error loading storage info:', error);
    }
}

async function loadFiles(folderId = null) {
    const fileList = document.getElementById('file-list');
    
    // Show loading
    fileList.innerHTML = `
        <div class="md-loading-state">
            <div class="md-progress-circular">
                <svg viewBox="0 0 50 50">
                    <circle cx="25" cy="25" r="20" fill="none" stroke="currentColor" stroke-width="4"/>
                </svg>
            </div>
            <p>加载中...</p>
        </div>
    `;
    
    try {
        const token = localStorage.getItem('access_token') || sessionStorage.getItem('access_token');
        const url = folderId 
            ? `${API_BASE_URL}/files/folder/${folderId}`
            : `${API_BASE_URL}/files/list`;
        
        const response = await fetch(url, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });
        
        if (response.ok) {
            const files = await response.json();
            renderFiles(files);
        } else {
            throw new Error('Failed to load files');
        }
    } catch (error) {
        console.error('Error loading files:', error);
        fileList.innerHTML = `
            <div class="md-loading-state">
                <span class="material-symbols-outlined" style="font-size: 48px; color: var(--md-error);">error</span>
                <p style="color: var(--md-error);">加载失败</p>
            </div>
        `;
    }
}

function renderFiles(files) {
    const fileList = document.getElementById('file-list');
    
    if (files.length === 0) {
        fileList.innerHTML = `
            <div class="md-loading-state">
                <span class="material-symbols-outlined" style="font-size: 48px;">folder_open</span>
                <p>这里还没有文件</p>
            </div>
        `;
        return;
    }
    
    fileList.innerHTML = files.map(file => `
        <div class="md-file-item" data-file-id="${file.id}">
            <div class="file-col-checkbox">
                <input type="checkbox" value="${file.id}" onchange="handleFileSelection('${file.id}', this.checked)">
            </div>
            <div class="file-icon-container">
                <div class="file-icon ${getFileTypeClass(file.file_type)}">
                    <span class="material-symbols-outlined">${getFileIcon(file.file_type)}</span>
                </div>
                <div class="file-name" ondblclick="handleFileClick('${file.id}', '${file.file_type}')">
                    ${file.filename}
                </div>
            </div>
            <div class="file-size">${formatFileSize(file.file_size)}</div>
            <div class="file-date">${formatDate(file.updated_at)}</div>
            <div class="file-actions">
                <button class="md-icon-button" onclick="downloadFile('${file.id}')" title="下载">
                    <span class="material-symbols-outlined">download</span>
                </button>
                <button class="md-icon-button" onclick="shareFile('${file.id}')" title="分享">
                    <span class="material-symbols-outlined">share</span>
                </button>
                <button class="md-icon-button" onclick="deleteFile('${file.id}')" title="删除">
                    <span class="material-symbols-outlined">delete</span>
                </button>
            </div>
        </div>
    `).join('');
}

// ==================== Helper Functions ====================
function getFileIcon(fileType) {
    const iconMap = {
        'folder': 'folder',
        'image': 'image',
        'video': 'video_library',
        'audio': 'music_note',
        'document': 'description',
        'pdf': 'picture_as_pdf',
        'archive': 'folder_zip',
        'code': 'code'
    };
    return iconMap[fileType] || 'description';
}

function getFileTypeClass(fileType) {
    return fileType || 'document';
}

function formatFileSize(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function formatDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diff = now - date;
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    
    if (days === 0) {
        return '今天 ' + date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
    } else if (days === 1) {
        return '昨天';
    } else if (days < 7) {
        return `${days}天前`;
    } else {
        return date.toLocaleDateString('zh-CN');
    }
}

function handleFileSelection(fileId, checked) {
    if (checked) {
        selectedFiles.add(fileId);
    } else {
        selectedFiles.delete(fileId);
    }
    updateBatchToolbar();
}

// ==================== File Actions ====================
function refreshFiles() {
    loadFiles();
}

function switchView(view) {
    console.log('Switching to view:', view);
    // Implement view filtering logic
    loadFiles();
}

function handleFileClick(fileId, fileType) {
    if (fileType === 'folder') {
        navigateToFolder(fileId);
    } else {
        previewFile(fileId);
    }
}

function navigateToFolder(folderId) {
    loadFiles(folderId);
    // Update breadcrumb
    // Implementation depends on your backend structure
}

function downloadFile(fileId) {
    console.log('Downloading file:', fileId);
    // Implement download logic
}

function shareFile(fileId) {
    console.log('Sharing file:', fileId);
    // Implement share logic
}

function deleteFile(fileId) {
    if (confirm('确定要删除这个文件吗？')) {
        console.log('Deleting file:', fileId);
        // Implement delete logic
    }
}

function previewFile(fileId) {
    console.log('Previewing file:', fileId);
    // Implement preview logic
}

function showUploadDialog() {
    console.log('Show upload dialog');
    // Implement upload dialog
}

function showCreateFolderDialog() {
    console.log('Show create folder dialog');
    // Implement create folder dialog
}

function showUserSettings() {
    console.log('Show user settings');
    // Implement user settings
}

function showMyShares() {
    console.log('Show my shares');
    // Implement shares view
}

function showRecycleBin() {
    console.log('Show recycle bin');
    // Implement recycle bin
}

function logout() {
    if (confirm('确定要退出登录吗？')) {
        localStorage.removeItem('access_token');
        localStorage.removeItem('user_info');
        sessionStorage.removeItem('access_token');
        sessionStorage.removeItem('user_info');
        window.location.href = 'login.html';
    }
}

