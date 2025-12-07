"""
文件处理模块
包含文件上传、下载、预览、断点续传等功能
"""

import os
import hashlib
import shutil
import mimetypes
from pathlib import Path
from typing import Optional, List, BinaryIO
from datetime import datetime
from fastapi import UploadFile, HTTPException, status
from sqlalchemy.orm import Session
from PIL import Image
import aiofiles

from models import User, File, UploadSession
from config import settings


class FileManager:
    """文件管理器"""
    
    @staticmethod
    def calculate_md5(file_path: Path, chunk_size: int = 8192) -> str:
        """
        计算文件MD5哈希
        
        Args:
            file_path: 文件路径
            chunk_size: 分块大小
        
        Returns:
            MD5哈希字符串
        """
        md5_hash = hashlib.md5()
        
        with open(file_path, "rb") as f:
            while chunk := f.read(chunk_size):
                md5_hash.update(chunk)
        
        return md5_hash.hexdigest()
    
    @staticmethod
    def get_safe_filename(filename: str) -> str:
        """
        获取安全的文件名（移除危险字符）
        
        Args:
            filename: 原始文件名
        
        Returns:
            安全的文件名
        """
        # 移除路径分隔符和特殊字符
        dangerous_chars = ['/', '\\', '..', '\0', '\n', '\r']
        safe_name = filename
        for char in dangerous_chars:
            safe_name = safe_name.replace(char, '_')
        
        return safe_name
    
    @staticmethod
    def get_unique_filename(directory: Path, filename: str) -> str:
        """
        获取唯一文件名（如果文件已存在，添加序号）
        
        Args:
            directory: 目录路径
            filename: 原始文件名
        
        Returns:
            唯一文件名
        """
        base_path = directory / filename
        
        if not base_path.exists():
            return filename
        
        # 分离文件名和扩展名
        name_parts = filename.rsplit('.', 1)
        base_name = name_parts[0]
        extension = f".{name_parts[1]}" if len(name_parts) > 1 else ""
        
        # 添加序号直到找到唯一名称
        counter = 1
        while True:
            new_filename = f"{base_name}_{counter}{extension}"
            if not (directory / new_filename).exists():
                return new_filename
            counter += 1
    
    @staticmethod
    async def save_upload_file(
        upload_file: UploadFile,
        destination: Path,
        chunk_size: int = 1024 * 1024  # 1MB
    ) -> int:
        """
        保存上传的文件
        
        Args:
            upload_file: 上传的文件对象
            destination: 目标路径
            chunk_size: 分块大小
        
        Returns:
            文件大小（字节）
        """
        destination.parent.mkdir(parents=True, exist_ok=True)
        
        total_size = 0
        
        async with aiofiles.open(destination, 'wb') as f:
            while chunk := await upload_file.read(chunk_size):
                await f.write(chunk)
                total_size += len(chunk)
        
        return total_size
    
    @staticmethod
    def create_thumbnail(
        image_path: Path,
        thumbnail_path: Path,
        size: tuple = (200, 200)
    ) -> bool:
        """
        创建缩略图
        
        Args:
            image_path: 原始图片路径
            thumbnail_path: 缩略图路径
            size: 缩略图尺寸
        
        Returns:
            是否成功
        """
        try:
            with Image.open(image_path) as img:
                # 转换RGBA到RGB（如果需要）
                if img.mode in ('RGBA', 'LA', 'P'):
                    background = Image.new('RGB', img.size, (255, 255, 255))
                    if img.mode == 'P':
                        img = img.convert('RGBA')
                    background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
                    img = background
                
                # 创建缩略图
                img.thumbnail(size, Image.Lanczos)
                
                # 保存
                thumbnail_path.parent.mkdir(parents=True, exist_ok=True)
                img.save(thumbnail_path, 'JPEG', quality=85, optimize=True)
                
                return True
                
        except Exception as e:
            print(f"创建缩略图失败: {e}")
            return False
    
    @staticmethod
    def get_file_info(file_path: Path) -> dict:
        """
        获取文件信息
        
        Args:
            file_path: 文件路径
        
        Returns:
            文件信息字典
        """
        stat = file_path.stat()
        mime_type, _ = mimetypes.guess_type(str(file_path))
        
        return {
            'size': stat.st_size,
            'mime_type': mime_type or 'application/octet-stream',
            'created_at': datetime.fromtimestamp(stat.st_ctime),
            'modified_at': datetime.fromtimestamp(stat.st_mtime),
        }
    
    @staticmethod
    def delete_file_safe(file_path: Path) -> bool:
        """
        安全删除文件（移到回收站）
        
        Args:
            file_path: 文件路径
        
        Returns:
            是否成功
        """
        try:
            if file_path.exists():
                file_path.unlink()
                return True
        except Exception as e:
            print(f"删除文件失败: {e}")
        
        return False
    
    @staticmethod
    def calculate_directory_size(directory: Path) -> int:
        """
        计算目录总大小
        
        Args:
            directory: 目录路径
        
        Returns:
            大小（字节）
        """
        total_size = 0
        
        for item in directory.rglob('*'):
            if item.is_file():
                total_size += item.stat().st_size
        
        return total_size


class FileService:
    """文件服务"""
    
    def __init__(self, db: Session):
        self.db = db
        self.file_manager = FileManager()
    
    def create_folder(
        self,
        user: User,
        folder_name: str,
        parent_id: Optional[int] = None
    ) -> File:
        """
        创建文件夹
        
        Args:
            user: 用户对象
            folder_name: 文件夹名称
            parent_id: 父文件夹ID
        
        Returns:
            File对象
        """
        # 获取安全文件名
        safe_name = self.file_manager.get_safe_filename(folder_name)
        
        # 创建物理目录
        user_path = settings.get_user_storage_path(user.id)
        
        if parent_id:
            parent = self.db.query(File).filter(
                File.id == parent_id,
                File.owner_id == user.id,
                File.is_folder == True
            ).first()
            
            if not parent:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="父文件夹不存在"
                )
            
            folder_path = Path(parent.file_path) / safe_name
        else:
            folder_path = user_path / safe_name
        
        # 创建目录
        folder_path.mkdir(parents=True, exist_ok=True)
        
        # 创建数据库记录
        folder = File(
            filename=safe_name,
            original_filename=folder_name,
            file_path=str(folder_path),
            size=0,
            is_folder=True,
            parent_id=parent_id,
            owner_id=user.id,
            category="folder"
        )
        
        self.db.add(folder)
        self.db.commit()
        self.db.refresh(folder)
        
        return folder
    
    async def upload_file(
        self,
        user: User,
        upload_file: UploadFile,
        parent_id: Optional[int] = None
    ) -> File:
        """
        上传文件
        
        Args:
            user: 用户对象
            upload_file: 上传的文件
            parent_id: 父文件夹ID
        
        Returns:
            File对象
        """
        # 检查文件大小
        upload_file.file.seek(0, 2)  # 移到文件末尾
        file_size = upload_file.file.tell()
        upload_file.file.seek(0)  # 重置到开始
        
        if file_size > settings.MAX_FILE_SIZE:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"文件大小超过限制（最大{settings.MAX_FILE_SIZE / 1024 / 1024 / 1024}GB）"
            )
        
        # 检查用户配额
        if not user.has_space_for(file_size):
            raise HTTPException(
                status_code=status.HTTP_507_INSUFFICIENT_STORAGE,
                detail="存储空间不足"
            )
        
        # 获取安全文件名
        safe_name = self.file_manager.get_safe_filename(upload_file.filename)
        
        # 确定保存路径
        user_path = settings.get_user_storage_path(user.id)
        
        if parent_id:
            parent = self.db.query(File).filter(
                File.id == parent_id,
                File.owner_id == user.id,
                File.is_folder == True
            ).first()
            
            if not parent:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="父文件夹不存在"
                )
            
            save_dir = Path(parent.file_path)
        else:
            save_dir = user_path
        
        # 获取唯一文件名
        unique_name = self.file_manager.get_unique_filename(save_dir, safe_name)
        file_path = save_dir / unique_name
        
        # 保存文件
        actual_size = await self.file_manager.save_upload_file(upload_file, file_path)
        
        # 计算MD5
        md5_hash = self.file_manager.calculate_md5(file_path)
        
        # 获取MIME类型
        mime_type, _ = mimetypes.guess_type(safe_name)
        category = settings.get_file_category(safe_name)
        
        # 创建缩略图（如果是图片）
        if category == "image":
            thumbnail_dir = user_path / ".thumbnails"
            thumbnail_path = thumbnail_dir / f"{md5_hash}.jpg"
            self.file_manager.create_thumbnail(file_path, thumbnail_path)
        
        # 创建数据库记录
        file_record = File(
            filename=unique_name,
            original_filename=upload_file.filename,
            file_path=str(file_path),
            size=actual_size,
            mime_type=mime_type or 'application/octet-stream',
            category=category,
            md5_hash=md5_hash,
            is_folder=False,
            parent_id=parent_id,
            owner_id=user.id
        )
        
        self.db.add(file_record)
        
        # 更新用户已用空间
        user.used_space += actual_size
        
        self.db.commit()
        self.db.refresh(file_record)
        
        return file_record
    
    def list_files(
        self,
        user: User,
        parent_id: Optional[int] = None,
        category: Optional[str] = None,
        search: Optional[str] = None
    ) -> List[File]:
        """
        列出文件
        
        Args:
            user: 用户对象
            parent_id: 父文件夹ID
            category: 文件类别过滤
            search: 搜索关键词
        
        Returns:
            File对象列表
        """
        query = self.db.query(File).filter(
            File.owner_id == user.id,
            File.is_deleted == False
        )
        
        if parent_id is not None:
            query = query.filter(File.parent_id == parent_id)
        else:
            query = query.filter(File.parent_id == None)
        
        if category:
            query = query.filter(File.category == category)
        
        if search:
            query = query.filter(File.filename.contains(search))
        
        return query.order_by(File.is_folder.desc(), File.created_at.desc()).all()
    
    def get_file(self, user: User, file_id: int) -> File:
        """
        获取文件
        
        Args:
            user: 用户对象
            file_id: 文件ID
        
        Returns:
            File对象
        """
        file = self.db.query(File).filter(
            File.id == file_id,
            File.owner_id == user.id,
            File.is_deleted == False
        ).first()
        
        if not file:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="文件不存在"
            )
        
        return file
    
    def delete_file(self, user: User, file_id: int) -> bool:
        """
        删除文件（软删除）
        
        Args:
            user: 用户对象
            file_id: 文件ID
        
        Returns:
            是否成功
        """
        file = self.get_file(user, file_id)
        
        # 标记为已删除
        file.is_deleted = True
        file.deleted_at = datetime.utcnow()
        
        # 更新用户已用空间
        user.used_space -= file.size
        if user.used_space < 0:
            user.used_space = 0
        
        self.db.commit()
        
        return True
    
    def rename_file(self, user: User, file_id: int, new_name: str) -> File:
        """
        重命名文件
        
        Args:
            user: 用户对象
            file_id: 文件ID
            new_name: 新文件名
        
        Returns:
            File对象
        """
        file = self.get_file(user, file_id)
        
        # 获取安全文件名
        safe_name = self.file_manager.get_safe_filename(new_name)
        
        # 重命名物理文件
        old_path = Path(file.file_path)
        new_path = old_path.parent / safe_name
        
        if new_path.exists() and new_path != old_path:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="文件名已存在"
            )
        
        old_path.rename(new_path)
        
        # 更新数据库
        file.filename = safe_name
        file.file_path = str(new_path)
        file.updated_at = datetime.utcnow()
        
        self.db.commit()
        self.db.refresh(file)
        
        return file
    
    def move_file(self, user: User, file_id: int, new_parent_id: Optional[int]) -> File:
        """
        移动文件
        
        Args:
            user: 用户对象
            file_id: 文件ID
            new_parent_id: 新父文件夹ID
        
        Returns:
            File对象
        """
        file = self.get_file(user, file_id)
        
        # 验证新父文件夹
        if new_parent_id:
            new_parent = self.db.query(File).filter(
                File.id == new_parent_id,
                File.owner_id == user.id,
                File.is_folder == True
            ).first()
            
            if not new_parent:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="目标文件夹不存在"
                )
            
            new_dir = Path(new_parent.file_path)
        else:
            new_dir = settings.get_user_storage_path(user.id)
        
        # 移动物理文件
        old_path = Path(file.file_path)
        new_path = new_dir / file.filename
        
        if new_path.exists():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="目标位置已存在同名文件"
            )
        
        shutil.move(str(old_path), str(new_path))
        
        # 更新数据库
        file.parent_id = new_parent_id
        file.file_path = str(new_path)
        file.updated_at = datetime.utcnow()
        
        self.db.commit()
        self.db.refresh(file)
        
        return file

