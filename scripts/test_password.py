#!/usr/bin/env python3
"""
测试密码哈希和验证
用于诊断登录问题
"""

import sys
import os

# 添加项目路径
sys.path.insert(0, '/opt/raspberrycloud')

from models import User, pwd_context
from passlib.context import CryptContext

def test_password_hashing():
    """测试密码哈希和验证"""
    print("=" * 60)
    print("密码哈希和验证测试")
    print("=" * 60)
    print()
    
    # 测试密码
    test_password = "test123456"
    
    print(f"测试密码: {test_password}")
    print(f"密码长度: {len(test_password)} 字符")
    print(f"密码字节长度: {len(test_password.encode('utf-8'))} 字节")
    print()
    
    # 测试哈希
    print("1. 测试密码哈希...")
    try:
        hashed = User.hash_password(test_password)
        print(f"   ✅ 哈希成功")
        print(f"   哈希值: {hashed[:50]}...")
        print(f"   哈希长度: {len(hashed)} 字符")
    except Exception as e:
        print(f"   ❌ 哈希失败: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    print()
    
    # 测试验证
    print("2. 测试密码验证...")
    try:
        # 使用 User 方法验证
        result1 = pwd_context.verify(test_password, hashed)
        print(f"   pwd_context.verify: {result1}")
        
        # 创建临时用户对象测试
        class TempUser:
            def __init__(self, hashed_password):
                self.hashed_password = hashed_password
            
            def verify_password(self, password):
                try:
                    result = pwd_context.verify(password, self.hashed_password)
                    if result:
                        return True
                    if len(password.encode('utf-8')) > 72:
                        import hashlib
                        hashed_password = hashlib.sha256(password.encode('utf-8')).hexdigest()
                        return pwd_context.verify(hashed_password, self.hashed_password)
                    return False
                except Exception as e:
                    print(f"   验证错误: {e}")
                    return False
        
        temp_user = TempUser(hashed)
        result2 = temp_user.verify_password(test_password)
        print(f"   User.verify_password: {result2}")
        
        if result1 and result2:
            print(f"   ✅ 验证成功")
        else:
            print(f"   ❌ 验证失败")
            return False
            
    except Exception as e:
        print(f"   ❌ 验证失败: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    print()
    
    # 测试错误密码
    print("3. 测试错误密码...")
    wrong_password = "wrongpassword"
    result = pwd_context.verify(wrong_password, hashed)
    if not result:
        print(f"   ✅ 正确拒绝了错误密码")
    else:
        print(f"   ❌ 错误：接受了错误密码")
        return False
    
    print()
    
    # 检查 bcrypt 版本
    print("4. 检查依赖版本...")
    try:
        import bcrypt
        print(f"   bcrypt 版本: {bcrypt.__version__}")
    except:
        print(f"   ❌ 无法获取 bcrypt 版本")
    
    try:
        import passlib
        print(f"   passlib 版本: {passlib.__version__}")
    except:
        print(f"   ❌ 无法获取 passlib 版本")
    
    print()
    print("=" * 60)
    print("测试完成")
    print("=" * 60)
    
    return True

if __name__ == "__main__":
    success = test_password_hashing()
    sys.exit(0 if success else 1)

