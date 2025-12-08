#!/usr/bin/env python3
"""
调试登录问题
检查数据库中的用户和密码
"""

import sys
import os

# 添加项目路径
sys.path.insert(0, '/opt/raspberrycloud')

from models import SessionLocal, User
from config import settings

def debug_user_login():
    """调试用户登录问题"""
    print("=" * 60)
    print("用户登录调试")
    print("=" * 60)
    print()
    
    db = SessionLocal()
    try:
        # 获取所有用户
        users = db.query(User).all()
        print(f"数据库中的用户数量: {len(users)}")
        print()
        
        for user in users:
            print(f"用户: {user.username}")
            print(f"  邮箱: {user.email}")
            print(f"  管理员: {user.is_admin}")
            print(f"  激活: {user.is_active}")
            print(f"  密码哈希: {user.hashed_password[:50]}...")
            print()
            
            # 测试默认密码
            test_passwords = [
                settings.ADMIN_PASSWORD,
                "RaspberryCloud2024!",
                "test123456",
                "password123"
            ]
            
            print("   测试密码验证:")
            for pwd in test_passwords:
                try:
                    result = user.verify_password(pwd)
                    status = "✅" if result else "❌"
                    print(f"     {status} '{pwd}': {result}")
                except Exception as e:
                    print(f"     ❌ '{pwd}': 错误 - {e}")
            
            print()
        
        # 测试创建新密码哈希
        print("测试创建新密码哈希:")
        test_password = "test123456"
        new_hash = User.hash_password(test_password)
        print(f"  密码: {test_password}")
        print(f"  新哈希: {new_hash[:50]}...")
        
        # 验证新哈希
        from models import pwd_context
        verify_result = pwd_context.verify(test_password, new_hash)
        print(f"  验证结果: {verify_result}")
        
    except Exception as e:
        print(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    debug_user_login()

