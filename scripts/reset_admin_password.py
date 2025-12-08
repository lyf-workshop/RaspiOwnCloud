#!/usr/bin/env python3
"""
重置管理员密码脚本
用于修复登录问题
"""

import sys
import os

# 添加项目路径
sys.path.insert(0, '/opt/raspberrycloud')

from models import SessionLocal, User
from config import settings

def reset_admin_password(new_password: str = None):
    """重置管理员密码"""
    if new_password is None:
        new_password = settings.ADMIN_PASSWORD
    
    db = SessionLocal()
    try:
        # 查找管理员账户
        admin = db.query(User).filter(User.username == settings.ADMIN_USERNAME).first()
        
        if not admin:
            print(f"❌ 管理员账户不存在: {settings.ADMIN_USERNAME}")
            print("   正在创建管理员账户...")
            admin = User(
                username=settings.ADMIN_USERNAME,
                email=settings.ADMIN_EMAIL,
                hashed_password=User.hash_password(new_password),
                full_name="Administrator",
                is_admin=True,
                quota=1024 * 1024 * 1024 * 1024  # 1TB
            )
            db.add(admin)
            db.commit()
            print(f"✅ 管理员账户已创建: {settings.ADMIN_USERNAME}")
        else:
            # 重置密码
            print(f"找到管理员账户: {settings.ADMIN_USERNAME}")
            admin.hashed_password = User.hash_password(new_password)
            db.commit()
            print(f"✅ 管理员密码已重置")
        
        # 验证新密码
        if admin.verify_password(new_password):
            print(f"✅ 密码验证成功")
            print(f"\n管理员信息:")
            print(f"  用户名: {admin.username}")
            print(f"  密码: {new_password}")
            print(f"  邮箱: {admin.email}")
        else:
            print(f"❌ 密码验证失败，请检查代码")
            
    except Exception as e:
        print(f"❌ 错误: {e}")
        db.rollback()
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='重置管理员密码')
    parser.add_argument('--password', '-p', type=str, help='新密码（不指定则使用默认密码）')
    
    args = parser.parse_args()
    
    print("=" * 50)
    print("重置管理员密码")
    print("=" * 50)
    print()
    
    reset_admin_password(args.password)

