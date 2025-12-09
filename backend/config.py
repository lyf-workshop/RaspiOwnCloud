"""
配置管理模块
从环境变量和.env文件读取配置
"""

import os
from pathlib import Path
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    """应用配置"""
    
    # 应用信息
    APP_NAME: str = "RaspberryCloud"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    
    # 安全配置
    SECRET_KEY: str = "your-secret-key-change-this-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7天
    
    # 数据库配置
    DATABASE_URL: str = "sqlite:///./raspberrycloud.db"
    
    # 存储路径配置
    # 默认使用SD卡存储（适合64GB SD卡，无外接硬盘）
    # 如需使用外接硬盘，在.env中修改为 /mnt/cloud_storage/*
    STORAGE_PATH: str = "/opt/raspberrycloud/storage/users"
    SHARE_PATH: str = "/opt/raspberrycloud/storage/shares"
    TEMP_PATH: str = "/opt/raspberrycloud/storage/temp"
    BACKUP_PATH: str = "/opt/raspberrycloud/storage/backups"
    
    # 文件限制
    MAX_FILE_SIZE: int = 10 * 1024 * 1024 * 1024  # 10GB
    MAX_UPLOAD_THREADS: int = 5
    CHUNK_SIZE: int = 5 * 1024 * 1024  # 5MB分块
    
    # 允许的文件类型
    ALLOWED_IMAGE_EXTENSIONS: set = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"}
    ALLOWED_VIDEO_EXTENSIONS: set = {".mp4", ".avi", ".mkv", ".mov", ".flv", ".wmv"}
    ALLOWED_AUDIO_EXTENSIONS: set = {".mp3", ".wav", ".flac", ".aac", ".ogg", ".m4a"}
    ALLOWED_DOCUMENT_EXTENSIONS: set = {".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt"}
    
    # 默认管理员配置
    ADMIN_USERNAME: str = "admin"
    ADMIN_PASSWORD: str = "RaspberryCloud2024!"
    ADMIN_EMAIL: str = "admin@raspberrycloud.local"
    
    # 默认用户配额（字节）
    # SD卡方案（64GB）：建议20GB，外接硬盘方案可设置为100GB
    DEFAULT_USER_QUOTA: int = 20 * 1024 * 1024 * 1024  # 20GB（SD卡方案）
    
    # 分享链接配置
    SHARE_LINK_LENGTH: int = 8
    MAX_SHARE_DAYS: int = 7
    
    # 邮件配置（邮箱验证）
    SMTP_HOST: str = "smtp.qq.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = ""
    
    # 缩略图配置
    THUMBNAIL_SIZE: tuple = (200, 200)
    PREVIEW_SIZE: tuple = (1920, 1080)
    
    # 同步配置
    SYNC_INTERVAL: int = 60  # 秒
    
    class Config:
        env_file = ".env"
        case_sensitive = True

    def ensure_directories(self):
        """确保所有必要的目录存在"""
        directories = [
            self.STORAGE_PATH,
            self.SHARE_PATH,
            self.TEMP_PATH,
            self.BACKUP_PATH,
        ]
        for directory in directories:
            Path(directory).mkdir(parents=True, exist_ok=True)
    
    def get_user_storage_path(self, user_id: int) -> Path:
        """获取用户存储路径"""
        path = Path(self.STORAGE_PATH) / str(user_id)
        path.mkdir(parents=True, exist_ok=True)
        return path
    
    def get_share_path(self, share_code: str) -> Path:
        """获取分享文件路径"""
        path = Path(self.SHARE_PATH) / share_code
        path.mkdir(parents=True, exist_ok=True)
        return path
    
    def is_image(self, filename: str) -> bool:
        """判断是否为图片文件"""
        return Path(filename).suffix.lower() in self.ALLOWED_IMAGE_EXTENSIONS
    
    def is_video(self, filename: str) -> bool:
        """判断是否为视频文件"""
        return Path(filename).suffix.lower() in self.ALLOWED_VIDEO_EXTENSIONS
    
    def is_audio(self, filename: str) -> bool:
        """判断是否为音频文件"""
        return Path(filename).suffix.lower() in self.ALLOWED_AUDIO_EXTENSIONS
    
    def is_document(self, filename: str) -> bool:
        """判断是否为文档文件"""
        return Path(filename).suffix.lower() in self.ALLOWED_DOCUMENT_EXTENSIONS
    
    def get_file_category(self, filename: str) -> str:
        """获取文件类别"""
        if self.is_image(filename):
            return "image"
        elif self.is_video(filename):
            return "video"
        elif self.is_audio(filename):
            return "audio"
        elif self.is_document(filename):
            return "document"
        else:
            return "other"


# 全局配置实例
settings = Settings()

# 确保目录存在
settings.ensure_directories()


