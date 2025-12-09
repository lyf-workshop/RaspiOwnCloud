"""
RaspberryCloud 主程序
FastAPI后端服务入口
"""

from fastapi import FastAPI, Depends, HTTPException, status, File as FastAPIFile, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from typing import Optional, List
from pathlib import Path
import aiofiles
from datetime import datetime

from config import settings
from models import get_db, init_db, User, File
from auth import (
    authenticate_user, create_access_token, get_current_user, get_current_admin_user,
    register_user, update_user_password, UserCreate, UserLogin, UserResponse, Token
)
from email_verification import send_verification_code, verify_code
from file_handler import FileService
from share import ShareService, ShareCreate, ShareResponse, ShareAccessRequest

# 创建FastAPI应用
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="树莓派私有云存储系统 - 功能对标百度网盘",
    docs_url="/api/docs" if settings.DEBUG else None,
    redoc_url="/api/redoc" if settings.DEBUG else None
)

# CORS中间件（跨域请求）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应该限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ==================== 健康检查 ====================

@app.get("/api/health")
async def health_check():
    """健康检查接口"""
    return {
        "status": "healthy",
        "version": settings.APP_VERSION,
        "timestamp": datetime.utcnow().isoformat()
    }


# ==================== 用户认证 ====================

@app.post("/api/auth/send-verification-code")
async def send_code(email: str, db: Session = Depends(get_db)):
    """
    发送邮箱验证码
    
    - **email**: 邮箱地址
    """
    # 验证邮箱格式
    import re
    if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="邮箱格式不正确"
        )
    
    # 检查邮箱是否已被注册
    existing_user = db.query(User).filter(User.email == email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该邮箱已被注册"
        )
    
    # 发送验证码
    result = send_verification_code(db, email)
    return result


@app.post("/api/auth/register", response_model=UserResponse)
async def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """
    用户注册（需要邮箱验证码）
    
    - **username**: 用户名（3-20字符）
    - **email**: 邮箱地址
    - **password**: 密码（至少8位）
    - **verification_code**: 邮箱验证码
    - **full_name**: 全名（可选）
    """
    user = register_user(db, user_data)
    return user


@app.post("/api/auth/login", response_model=Token)
async def login(user_data: UserLogin, db: Session = Depends(get_db)):
    """
    用户登录
    
    - **username**: 用户名
    - **password**: 密码
    
    返回JWT access token
    """
    print(f"[LOGIN] 登录请求: username={user_data.username}, password_length={len(user_data.password)}")
    
    user = authenticate_user(db, user_data.username, user_data.password)
    
    if not user:
        print(f"[LOGIN] 登录失败: {user_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    print(f"[LOGIN] 登录成功: {user_data.username}")
    
    # 更新最后登录时间
    user.last_login = datetime.utcnow()
    db.commit()
    
    # 生成JWT token
    access_token = create_access_token(
        data={"sub": user.username, "user_id": user.id}
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_info": {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "full_name": user.full_name,
            "is_admin": user.is_admin,
            "quota": user.quota,
            "used_space": user.used_space
        }
    }


@app.get("/api/auth/me", response_model=UserResponse)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """获取当前用户信息"""
    return current_user


@app.post("/api/auth/change-password")
async def change_password(
    old_password: str = Form(...),
    new_password: str = Form(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """修改密码"""
    success = update_user_password(db, current_user, old_password, new_password)
    
    return {"success": success, "message": "密码修改成功"}


# ==================== 文件管理 ====================

@app.post("/api/files/upload")
async def upload_file(
    file: UploadFile = FastAPIFile(...),
    parent_id: Optional[int] = Form(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    上传文件
    
    - **file**: 文件数据
    - **parent_id**: 父文件夹ID（可选）
    """
    file_service = FileService(db)
    uploaded_file = await file_service.upload_file(current_user, file, parent_id)
    
    return {
        "success": True,
        "file": {
            "id": uploaded_file.id,
            "filename": uploaded_file.filename,
            "original_filename": uploaded_file.original_filename,
            "size": uploaded_file.size,
            "category": uploaded_file.category,
            "created_at": uploaded_file.created_at.isoformat()
        }
    }


@app.post("/api/files/create-folder")
async def create_folder(
    folder_name: str = Form(...),
    parent_id: Optional[int] = Form(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    创建文件夹
    
    - **folder_name**: 文件夹名称
    - **parent_id**: 父文件夹ID（可选）
    """
    file_service = FileService(db)
    folder = file_service.create_folder(current_user, folder_name, parent_id)
    
    return {
        "success": True,
        "folder": {
            "id": folder.id,
            "filename": folder.filename,
            "created_at": folder.created_at.isoformat()
        }
    }


@app.get("/api/files/list")
async def list_files(
    parent_id: Optional[int] = None,
    category: Optional[str] = None,
    search: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    列出文件
    
    - **parent_id**: 父文件夹ID（可选，默认为根目录）
    - **category**: 文件类别过滤（image/video/audio/document，可选）
    - **search**: 搜索关键词（可选）
    """
    file_service = FileService(db)
    files = file_service.list_files(current_user, parent_id, category, search)
    
    return {
        "files": [
            {
                "id": f.id,
                "filename": f.filename,
                "original_filename": f.original_filename,
                "size": f.size,
                "category": f.category,
                "is_folder": f.is_folder,
                "mime_type": f.mime_type,
                "created_at": f.created_at.isoformat(),
                "updated_at": f.updated_at.isoformat()
            }
            for f in files
        ]
    }


@app.get("/api/files/download/{file_id}")
async def download_file(
    file_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    下载文件
    
    - **file_id**: 文件ID
    """
    file_service = FileService(db)
    file = file_service.get_file(current_user, file_id)
    
    if file.is_folder:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="无法下载文件夹"
        )
    
    file_path = Path(file.file_path)
    
    if not file_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="文件不存在"
        )
    
    return FileResponse(
        path=file_path,
        filename=file.original_filename or file.filename,
        media_type=file.mime_type or 'application/octet-stream'
    )


@app.get("/api/files/preview/{file_id}")
async def preview_file(
    file_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    预览文件（返回缩略图或原文件）
    
    - **file_id**: 文件ID
    """
    file_service = FileService(db)
    file = file_service.get_file(current_user, file_id)
    
    file_path = Path(file.file_path)
    
    # 如果是图片，尝试返回缩略图
    if file.category == "image":
        thumbnail_dir = settings.get_user_storage_path(current_user.id) / ".thumbnails"
        thumbnail_path = thumbnail_dir / f"{file.md5_hash}.jpg"
        
        if thumbnail_path.exists():
            return FileResponse(
                path=thumbnail_path,
                media_type='image/jpeg'
            )
    
    # 返回原文件
    if file_path.exists():
        return FileResponse(
            path=file_path,
            media_type=file.mime_type or 'application/octet-stream'
        )
    
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="文件不存在"
    )


@app.delete("/api/files/{file_id}")
async def delete_file(
    file_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    删除文件
    
    - **file_id**: 文件ID
    """
    file_service = FileService(db)
    success = file_service.delete_file(current_user, file_id)
    
    return {"success": success, "message": "文件已删除"}


@app.put("/api/files/{file_id}/rename")
async def rename_file(
    file_id: int,
    new_name: str = Form(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    重命名文件
    
    - **file_id**: 文件ID
    - **new_name**: 新文件名
    """
    file_service = FileService(db)
    file = file_service.rename_file(current_user, file_id, new_name)
    
    return {
        "success": True,
        "file": {
            "id": file.id,
            "filename": file.filename
        }
    }


@app.put("/api/files/{file_id}/move")
async def move_file(
    file_id: int,
    new_parent_id: Optional[int] = Form(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    移动文件
    
    - **file_id**: 文件ID
    - **new_parent_id**: 新父文件夹ID（null表示移到根目录）
    """
    file_service = FileService(db)
    file = file_service.move_file(current_user, file_id, new_parent_id)
    
    return {
        "success": True,
        "file": {
            "id": file.id,
            "parent_id": file.parent_id
        }
    }


# ==================== 文件分享 ====================

@app.post("/api/shares/create", response_model=ShareResponse)
async def create_share(
    share_data: ShareCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    创建分享链接
    
    - **file_id**: 要分享的文件ID
    - **expire_days**: 过期天数（1-7天）
    - **need_extract_code**: 是否需要提取码
    - **max_downloads**: 最大下载次数（可选）
    """
    share_service = ShareService(db)
    share = share_service.create_share(current_user, share_data)
    
    # 构建分享URL
    base_url = "http://raspberrycloud.local"  # 生产环境应从配置读取
    share_url = f"{base_url}/share/{share.share_code}"
    
    return {
        "share_code": share.share_code,
        "extract_code": share.extract_code,
        "share_url": share_url,
        "expire_at": share.expire_at,
        "max_downloads": share.max_downloads
    }


@app.get("/api/shares/info/{share_code}")
async def get_share_info(share_code: str, db: Session = Depends(get_db)):
    """
    获取分享信息（不需要登录）
    
    - **share_code**: 分享码
    """
    share_service = ShareService(db)
    info = share_service.get_share_info(share_code)
    
    return info


@app.post("/api/shares/access")
async def access_share(
    access_data: ShareAccessRequest,
    db: Session = Depends(get_db)
):
    """
    访问分享（验证提取码）
    
    - **share_code**: 分享码
    - **extract_code**: 提取码（如果需要）
    """
    share_service = ShareService(db)
    share = share_service.verify_share_access(
        access_data.share_code,
        access_data.extract_code
    )
    
    # 获取文件信息
    file = db.query(File).filter(File.id == share.file_id).first()
    
    return {
        "success": True,
        "file": {
            "id": file.id,
            "filename": file.original_filename or file.filename,
            "size": file.size,
            "category": file.category,
            "mime_type": file.mime_type
        }
    }


@app.get("/api/shares/download/{share_code}")
async def download_shared_file(
    share_code: str,
    extract_code: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    下载分享的文件
    
    - **share_code**: 分享码
    - **extract_code**: 提取码（如果需要）
    """
    share_service = ShareService(db)
    share = share_service.verify_share_access(share_code, extract_code)
    
    # 获取文件
    file = db.query(File).filter(File.id == share.file_id).first()
    
    if not file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="文件不存在"
        )
    
    file_path = Path(file.file_path)
    
    if not file_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="文件不存在"
        )
    
    # 增加下载次数
    share_service.increment_download_count(share)
    
    return FileResponse(
        path=file_path,
        filename=file.original_filename or file.filename,
        media_type=file.mime_type or 'application/octet-stream'
    )


@app.get("/api/shares/my-shares")
async def list_my_shares(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """列出我的分享"""
    share_service = ShareService(db)
    shares = share_service.list_user_shares(current_user)
    
    return {
        "shares": [
            {
                "id": s.id,
                "share_code": s.share_code,
                "file_id": s.file_id,
                "extract_code": s.extract_code,
                "expire_at": s.expire_at.isoformat() if s.expire_at else None,
                "max_downloads": s.max_downloads,
                "download_count": s.download_count,
                "is_active": s.is_active,
                "created_at": s.created_at.isoformat()
            }
            for s in shares
        ]
    }


@app.delete("/api/shares/{share_code}")
async def cancel_share(
    share_code: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """取消分享"""
    share_service = ShareService(db)
    success = share_service.cancel_share(current_user, share_code)
    
    return {"success": success, "message": "分享已取消"}


# ==================== 用户管理（管理员） ====================

@app.get("/api/admin/users")
async def list_users(
    current_admin: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """列出所有用户（仅管理员）"""
    users = db.query(User).all()
    
    return {
        "users": [
            {
                "id": u.id,
                "username": u.username,
                "email": u.email,
                "full_name": u.full_name,
                "is_active": u.is_active,
                "is_admin": u.is_admin,
                "quota": u.quota,
                "used_space": u.used_space,
                "created_at": u.created_at.isoformat()
            }
            for u in users
        ]
    }


@app.put("/api/admin/users/{user_id}/quota")
async def update_user_quota(
    user_id: int,
    new_quota: int = Form(...),
    current_admin: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    """更新用户配额（仅管理员）"""
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )
    
    user.quota = new_quota
    db.commit()
    
    return {"success": True, "message": "配额已更新"}


# ==================== 统计信息 ====================

@app.get("/api/stats")
async def get_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取用户统计信息"""
    # 文件统计
    total_files = db.query(File).filter(
        File.owner_id == current_user.id,
        File.is_deleted == False,
        File.is_folder == False
    ).count()
    
    total_folders = db.query(File).filter(
        File.owner_id == current_user.id,
        File.is_deleted == False,
        File.is_folder == True
    ).count()
    
    # 分类统计
    files_by_category = {}
    for category in ['image', 'video', 'audio', 'document', 'other']:
        count = db.query(File).filter(
            File.owner_id == current_user.id,
            File.is_deleted == False,
            File.category == category
        ).count()
        files_by_category[category] = count
    
    return {
        "user": {
            "username": current_user.username,
            "quota": current_user.quota,
            "used_space": current_user.used_space,
            "available_space": current_user.quota - current_user.used_space,
            "usage_percentage": (current_user.used_space / current_user.quota * 100) if current_user.quota > 0 else 0
        },
        "files": {
            "total": total_files,
            "folders": total_folders,
            "by_category": files_by_category
        }
    }


# ==================== 启动事件 ====================

@app.on_event("startup")
async def startup_event():
    """应用启动时执行"""
    print(f"🚀 {settings.APP_NAME} v{settings.APP_VERSION} 正在启动...")
    
    # 初始化数据库
    try:
        init_db()
        print("✅ 数据库初始化完成")
    except Exception as e:
        print(f"❌ 数据库初始化失败: {e}")
    
    # 确保存储目录存在
    settings.ensure_directories()
    print("✅ 存储目录检查完成")
    
    print(f"✨ {settings.APP_NAME} 启动成功！")


@app.on_event("shutdown")
async def shutdown_event():
    """应用关闭时执行"""
    print(f"👋 {settings.APP_NAME} 正在关闭...")


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        workers=2 if not settings.DEBUG else 1
    )


