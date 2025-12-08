"""
用户认证模块
包含JWT token生成、验证、权限检查等
"""

from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status, Query
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from pydantic import BaseModel

from models import User, get_db
from config import settings


# OAuth2密码bearer token
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login", auto_error=False)


class Token(BaseModel):
    """Token响应模型"""
    access_token: str
    token_type: str = "bearer"
    user_info: dict


class TokenData(BaseModel):
    """Token数据模型"""
    username: Optional[str] = None
    user_id: Optional[int] = None


class UserCreate(BaseModel):
    """用户创建模型"""
    username: str
    email: str
    password: str
    full_name: Optional[str] = None


class UserLogin(BaseModel):
    """用户登录模型"""
    username: str
    password: str


class UserResponse(BaseModel):
    """用户响应模型"""
    id: int
    username: str
    email: Optional[str]
    full_name: Optional[str]
    is_admin: bool
    quota: int
    used_space: int
    created_at: datetime
    
    class Config:
        from_attributes = True


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    创建JWT访问令牌
    
    Args:
        data: 要编码的数据
        expires_delta: 过期时间（可选）
    
    Returns:
        JWT token字符串
    """
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    
    return encoded_jwt


def verify_token(token: str) -> TokenData:
    """
    验证JWT令牌
    
    Args:
        token: JWT token字符串
    
    Returns:
        TokenData对象
    
    Raises:
        HTTPException: 令牌无效
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="无法验证凭据",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        username: str = payload.get("sub")
        user_id: int = payload.get("user_id")
        
        if username is None or user_id is None:
            raise credentials_exception
        
        token_data = TokenData(username=username, user_id=user_id)
        return token_data
        
    except JWTError:
        raise credentials_exception


def get_current_user(
    token: Optional[str] = Depends(oauth2_scheme),
    token_param: Optional[str] = Query(None, alias="token"),
    db: Session = Depends(get_db)
) -> User:
    """
    获取当前登录用户（依赖注入）
    支持从 Header 或 URL 参数获取 token
    
    Args:
        token: JWT token (从 Header)
        token_param: JWT token (从 URL 参数)
        db: 数据库会话
    
    Returns:
        User对象
    
    Raises:
        HTTPException: 用户不存在或未激活
    """
    # 优先使用 Header 中的 token，如果没有则使用 URL 参数中的 token
    auth_token = token or token_param
    
    if not auth_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    token_data = verify_token(auth_token)
    
    user = db.query(User).filter(User.id == token_data.user_id).first()
    
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户不存在",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="用户已被禁用"
        )
    
    return user


def get_current_admin_user(current_user: User = Depends(get_current_user)) -> User:
    """
    获取当前管理员用户（权限检查）
    
    Args:
        current_user: 当前用户
    
    Returns:
        User对象
    
    Raises:
        HTTPException: 用户不是管理员
    """
    if not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="需要管理员权限"
        )
    
    return current_user


def authenticate_user(db: Session, username: str, password: str) -> Optional[User]:
    """
    验证用户身份
    
    Args:
        db: 数据库会话
        username: 用户名
        password: 密码
    
    Returns:
        User对象（验证成功）或None（验证失败）
    """
    user = db.query(User).filter(User.username == username).first()
    
    if not user:
        print(f"[AUTH] 用户不存在: {username}")
        return None
    
    if not user.is_active:
        print(f"[AUTH] 用户未激活: {username}")
        return None
    
    # 验证密码
    password_valid = user.verify_password(password)
    print(f"[AUTH] 用户: {username}, 密码验证: {password_valid}, 密码长度: {len(password)}")
    
    if not password_valid:
        print(f"[AUTH] 密码验证失败: {username}")
        return None
    
    print(f"[AUTH] 登录成功: {username}")
    return user


def register_user(db: Session, user_data: UserCreate) -> User:
    """
    注册新用户
    
    Args:
        db: 数据库会话
        user_data: 用户创建数据
    
    Returns:
        新创建的User对象
    
    Raises:
        HTTPException: 用户名或邮箱已存在
    """
    # 检查用户名是否已存在
    existing_user = db.query(User).filter(User.username == user_data.username).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="用户名已存在"
        )
    
    # 检查邮箱是否已存在
    existing_email = db.query(User).filter(User.email == user_data.email).first()
    if existing_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="邮箱已被使用"
        )
    
    # 创建新用户
    new_user = User(
        username=user_data.username,
        email=user_data.email,
        hashed_password=User.hash_password(user_data.password),
        full_name=user_data.full_name,
        is_admin=False,
        quota=settings.DEFAULT_USER_QUOTA
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # 创建用户存储目录
    settings.get_user_storage_path(new_user.id)
    
    return new_user


def update_user_password(db: Session, user: User, old_password: str, new_password: str) -> bool:
    """
    更新用户密码
    
    Args:
        db: 数据库会话
        user: 用户对象
        old_password: 旧密码
        new_password: 新密码
    
    Returns:
        是否成功
    
    Raises:
        HTTPException: 旧密码错误
    """
    if not user.verify_password(old_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="旧密码错误"
        )
    
    user.hashed_password = User.hash_password(new_password)
    db.commit()
    
    return True


def check_user_quota(user: User, file_size: int) -> bool:
    """
    检查用户配额
    
    Args:
        user: 用户对象
        file_size: 文件大小（字节）
    
    Returns:
        是否有足够空间
    """
    return user.has_space_for(file_size)


def update_user_space(db: Session, user: User, size_delta: int):
    """
    更新用户已用空间
    
    Args:
        db: 数据库会话
        user: 用户对象
        size_delta: 空间变化量（正数增加，负数减少）
    """
    user.used_space += size_delta
    if user.used_space < 0:
        user.used_space = 0
    db.commit()


