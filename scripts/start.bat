@echo off
REM RaspberryCloud Windows 快速启动脚本

echo ========================================
echo 启动 RaspberryCloud 服务
echo ========================================
echo.

REM 进入后端目录
cd /d "%~dp0..\backend"

REM 检查虚拟环境
if not exist "venv\Scripts\activate.bat" (
    echo [INFO] 创建虚拟环境...
    python -m venv venv
)

REM 激活虚拟环境
call venv\Scripts\activate.bat

REM 检查依赖
echo [INFO] 检查依赖...
pip install -q -r requirements.txt

REM 检查.env文件
if not exist ".env" (
    echo [WARN] .env文件不存在，从示例文件创建...
    copy ..\config\env.example .env
    echo [WARN] 请编辑 .env 文件配置存储路径等设置
    pause
)

REM 初始化数据库
echo [INFO] 初始化数据库...
python -c "from models import init_db; init_db()"

echo.
echo ========================================
echo 服务启动中...
echo ========================================
echo.
echo 访问地址:
echo   - 后端API: http://localhost:8000
echo   - API文档: http://localhost:8000/api/docs
echo.
echo 按 Ctrl+C 停止服务
echo.

REM 启动服务
uvicorn main:app --host 0.0.0.0 --port 8000 --reload

pause

