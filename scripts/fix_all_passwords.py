#!/usr/bin/env python3
"""
修复所有用户密码 - 强制重新哈希
"""

import sys
import os
sys.path.insert(0, '/opt/raspberrycloud')

from models import SessionLocal, User, pwd_context

def fix_all_passwords():
    """修复所有用户的密码"""
    print("=" * 60)
    print("修复所有用户密码")
    print("=" * 60)
    print()
    
    db = SessionLocal()
    try:
        users = db.query(User).all()
        print(f"找到 {len(users)} 个用户\n")
        
        # 为每个用户设置一个已知密码
        fixed_password = "123456"
        
        for user in users:
            print(f"处理用户: {user.username}")
            print(f"  旧哈希: {user.hashed_password[:60]}...")
            
            # 直接使用 pwd_context 重新哈希（确保兼容性）
            new_hash = pwd_context.hash(fixed_password)
            user.hashed_password = new_hash
            user.is_active = True  # 确保账户激活
            
            print(f"  新哈希: {new_hash[:60]}...")
            
            # 立即验证
            verify_result = pwd_context.verify(fixed_password, new_hash)
            print(f"  验证结果: {verify_result}")
            
            if verify_result:
                print(f"  ✅ 成功")
            else:
                print(f"  ❌ 失败")
            print()
        
        db.commit()
        print("=" * 60)
        print("✅ 所有用户密码已重置")
        print("=" * 60)
        print()
        print("登录信息:")
        for user in users:
            print(f"  用户名: {user.username}")
            print(f"  密码: {fixed_password}")
            print()
        
    except Exception as e:
        print(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    fix_all_passwords()




