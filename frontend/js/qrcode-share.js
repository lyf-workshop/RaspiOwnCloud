/**
 * 二维码分享功能模块
 */

/**
 * 生成二维码
 * 使用第三方库：qrcodejs2
 */
function generateQRCode(text, containerId) {
    const container = document.getElementById(containerId);
    if (!container) return;
    
    // 清空容器
    container.innerHTML = '';
    
    // 创建二维码
    try {
        if (typeof QRCode !== 'undefined') {
            new QRCode(container, {
                text: text,
                width: 200,
                height: 200,
                colorDark: "#000000",
                colorLight: "#ffffff",
                correctLevel: QRCode.CorrectLevel.H
            });
        } else {
            // 如果QRCode库未加载，使用API生成
            generateQRCodeViaAPI(text, container);
        }
    } catch (error) {
        console.error('生成二维码失败:', error);
        generateQRCodeViaAPI(text, container);
    }
}

/**
 * 通过API生成二维码（备用方案）
 */
function generateQRCodeViaAPI(text, container) {
    const encodedText = encodeURIComponent(text);
    const size = 200;
    const apiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodedText}`;
    
    const img = document.createElement('img');
    img.src = apiUrl;
    img.alt = 'QR Code';
    img.style.width = '200px';
    img.style.height = '200px';
    img.style.display = 'block';
    
    container.appendChild(img);
}

/**
 * 显示分享二维码
 */
function showShareQRCode(shareUrl) {
    const qrcodeContainer = document.getElementById('share-qrcode');
    if (!qrcodeContainer) {
        console.error('二维码容器不存在');
        return;
    }
    
    // 显示二维码区域
    qrcodeContainer.parentElement.style.display = 'block';
    
    // 生成二维码
    generateQRCode(shareUrl, 'share-qrcode');
}

/**
 * 下载二维码
 */
function downloadQRCode() {
    const qrcodeContainer = document.getElementById('share-qrcode');
    if (!qrcodeContainer) return;
    
    const canvas = qrcodeContainer.querySelector('canvas');
    const img = qrcodeContainer.querySelector('img');
    
    if (canvas) {
        // 如果是canvas，转换为图片下载
        const link = document.createElement('a');
        link.download = '分享二维码.png';
        link.href = canvas.toDataURL('image/png');
        link.click();
    } else if (img) {
        // 如果是img标签，直接下载
        const link = document.createElement('a');
        link.download = '分享二维码.png';
        link.href = img.src;
        link.target = '_blank';
        link.click();
    }
}

/**
 * 清除二维码
 */
function clearQRCode() {
    const qrcodeContainer = document.getElementById('share-qrcode');
    if (qrcodeContainer) {
        qrcodeContainer.innerHTML = '';
        qrcodeContainer.parentElement.style.display = 'none';
    }
}

// 导出函数
window.qrcodeShare = {
    generate: generateQRCode,
    show: showShareQRCode,
    download: downloadQRCode,
    clear: clearQRCode
};



