// Apple风格移动端菜单
(function() {
    'use strict';
    
    // 创建移动端菜单按钮
    function createMobileMenuButton() {
        const header = document.querySelector('.header-left');
        if (!header) return;
        
        // 检查是否已存在
        if (document.querySelector('.mobile-menu-btn')) return;
        
        const menuBtn = document.createElement('button');
        menuBtn.className = 'mobile-menu-btn';
        menuBtn.innerHTML = '<i class="fas fa-bars"></i>';
        menuBtn.style.cssText = `
            display: none;
            background: transparent;
            border: none;
            font-size: 20px;
            color: var(--text-primary);
            cursor: pointer;
            padding: 8px;
            margin-right: 12px;
            transition: all 0.2s ease;
            border-radius: 8px;
        `;
        
        // 移动端显示
        if (window.innerWidth <= 768) {
            menuBtn.style.display = 'block';
        }
        
        // 点击切换侧边栏
        menuBtn.addEventListener('click', toggleSidebar);
        
        // 悬停效果
        menuBtn.addEventListener('mouseenter', function() {
            this.style.background = 'rgba(0, 0, 0, 0.05)';
        });
        menuBtn.addEventListener('mouseleave', function() {
            this.style.background = 'transparent';
        });
        
        header.insertBefore(menuBtn, header.firstChild);
    }
    
    // 切换侧边栏
    function toggleSidebar() {
        const sidebar = document.querySelector('.sidebar');
        const overlay = document.querySelector('.sidebar-overlay');
        
        if (!sidebar) return;
        
        const isActive = sidebar.classList.contains('active');
        
        if (isActive) {
            closeSidebar();
        } else {
            openSidebar();
        }
    }
    
    // 打开侧边栏
    function openSidebar() {
        const sidebar = document.querySelector('.sidebar');
        let overlay = document.querySelector('.sidebar-overlay');
        
        if (!overlay) {
            overlay = createOverlay();
        }
        
        sidebar.classList.add('active');
        overlay.classList.add('active');
        document.body.style.overflow = 'hidden';
    }
    
    // 关闭侧边栏
    function closeSidebar() {
        const sidebar = document.querySelector('.sidebar');
        const overlay = document.querySelector('.sidebar-overlay');
        
        sidebar.classList.remove('active');
        if (overlay) {
            overlay.classList.remove('active');
        }
        document.body.style.overflow = '';
    }
    
    // 创建遮罩层
    function createOverlay() {
        const overlay = document.createElement('div');
        overlay.className = 'sidebar-overlay';
        overlay.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.4);
            backdrop-filter: blur(4px);
            -webkit-backdrop-filter: blur(4px);
            z-index: 998;
            opacity: 0;
            transition: opacity 0.3s ease;
            display: none;
        `;
        
        overlay.addEventListener('click', closeSidebar);
        document.body.appendChild(overlay);
        
        // 触发重排以启用过渡
        setTimeout(() => {
            overlay.style.display = 'block';
            overlay.style.opacity = '1';
        }, 10);
        
        return overlay;
    }
    
    // 响应式处理
    function handleResize() {
        const menuBtn = document.querySelector('.mobile-menu-btn');
        const sidebar = document.querySelector('.sidebar');
        
        if (window.innerWidth <= 768) {
            if (menuBtn) menuBtn.style.display = 'block';
            closeSidebar();
        } else {
            if (menuBtn) menuBtn.style.display = 'none';
            if (sidebar) sidebar.classList.remove('active');
            const overlay = document.querySelector('.sidebar-overlay');
            if (overlay) overlay.remove();
            document.body.style.overflow = '';
        }
    }
    
    // 触摸滑动关闭侧边栏
    let touchStartX = 0;
    let touchEndX = 0;
    
    function handleTouchStart(e) {
        touchStartX = e.touches[0].clientX;
    }
    
    function handleTouchMove(e) {
        touchEndX = e.touches[0].clientX;
    }
    
    function handleTouchEnd() {
        const sidebar = document.querySelector('.sidebar');
        if (!sidebar || !sidebar.classList.contains('active')) return;
        
        const swipeDistance = touchStartX - touchEndX;
        
        // 向左滑动超过50px关闭
        if (swipeDistance > 50) {
            closeSidebar();
        }
    }
    
    // 初始化
    function init() {
        createMobileMenuButton();
        
        // 监听窗口大小变化
        window.addEventListener('resize', handleResize);
        
        // 触摸事件
        const sidebar = document.querySelector('.sidebar');
        if (sidebar) {
            sidebar.addEventListener('touchstart', handleTouchStart, { passive: true });
            sidebar.addEventListener('touchmove', handleTouchMove, { passive: true });
            sidebar.addEventListener('touchend', handleTouchEnd);
        }
        
        // ESC键关闭
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                closeSidebar();
            }
        });
    }
    
    // DOM加载完成后初始化
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();

