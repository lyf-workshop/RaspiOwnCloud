@echo off
chcp 65001 >nul
REM 远程修复树莓派Nginx配置
REM 从Windows笔记本连接到树莓派并执行修复

echo ======================================
echo 远程修复RaspberryCloud Nginx配置
echo ======================================
echo.

REM 设置树莓派连接信息
set PI_USER=pi
set PI_HOST=192.168.137.51
set PI_PROJECT_DIR=/home/pi/RaspiOwnCloud

echo 📡 连接信息:
echo    用户: %PI_USER%
echo    主机: %PI_HOST%
echo    项目目录: %PI_PROJECT_DIR%
echo.

REM 检查是否安装了SSH客户端
where ssh >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 未找到SSH客户端！
    echo    请确保已安装OpenSSH客户端
    echo    Windows 10/11: 设置 ^> 应用 ^> 可选功能 ^> OpenSSH客户端
    pause
    exit /b 1
)

echo 🔌 正在连接到树莓派...
echo.

REM 执行远程修复命令
ssh %PI_USER%@%PI_HOST% "cd %PI_PROJECT_DIR% && git pull origin main && sudo bash scripts/fix_nginx.sh"

if %errorlevel% equ 0 (
    echo.
    echo ✅ 修复完成！
    echo.
    echo 📝 下一步操作:
    echo    1. 在浏览器中清除缓存 ^(Ctrl+Shift+Delete^)
    echo    2. 刷新页面 http://%PI_HOST%
    echo    3. 使用以下账号登录:
    echo       用户名: admin
    echo       密码: RaspberryCloud2024!
    echo.
) else (
    echo.
    echo ❌ 修复失败！
    echo.
    echo 可能的原因:
    echo    1. SSH连接失败 - 检查网络连接
    echo    2. 需要输入密码 - 请在提示时输入树莓派密码
    echo    3. Git拉取失败 - 检查树莓派网络连接
    echo.
    echo 💡 手动修复步骤:
    echo    1. SSH连接到树莓派: ssh %PI_USER%@%PI_HOST%
    echo    2. 进入项目目录: cd %PI_PROJECT_DIR%
    echo    3. 拉取最新代码: git pull origin main
    echo    4. 运行修复脚本: sudo bash scripts/fix_nginx.sh
    echo.
)

pause












