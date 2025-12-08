"""
数据库模型定义
使用SQLAlchemy ORM
"""

from sqlalchemy import create_engine, Column, Integer, String, BigInteger, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime, timedelta
from passlib.context import CryptContext
import secrets
import string

from config import settings

# 密码哈希
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# 创建数据库引擎
engine = create_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in settings.DATABASE_URL else {},
    echo=settings.DEBUG,
    pool_pre_ping=True
)

# 创建会话工厂
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 基类
Base = declarative_base()


def get_db():
    """获取数据库会话（依赖注入用）"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


class User(Base):
    """用户模型"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(100))
    
    # 权限
    is_active = Column(Boolean, default=True)
    is_admin = Column(Boolean, default=False)
    
    # 配额（字节）
    quota = Column(BigInteger, default=settings.DEFAULT_USER_QUOTA)
    used_space = Column(BigInteger, default=0)
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login = Column(DateTime)
    
    # 关系
    files = relationship("File", back_populates="owner", cascade="all, delete-orphan")
    shares = relationship("Share", back_populates="owner", cascade="all, delete-orphan")
    
    def verify_password(self, password: str) -> bool:
        """验证密码"""
        try:
            # 方法1: 直接验证密码（正常情况）
            result = pwd_context.verify(password, self.hashed_password)
            if result:
                return True
            
            # 方法2: 如果密码超过72字节，尝试先SHA256再验证（向后兼容）
            if len(password.encode('utf-8')) > 72:
                import hashlib
                hashed_password = hashlib.sha256(password.encode('utf-8')).hexdigest()
                result = pwd_context.verify(hashed_password, self.hashed_password)
                if result:
                    return True
            
            # 验证失败
            return False
        except Exception as e:
            print(f"密码验证异常: {e}, 密码长度: {len(password.encode('utf-8'))}, 哈希前缀: {self.hashed_password[:20]}")
            import traceback
            traceback.print_exc()
            return False
    
    @staticmethod
    def hash_password(password: str) -> str:
        """哈希密码"""
        # bcrypt 限制密码长度为 72 字节
        # 对于超过 72 字节的密码，先进行 SHA256 哈希
        original_password = password
        if len(password.encode('utf-8')) > 72:
            import hashlib
            # 先对长密码进行 SHA256 哈希，然后再用 bcrypt
            password = hashlib.sha256(password.encode('utf-8')).hexdigest()
        
        try:
            return pwd_context.hash(password)
        except Exception as e:
            print(f"密码哈希错误: {e}, 密码长度: {len(original_password.encode('utf-8'))}")
            raise
    
    def get_available_space(self) -> int:
        """获取可用空间"""
        return self.quota - self.used_space
    
    def has_space_for(self, size: int) -> bool:
        """检查是否有足够空间"""
        return self.get_available_space() >= size


class File(Base):
    """文件模型"""
    __tablename__ = "files"
    
    id = Column(Integer, primary_key=True, index=True)
    filename = Column(String(255), nullable=False)
    original_filename = Column(String(255))
    file_path = Column(String(500), nullable=False)
    
    # 文件信息
    size = Column(BigInteger, nullable=False)
    mime_type = Column(String(100))
    category = Column(String(20))  # image, video, audio, document, other
    md5_hash = Column(String(32), index=True)  # 文件哈希，用于去重
    
    # 元数据
    is_folder = Column(Boolean, default=False)
    parent_id = Column(Integer, ForeignKey("files.id"), nullable=True)
    
    # 所有者
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # 权限
    is_public = Column(Boolean, default=False)
    is_deleted = Column(Boolean, default=False)
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    deleted_at = Column(DateTime)
    
    # 关系
    owner = relationship("User", back_populates="files")
    children = relationship("File", backref="parent", remote_side=[id])
    
    def get_full_path(self) -> str:
        """获取完整路径（包含所有父级）"""
        if self.parent_id is None:
            return "/" + self.filename
        parts = [self.filename]
        current = self.parent
        while current:
            parts.insert(0, current.filename)
            current = current.parent
        return "/" + "/".join(parts)


class Share(Base):
    """分享模型"""
    __tablename__ = "shares"
    
    id = Column(Integer, primary_key=True, index=True)
    share_code = Column(String(20), unique=True, index=True, nullable=False)
    file_id = Column(Integer, ForeignKey("files.id"), nullable=False)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # 分享设置
    extract_code = Column(String(10))  # 提取码（可选）
    expire_at = Column(DateTime)  # 过期时间
    max_downloads = Column(Integer)  # 最大下载次数（可选）
    download_count = Column(Integer, default=0)
    
    # 状态
    is_active = Column(Boolean, default=True)
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # 关系
    owner = relationship("User", back_populates="shares")
    file = relationship("File")
    
    def is_expired(self) -> bool:
        """检查是否过期"""
        if self.expire_at and datetime.utcnow() > self.expire_at:
            return True
        return False
    
    def is_download_limit_reached(self) -> bool:
        """检查是否达到下载次数限制"""
        if self.max_downloads and self.download_count >= self.max_downloads:
            return True
        return False
    
    def is_valid(self) -> bool:
        """检查分享是否有效"""
        return (
            self.is_active
            and not self.is_expired()
            and not self.is_download_limit_reached()
        )
    
    @staticmethod
    def generate_share_code(length: int = 8) -> str:
        """生成分享码"""
        chars = string.ascii_letters + string.digits
        return ''.join(secrets.choice(chars) for _ in range(length))
    
    @staticmethod
    def generate_extract_code(length: int = 4) -> str:
        """生成提取码"""
        chars = string.ascii_lowercase + string.digits
        return ''.join(secrets.choice(chars) for _ in range(length))


class UploadSession(Base):
    """上传会话（断点续传）"""
    __tablename__ = "upload_sessions"
    
    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(String(64), unique=True, index=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # 文件信息
    filename = Column(String(255), nullable=False)
    total_size = Column(BigInteger, nullable=False)
    uploaded_size = Column(BigInteger, default=0)
    chunk_size = Column(Integer, default=settings.CHUNK_SIZE)
    
    # 状态
    is_completed = Column(Boolean, default=False)
    temp_path = Column(String(500))
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def get_progress(self) -> float:
        """获取上传进度（百分比）"""
        if self.total_size == 0:
            return 0.0
        return (self.uploaded_size / self.total_size) * 100


class SyncRecord(Base):
    """同步记录"""
    __tablename__ = "sync_records"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    file_id = Column(Integer, ForeignKey("files.id"), nullable=False)
    
    # 同步信息
    action = Column(String(20))  # created, updated, deleted
    device_id = Column(String(100))
    synced_at = Column(DateTime, default=datetime.utcnow)


def init_db():
    """初始化数据库"""
    # 创建所有表
    Base.metadata.create_all(bind=engine)
    
    # 创建默认管理员账户
    db = SessionLocal()
    try:
        admin = db.query(User).filter(User.username == settings.ADMIN_USERNAME).first()
        if not admin:
            admin = User(
                username=settings.ADMIN_USERNAME,
                email=settings.ADMIN_EMAIL,
                hashed_password=User.hash_password(settings.ADMIN_PASSWORD),
                full_name="Administrator",
                is_admin=True,
                quota=1024 * 1024 * 1024 * 1024  # 1TB
            )
            db.add(admin)
            db.commit()
            print(f"✅ 默认管理员账户已创建: {settings.ADMIN_USERNAME}")
        else:
            print(f"ℹ️  管理员账户已存在: {settings.ADMIN_USERNAME}")
    finally:
        db.close()


def drop_db():
    """删除所有表（仅用于开发）"""
    Base.metadata.drop_all(bind=engine)


if __name__ == "__main__":
    print("初始化数据库...")
    init_db()
    print("✅ 数据库初始化完成")


