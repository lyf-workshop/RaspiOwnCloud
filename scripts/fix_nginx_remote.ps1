# 远程修复树莓派Nginx配置
# 从Windows笔记本连接到树莓派并执行修复

$ErrorActionPreference = "Stop"

# 配置信息
$PI_USER = "pi"
$PI_HOST = "192.168.137.51"
$PI_PROJECT_DIR = "/home/pi/RaspiOwnCloud"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "远程修复RaspberryCloud Nginx配置" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📡 连接信息:" -ForegroundColor Yellow
Write-Host "   用户: $PI_USER"
Write-Host "   主机: $PI_HOST"
Write-Host "   项目目录: $PI_PROJECT_DIR"
Write-Host ""

# 检查SSH客户端
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 未找到SSH客户端！" -ForegroundColor Red
    Write-Host "   请确保已安装OpenSSH客户端" -ForegroundColor Red
    Write-Host "   Windows 10/11: 设置 > 应用 > 可选功能 > OpenSSH客户端" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "🔌 正在连接到树莓派..." -ForegroundColor Yellow
Write-Host ""

# 构建SSH命令
$sshCommand = "cd $PI_PROJECT_DIR && git pull origin main && sudo bash scripts/fix_nginx.sh"

try {
    # 执行SSH命令
    ssh "$PI_USER@$PI_HOST" $sshCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ 修复完成！" -ForegroundColor Green
        Write-Host ""
        Write-Host "📝 下一步操作:" -ForegroundColor Yellow
        Write-Host "   1. 在浏览器中清除缓存 (Ctrl+Shift+Delete)"
        Write-Host "   2. 刷新页面 http://$PI_HOST"
        Write-Host "   3. 使用以下账号登录:"
        Write-Host "      用户名: admin"
        Write-Host "      密码: RaspberryCloud2024!"
        Write-Host ""
    } else {
        throw "SSH命令执行失败"
    }
} catch {
    Write-Host ""
    Write-Host "❌ 修复失败！" -ForegroundColor Red
    Write-Host ""
    Write-Host "错误信息: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "可能的原因:" -ForegroundColor Yellow
    Write-Host "   1. SSH连接失败 - 检查网络连接"
    Write-Host "   2. 需要输入密码 - 请在提示时输入树莓派密码"
    Write-Host "   3. Git拉取失败 - 检查树莓派网络连接"
    Write-Host ""
    Write-Host "💡 手动修复步骤:" -ForegroundColor Cyan
    Write-Host "   1. SSH连接到树莓派: ssh $PI_USER@$PI_HOST"
    Write-Host "   2. 进入项目目录: cd $PI_PROJECT_DIR"
    Write-Host "   3. 拉取最新代码: git pull origin main"
    Write-Host "   4. 运行修复脚本: sudo bash scripts/fix_nginx.sh"
    Write-Host ""
}

pause
























