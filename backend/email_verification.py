"""
邮箱验证码模块
用于注册时的邮箱验证
"""

import smtplib
import secrets
import string
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
from typing import Optional, Dict
from sqlalchemy.orm import Session
from sqlalchemy import Column, Integer, String, DateTime
from fastapi import HTTPException, status

from config import settings
from models import Base  # 使用统一的Base

class EmailVerificationCode(Base):
    """邮箱验证码模型"""
    __tablename__ = "email_verification_codes"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(100), index=True, nullable=False)
    code = Column(String(10), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)
    used = Column(Integer, default=0)  # 0=未使用, 1=已使用


def generate_verification_code(length: int = 6) -> str:
    """生成验证码"""
    return ''.join(secrets.choice(string.digits) for _ in range(length))


def send_verification_email(email: str, code: str) -> bool:
    """
    发送验证码邮件
    
    Args:
        email: 收件人邮箱
        code: 验证码
    
    Returns:
        是否发送成功
    """
    # 从配置读取SMTP设置
    smtp_host = getattr(settings, 'SMTP_HOST', 'smtp.qq.com')
    smtp_port = getattr(settings, 'SMTP_PORT', 587)
    smtp_user = getattr(settings, 'SMTP_USER', '')
    smtp_password = getattr(settings, 'SMTP_PASSWORD', '')
    smtp_from = getattr(settings, 'SMTP_FROM', smtp_user)
    
    if not smtp_user or not smtp_password:
        print(f"[EMAIL] SMTP未配置，跳过邮件发送")
        # 开发环境：直接打印验证码
        print(f"[EMAIL] 验证码: {code} (开发模式)")
        return True
    
    # 创建邮件
    msg = MIMEMultipart('alternative')
    msg['Subject'] = f'{settings.APP_NAME} 邮箱验证码'
    msg['From'] = smtp_from
    msg['To'] = email
    
    # 邮件内容
    html_content = f"""
    <html>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #9933cc;">{settings.APP_NAME} 邮箱验证</h2>
            <p>您好！</p>
            <p>您正在注册 {settings.APP_NAME} 账户，验证码为：</p>
            <div style="background: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0;">
                <h1 style="color: #9933cc; font-size: 32px; margin: 0; letter-spacing: 5px;">{code}</h1>
            </div>
            <p>验证码有效期为 <strong>10分钟</strong>，请勿泄露给他人。</p>
            <p>如果这不是您的操作，请忽略此邮件。</p>
            <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
            <p style="color: #999; font-size: 12px;">此邮件由系统自动发送，请勿回复。</p>
        </div>
    </body>
    </html>
    """
    
    text_content = f"""
    {settings.APP_NAME} 邮箱验证
    
    您的验证码是: {code}
    
    验证码有效期为10分钟，请勿泄露给他人。
    
    如果这不是您的操作，请忽略此邮件。
    """
    
    # 添加内容
    part1 = MIMEText(text_content, 'plain', 'utf-8')
    part2 = MIMEText(html_content, 'html', 'utf-8')
    msg.attach(part1)
    msg.attach(part2)
    
    # 发送邮件
    try:
        print(f"[EMAIL] 正在连接到 {smtp_host}:{smtp_port}")
        with smtplib.SMTP(smtp_host, smtp_port, timeout=30) as server:
            print(f"[EMAIL] 开始TLS加密")
            server.starttls()
            print(f"[EMAIL] 正在登录: {smtp_user}")
            server.login(smtp_user, smtp_password)
            print(f"[EMAIL] 正在发送邮件到: {email}")
            server.send_message(msg)
            print(f"[EMAIL] 邮件发送成功: {email}")
        
        return True
    except smtplib.SMTPAuthenticationError as auth_error:
        # 认证错误
        error_msg = f"SMTP认证失败: {auth_error}"
        print(f"[EMAIL] {error_msg}")
        if settings.DEBUG:
            print(f"[EMAIL] 开发模式：假设发送成功，验证码: {code}")
            return True
        raise Exception(error_msg)
    except smtplib.SMTPException as smtp_error:
        # SMTP特定错误
        error_msg = f"SMTP错误: {smtp_error}"
        print(f"[EMAIL] {error_msg}")
        if settings.DEBUG:
            print(f"[EMAIL] 开发模式：假设发送成功，验证码: {code}")
            return True
        raise Exception(error_msg)
    except Exception as e:
        # 其他错误（网络错误等）
        error_msg = f"发送邮件失败: {e}"
        print(f"[EMAIL] {error_msg}")
        if settings.DEBUG:
            print(f"[EMAIL] 开发模式：假设发送成功，验证码: {code}")
            return True
        raise Exception(error_msg)


def save_verification_code(db: Session, email: str, code: str, expires_minutes: int = 10) -> EmailVerificationCode:
    """
    保存验证码到数据库
    
    Args:
        db: 数据库会话
        email: 邮箱
        code: 验证码
        expires_minutes: 过期时间（分钟）
    
    Returns:
        EmailVerificationCode对象
    """
    # 删除该邮箱的旧验证码
    db.query(EmailVerificationCode).filter(
        EmailVerificationCode.email == email
    ).delete()
    
    # 创建新验证码
    verification = EmailVerificationCode(
        email=email,
        code=code,
        expires_at=datetime.utcnow() + timedelta(minutes=expires_minutes)
    )
    
    db.add(verification)
    db.commit()
    db.refresh(verification)
    
    return verification


def verify_code(db: Session, email: str, code: str) -> bool:
    """
    验证验证码
    
    Args:
        db: 数据库会话
        email: 邮箱
        code: 验证码
    
    Returns:
        是否验证成功
    """
    verification = db.query(EmailVerificationCode).filter(
        EmailVerificationCode.email == email,
        EmailVerificationCode.code == code,
        EmailVerificationCode.used == 0
    ).first()
    
    if not verification:
        return False
    
    # 检查是否过期
    if datetime.utcnow() > verification.expires_at:
        return False
    
    # 标记为已使用
    verification.used = 1
    db.commit()
    
    return True


def send_verification_code(db: Session, email: str) -> Dict[str, str]:
    """
    发送验证码（完整流程）
    
    Args:
        db: 数据库会话
        email: 邮箱
    
    Returns:
        包含验证码ID的字典（用于测试）
    
    Raises:
        HTTPException: 发送失败时抛出异常
    """
    # 生成验证码
    code = generate_verification_code(6)
    
    # 保存验证码（先保存，即使发送失败也可以重试）
    verification = save_verification_code(db, email, code, expires_minutes=10)
    
    # 发送邮件
    try:
        send_success = send_verification_email(email, code)
        if not send_success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="验证码发送失败，请检查邮箱配置"
            )
    except HTTPException:
        # 重新抛出HTTP异常
        raise
    except Exception as e:
        # 捕获其他异常，转换为HTTP异常
        print(f"[EMAIL] 发送验证码时发生异常: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"验证码发送失败: {str(e)}"
        )
    
    return {
        "message": "验证码已发送到邮箱",
        "email": email,
        "expires_in": 600  # 10分钟
    }

