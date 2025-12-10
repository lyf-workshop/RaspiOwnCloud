#!/usr/bin/env python3
"""
直接测试登录功能
"""

import sys
sys.path.insert(0, '/opt/raspberrycloud')

from models import SessionLocal, User
from auth import authenticate_user

def test_login():
    """测试登录"""
    print("=" * 60)
    print("直接测试登录功能")
    print("=" * 60)
    print()
    
    db = SessionLocal()
    try:
        # 获取所有用户
        users = db.query(User).all()
        print(f"数据库中的用户: {len(users)}")
        print()
        
        for user in users:
            print(f"用户: {user.username}")
            print(f"  is_active: {user.is_active}")
            print(f"  is_admin: {user.is_admin}")
            print(f"  密码哈希: {user.hashed_password[:50]}...")
            print()
            
            # 测试几个常见密码
            test_passwords = [
                "RaspberryCloud2024!",
                "123456",
                "test123456",
                "password"
            ]
            
            print("  测试密码验证:")
            for pwd in test_passwords:
                # 使用 authenticate_user 函数测试
                result = authenticate_user(db, user.username, pwd)
                status = "✅" if result else "❌"
                print(f"    {status} '{pwd}': {'成功' if result else '失败'}")
            
            print()
        
    except Exception as e:
        print(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    test_login()






