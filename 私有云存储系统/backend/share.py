"""
文件分享模块
包含分享链接创建、验证、下载等功能
"""

from datetime import datetime, timedelta
from typing import Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel

from models import User, File, Share
from config import settings


class ShareCreate(BaseModel):
    """分享创建模型"""
    file_id: int
    expire_days: Optional[int] = 7  # 过期天数（1-7天）
    need_extract_code: bool = False  # 是否需要提取码
    max_downloads: Optional[int] = None  # 最大下载次数


class ShareResponse(BaseModel):
    """分享响应模型"""
    share_code: str
    extract_code: Optional[str] = None
    share_url: str
    expire_at: Optional[datetime] = None
    max_downloads: Optional[int] = None
    
    class Config:
        from_attributes = True


class ShareAccessRequest(BaseModel):
    """分享访问请求模型"""
    share_code: str
    extract_code: Optional[str] = None


class ShareService:
    """分享服务"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def create_share(
        self,
        user: User,
        share_data: ShareCreate
    ) -> Share:
        """
        创建分享链接
        
        Args:
            user: 用户对象
            share_data: 分享创建数据
        
        Returns:
            Share对象
        
        Raises:
            HTTPException: 文件不存在或参数错误
        """
        # 验证文件
        file = self.db.query(File).filter(
            File.id == share_data.file_id,
            File.owner_id == user.id,
            File.is_deleted == False
        ).first()
        
        if not file:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="文件不存在"
            )
        
        # 验证过期天数
        if share_data.expire_days < 1 or share_data.expire_days > settings.MAX_SHARE_DAYS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"过期天数必须在1-{settings.MAX_SHARE_DAYS}天之间"
            )
        
        # 生成分享码
        share_code = self._generate_unique_share_code()
        
        # 生成提取码（如果需要）
        extract_code = None
        if share_data.need_extract_code:
            extract_code = Share.generate_extract_code()
        
        # 计算过期时间
        expire_at = datetime.utcnow() + timedelta(days=share_data.expire_days)
        
        # 创建分享记录
        share = Share(
            share_code=share_code,
            file_id=file.id,
            owner_id=user.id,
            extract_code=extract_code,
            expire_at=expire_at,
            max_downloads=share_data.max_downloads,
            is_active=True
        )
        
        self.db.add(share)
        self.db.commit()
        self.db.refresh(share)
        
        return share
    
    def _generate_unique_share_code(self) -> str:
        """
        生成唯一分享码
        
        Returns:
            分享码
        """
        max_attempts = 10
        
        for _ in range(max_attempts):
            code = Share.generate_share_code(settings.SHARE_LINK_LENGTH)
            
            # 检查是否已存在
            existing = self.db.query(Share).filter(Share.share_code == code).first()
            
            if not existing:
                return code
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="生成分享码失败，请重试"
        )
    
    def get_share_by_code(self, share_code: str) -> Share:
        """
        通过分享码获取分享
        
        Args:
            share_code: 分享码
        
        Returns:
            Share对象
        
        Raises:
            HTTPException: 分享不存在
        """
        share = self.db.query(Share).filter(Share.share_code == share_code).first()
        
        if not share:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="分享链接不存在"
            )
        
        return share
    
    def verify_share_access(
        self,
        share_code: str,
        extract_code: Optional[str] = None
    ) -> Share:
        """
        验证分享访问权限
        
        Args:
            share_code: 分享码
            extract_code: 提取码（可选）
        
        Returns:
            Share对象
        
        Raises:
            HTTPException: 分享无效或提取码错误
        """
        share = self.get_share_by_code(share_code)
        
        # 检查分享是否有效
        if not share.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="分享已被取消"
            )
        
        # 检查是否过期
        if share.is_expired():
            raise HTTPException(
                status_code=status.HTTP_410_GONE,
                detail="分享已过期"
            )
        
        # 检查下载次数限制
        if share.is_download_limit_reached():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="分享下载次数已达上限"
            )
        
        # 验证提取码
        if share.extract_code:
            if not extract_code or extract_code != share.extract_code:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="提取码错误"
                )
        
        return share
    
    def increment_download_count(self, share: Share):
        """
        增加下载次数
        
        Args:
            share: Share对象
        """
        share.download_count += 1
        self.db.commit()
    
    def cancel_share(self, user: User, share_code: str) -> bool:
        """
        取消分享
        
        Args:
            user: 用户对象
            share_code: 分享码
        
        Returns:
            是否成功
        
        Raises:
            HTTPException: 分享不存在或无权限
        """
        share = self.get_share_by_code(share_code)
        
        # 检查权限
        if share.owner_id != user.id and not user.is_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权取消此分享"
            )
        
        share.is_active = False
        self.db.commit()
        
        return True
    
    def list_user_shares(self, user: User, active_only: bool = True):
        """
        列出用户的分享
        
        Args:
            user: 用户对象
            active_only: 只显示有效分享
        
        Returns:
            Share对象列表
        """
        query = self.db.query(Share).filter(Share.owner_id == user.id)
        
        if active_only:
            query = query.filter(Share.is_active == True)
        
        return query.order_by(Share.created_at.desc()).all()
    
    def get_share_info(self, share_code: str) -> dict:
        """
        获取分享信息（无需提取码）
        
        Args:
            share_code: 分享码
        
        Returns:
            分享基本信息
        """
        share = self.get_share_by_code(share_code)
        
        # 获取文件信息
        file = self.db.query(File).filter(File.id == share.file_id).first()
        
        if not file:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="分享的文件不存在"
            )
        
        # 返回基本信息
        return {
            "filename": file.original_filename or file.filename,
            "size": file.size,
            "category": file.category,
            "need_extract_code": bool(share.extract_code),
            "expire_at": share.expire_at,
            "is_active": share.is_active and share.is_valid(),
            "is_expired": share.is_expired(),
            "downloads_remaining": (
                share.max_downloads - share.download_count
                if share.max_downloads
                else None
            )
        }

