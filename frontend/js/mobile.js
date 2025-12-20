/**
 * 移动端交互优化
 */

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', () => {
    initMobileMenu();
    initTouchGestures();
    initViewportFix();
});

/**
 * 初始化移动端菜单
 */
function initMobileMenu() {
    // 创建菜单按钮
    const header = document.querySelector('.header');
    const headerLeft = document.querySelector('.header-left');
    
    if (!header || !headerLeft) return;
    
    // 只在移动端添加菜单按钮
    if (window.innerWidth <= 768) {
        // 检查是否已存在菜单按钮
        if (!document.querySelector('.menu-toggle')) {
            const menuButton = document.createElement('button');
            menuButton.className = 'menu-toggle';
            menuButton.innerHTML = '<i class="fas fa-bars"></i>';
            menuButton.setAttribute('aria-label', '打开菜单');
            
            // 插入到header-left的最前面
            headerLeft.insertBefore(menuButton, headerLeft.firstChild);
            
            // 添加点击事件
            menuButton.addEventListener('click', toggleSidebar);
        }
    }
    
    // 监听窗口大小变化
    let resizeTimer;
    window.addEventListener('resize', () => {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(() => {
            const menuBtn = document.querySelector('.menu-toggle');
            
            if (window.innerWidth <= 768) {
                // 移动端：添加菜单按钮
                if (!menuBtn) {
                    initMobileMenu();
                }
            } else {
                // 桌面端：移除菜单按钮和侧边栏激活状态
                if (menuBtn) {
                    menuBtn.remove();
                }
                const sidebar = document.querySelector('.sidebar');
                if (sidebar) {
                    sidebar.classList.remove('active');
                }
            }
        }, 250);
    });
}

/**
 * 切换侧边栏显示/隐藏
 */
function toggleSidebar() {
    const sidebar = document.querySelector('.sidebar');
    const menuButton = document.querySelector('.menu-toggle');
    
    if (!sidebar) return;
    
    const isActive = sidebar.classList.toggle('active');
    
    // 更新按钮状态和图标
    if (menuButton) {
        // 添加active类用于动画
        if (isActive) {
            menuButton.classList.add('active');
        } else {
            menuButton.classList.remove('active');
        }
        
        // 更新图标
        const icon = menuButton.querySelector('i');
        if (icon) {
            icon.className = isActive ? 'fas fa-times' : 'fas fa-bars';
        }
    }
    
    // 如果侧边栏打开，添加点击外部关闭功能
    if (isActive) {
        setTimeout(() => {
            document.addEventListener('click', closeSidebarOnOutsideClick);
        }, 100);
    } else {
        document.removeEventListener('click', closeSidebarOnOutsideClick);
    }
    
    // 防止body滚动
    document.body.style.overflow = isActive ? 'hidden' : '';
}

/**
 * 点击外部关闭侧边栏
 */
function closeSidebarOnOutsideClick(event) {
    const sidebar = document.querySelector('.sidebar');
    const menuButton = document.querySelector('.menu-toggle');
    
    if (!sidebar || !sidebar.classList.contains('active')) return;
    
    // 如果点击的不是侧边栏或菜单按钮，则关闭侧边栏
    if (!sidebar.contains(event.target) && !menuButton?.contains(event.target)) {
        toggleSidebar();
    }
}

/**
 * 初始化触摸手势
 */
function initTouchGestures() {
    const sidebar = document.querySelector('.sidebar');
    if (!sidebar) return;
    
    let touchStartX = 0;
    let touchEndX = 0;
    let isSwiping = false;
    
    // 从左边缘滑动打开
    document.addEventListener('touchstart', (e) => {
        touchStartX = e.touches[0].clientX;
        
        // 只在左边缘20px内开始滑动才响应
        if (touchStartX < 20 && !sidebar.classList.contains('active')) {
            isSwiping = true;
        }
    }, { passive: true });
    
    document.addEventListener('touchmove', (e) => {
        if (!isSwiping) return;
        
        touchEndX = e.touches[0].clientX;
        const diff = touchEndX - touchStartX;
        
        // 向右滑动超过50px
        if (diff > 50 && !sidebar.classList.contains('active')) {
            isSwiping = false;
            toggleSidebar();
        }
    }, { passive: true });
    
    document.addEventListener('touchend', () => {
        isSwiping = false;
    }, { passive: true });
    
    // 在侧边栏上向左滑动关闭
    let sidebarTouchStartX = 0;
    
    sidebar.addEventListener('touchstart', (e) => {
        sidebarTouchStartX = e.touches[0].clientX;
    }, { passive: true });
    
    sidebar.addEventListener('touchmove', (e) => {
        if (!sidebar.classList.contains('active')) return;
        
        const touchCurrentX = e.touches[0].clientX;
        const diff = touchCurrentX - sidebarTouchStartX;
        
        // 向左滑动超过50px
        if (diff < -50) {
            toggleSidebar();
        }
    }, { passive: true });
}

/**
 * 修复移动端视口问题
 */
function initViewportFix() {
    // 修复iOS地址栏导致的视口高度变化
    const setVH = () => {
        const vh = window.innerHeight * 0.01;
        document.documentElement.style.setProperty('--vh', `${vh}px`);
    };
    
    setVH();
    window.addEventListener('resize', setVH);
    window.addEventListener('orientationchange', () => {
        setTimeout(setVH, 100);
    });
}

/**
 * 优化移动端点击延迟
 */
function removeTapDelay() {
    // 移除300ms点击延迟（现代浏览器已自动处理，这里作为备用）
    document.addEventListener('touchstart', () => {}, { passive: true });
}

/**
 * 检测是否为移动设备
 */
function isMobileDevice() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
}

/**
 * 检测是否为平板设备
 */
function isTabletDevice() {
    return /iPad|Android(?!.*Mobile)/i.test(navigator.userAgent) || 
           (window.innerWidth >= 768 && window.innerWidth <= 1024);
}

/**
 * 获取设备类型
 */
function getDeviceType() {
    if (isMobileDevice()) {
        return isTabletDevice() ? 'tablet' : 'mobile';
    }
    return 'desktop';
}

// 添加设备类型到body class
document.body.classList.add(`device-${getDeviceType()}`);

// 导出函数供其他模块使用
window.mobileUtils = {
    toggleSidebar,
    isMobileDevice,
    isTabletDevice,
    getDeviceType
};

