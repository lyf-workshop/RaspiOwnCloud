# Windows端远程诊断脚本
# 检查树莓派上的RaspberryCloud登录问题

$ErrorActionPreference = "Continue"

$PI_USER = "pi"
$PI_HOST = "192.168.137.51"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RaspberryCloud 远程诊断" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 测试网络连接
Write-Host "1️⃣  测试网络连接..." -ForegroundColor Yellow
Write-Host "---"

$pingResult = Test-Connection -ComputerName $PI_HOST -Count 2 -Quiet
if ($pingResult) {
    Write-Host "✅ 网络连接正常" -ForegroundColor Green
} else {
    Write-Host "❌ 无法连接到树莓派 ($PI_HOST)" -ForegroundColor Red
    Write-Host "   请检查:" -ForegroundColor Yellow
    Write-Host "   - 树莓派是否开机"
    Write-Host "   - 网线是否连接"
    Write-Host "   - IP地址是否正确"
    pause
    exit 1
}
Write-Host ""

# 2. 测试后端API（直接访问8000端口）
Write-Host "2️⃣  测试后端API (http://${PI_HOST}:8000/api/health)..." -ForegroundColor Yellow
Write-Host "---"

try {
    $response = Invoke-WebRequest -Uri "http://${PI_HOST}:8000/api/health" -TimeoutSec 5 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ 后端API响应正常" -ForegroundColor Green
        Write-Host "   响应内容: $($response.Content)" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ 后端API无响应或错误" -ForegroundColor Red
    Write-Host "   错误信息: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "⚠️  后端服务可能未运行，需要在树莓派上检查" -ForegroundColor Yellow
}
Write-Host ""

# 3. 测试Nginx代理（80端口）
Write-Host "3️⃣  测试Nginx API代理 (http://${PI_HOST}/api/health)..." -ForegroundColor Yellow
Write-Host "---"

try {
    $response = Invoke-WebRequest -Uri "http://${PI_HOST}/api/health" -TimeoutSec 5 -UseBasicParsing
    
    if ($response.StatusCode -eq 200) {
        $content = $response.Content
        
        # 检查返回的是JSON还是HTML
        if ($content -match "^\s*<html" -or $content -match "<!DOCTYPE") {
            Write-Host "❌ Nginx返回HTML而不是JSON！" -ForegroundColor Red
            Write-Host "   这就是导致登录错误的原因！" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "   返回内容前100字符:" -ForegroundColor Gray
            Write-Host "   $($content.Substring(0, [Math]::Min(100, $content.Length)))" -ForegroundColor Gray
            $nginxError = $true
        } elseif ($content -match '"status"') {
            Write-Host "✅ Nginx代理正常，返回JSON" -ForegroundColor Green
            Write-Host "   响应内容: $content" -ForegroundColor Gray
            $nginxError = $false
        } else {
            Write-Host "⚠️  Nginx返回了非预期的内容" -ForegroundColor Yellow
            Write-Host "   响应内容: $content" -ForegroundColor Gray
            $nginxError = $true
        }
    }
} catch {
    Write-Host "❌ Nginx代理无响应或错误" -ForegroundColor Red
    Write-Host "   错误信息: $($_.Exception.Message)" -ForegroundColor Red
    $nginxError = $true
}
Write-Host ""

# 4. 测试登录接口
Write-Host "4️⃣  测试登录接口 (POST http://${PI_HOST}/api/auth/login)..." -ForegroundColor Yellow
Write-Host "---"

try {
    $body = @{
        username = "admin"
        password = "RaspberryCloud2024!"
    } | ConvertTo-Json
    
    $response = Invoke-WebRequest `
        -Uri "http://${PI_HOST}/api/auth/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $body `
        -TimeoutSec 10 `
        -UseBasicParsing
    
    if ($response.StatusCode -eq 200) {
        $content = $response.Content
        
        if ($content -match "^\s*<html" -or $content -match "<!DOCTYPE") {
            Write-Host "❌ 登录接口返回HTML而不是JSON！" -ForegroundColor Red
            Write-Host "   这就是浏览器显示JSON错误的原因！" -ForegroundColor Yellow
        } elseif ($content -match '"access_token"') {
            Write-Host "✅ 登录接口正常，返回access_token" -ForegroundColor Green
        } else {
            Write-Host "⚠️  登录接口返回了非预期的内容" -ForegroundColor Yellow
            Write-Host "   响应内容: $content" -ForegroundColor Gray
        }
    }
} catch {
    $errorResponse = $_.Exception.Response
    if ($errorResponse) {
        $reader = New-Object System.IO.StreamReader($errorResponse.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        
        Write-Host "❌ 登录接口返回错误" -ForegroundColor Red
        Write-Host "   状态码: $($errorResponse.StatusCode)" -ForegroundColor Red
        Write-Host "   响应内容前200字符: $($responseBody.Substring(0, [Math]::Min(200, $responseBody.Length)))" -ForegroundColor Gray
        
        if ($responseBody -match "^\s*<html" -or $responseBody -match "<!DOCTYPE") {
            Write-Host ""
            Write-Host "❌ 确认：返回的是HTML，不是JSON！" -ForegroundColor Red
            $nginxError = $true
        }
    } else {
        Write-Host "❌ 登录接口无响应" -ForegroundColor Red
        Write-Host "   错误信息: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# 5. SSH执行详细诊断
Write-Host "5️⃣  SSH远程执行详细诊断..." -ForegroundColor Yellow
Write-Host "---"
Write-Host "正在连接到树莓派执行诊断脚本..." -ForegroundColor Gray
Write-Host ""

try {
    ssh "$PI_USER@$PI_HOST" "bash -s" < "$PSScriptRoot/diagnose_login.sh"
} catch {
    Write-Host "⚠️  无法通过SSH执行诊断" -ForegroundColor Yellow
    Write-Host "   请手动SSH到树莓派执行:" -ForegroundColor Yellow
    Write-Host "   ssh $PI_USER@$PI_HOST" -ForegroundColor Cyan
    Write-Host "   cd /home/pi/RaspiOwnCloud" -ForegroundColor Cyan
    Write-Host "   bash scripts/diagnose_login.sh" -ForegroundColor Cyan
}
Write-Host ""

# 6. 总结和建议
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📊 诊断总结和修复建议" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($nginxError) {
    Write-Host "🔴 主要问题: Nginx配置错误" -ForegroundColor Red
    Write-Host ""
    Write-Host "原因: location /api/ 没有正确代理到后端" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "解决方案 1 - 自动修复 (推荐):" -ForegroundColor Green
    Write-Host "   在PowerShell中运行:" -ForegroundColor Cyan
    Write-Host "   cd F:\Github\RaspiOwnCloud" -ForegroundColor White
    Write-Host "   .\scripts\fix_nginx_remote.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "解决方案 2 - 手动修复:" -ForegroundColor Green
    Write-Host "   1. SSH连接: ssh $PI_USER@$PI_HOST" -ForegroundColor White
    Write-Host "   2. 进入目录: cd /home/pi/RaspiOwnCloud" -ForegroundColor White
    Write-Host "   3. 拉取代码: git pull origin main" -ForegroundColor White
    Write-Host "   4. 运行修复: sudo bash scripts/fix_nginx.sh" -ForegroundColor White
    Write-Host ""
    Write-Host "解决方案 3 - 强制更新Nginx配置:" -ForegroundColor Green
    Write-Host "   ssh $PI_USER@$PI_HOST << 'EOF'" -ForegroundColor White
    Write-Host "   cd /home/pi/RaspiOwnCloud" -ForegroundColor White
    Write-Host "   sudo cp config/nginx.conf /etc/nginx/sites-available/raspberrycloud" -ForegroundColor White
    Write-Host "   sudo nginx -t && sudo systemctl restart nginx" -ForegroundColor White
    Write-Host "   EOF" -ForegroundColor White
} else {
    Write-Host "✅ 从Windows端看，API端点工作正常" -ForegroundColor Green
    Write-Host ""
    Write-Host "如果浏览器仍然显示JSON错误，请尝试:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. 清除浏览器缓存" -ForegroundColor Cyan
    Write-Host "   - 按 Ctrl+Shift+Delete" -ForegroundColor White
    Write-Host "   - 选择'缓存的图片和文件'" -ForegroundColor White
    Write-Host "   - 清除所有时间的缓存" -ForegroundColor White
    Write-Host ""
    Write-Host "2. 使用无痕模式测试" -ForegroundColor Cyan
    Write-Host "   - 按 Ctrl+Shift+N 打开无痕窗口" -ForegroundColor White
    Write-Host "   - 访问 http://$PI_HOST" -ForegroundColor White
    Write-Host ""
    Write-Host "3. 检查浏览器开发者工具" -ForegroundColor Cyan
    Write-Host "   - 按 F12 打开开发者工具" -ForegroundColor White
    Write-Host "   - 切换到 Network 标签" -ForegroundColor White
    Write-Host "   - 尝试登录并查看 login 请求的 Response" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
pause



























