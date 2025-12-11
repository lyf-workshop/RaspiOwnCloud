#!/bin/bash
#
# 测试阿里云AccessKey是否有效
# 用于诊断InvalidAccessKeyId错误
#

echo "========================================="
echo "阿里云AccessKey测试工具"
echo "========================================="
echo ""

# 加载配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/update_aliyun_dns.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERROR] 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 从配置文件读取环境变量
source "$CONFIG_FILE"

# 检查环境变量是否已设置
if [ -z "$ALIYUN_ACCESS_KEY_ID" ]; then
    echo "[ERROR] ALIYUN_ACCESS_KEY_ID 未设置"
    exit 1
fi

if [ -z "$ALIYUN_ACCESS_KEY_SECRET" ]; then
    echo "[ERROR] ALIYUN_ACCESS_KEY_SECRET 未设置"
    exit 1
fi

if [ -z "$ALIYUN_DOMAIN" ]; then
    echo "[ERROR] ALIYUN_DOMAIN 未设置"
    exit 1
fi

echo "1. 检查配置："
echo "----------------------------------------"
echo "AccessKey ID:     ${ALIYUN_ACCESS_KEY_ID:0:10}..."
echo "AccessKey Secret: ${ALIYUN_ACCESS_KEY_SECRET:0:10}..."
echo "域名:            $ALIYUN_DOMAIN"
echo "子域名:          ${ALIYUN_SUBDOMAIN:-@}"
echo ""

# 检查AccessKey格式
echo "2. 验证AccessKey格式："
echo "----------------------------------------"
if [[ ! "$ALIYUN_ACCESS_KEY_ID" =~ ^LTAI[0-9A-Za-z]{16}$ ]]; then
    echo "[WARN] AccessKey ID 格式可能不正确"
    echo "       正确格式: LTAI + 16个字符（共20个字符）"
    echo "       当前值: $ALIYUN_ACCESS_KEY_ID (${#ALIYUN_ACCESS_KEY_ID}个字符)"
else
    echo "[OK] AccessKey ID 格式正确"
fi

if [ ${#ALIYUN_ACCESS_KEY_SECRET} -lt 20 ]; then
    echo "[WARN] AccessKey Secret 长度可能不正确（通常30+字符）"
    echo "       当前长度: ${#ALIYUN_ACCESS_KEY_SECRET}个字符"
else
    echo "[OK] AccessKey Secret 长度正常"
fi
echo ""

# 测试API调用
echo "3. 测试API调用："
echo "----------------------------------------"
echo "正在调用阿里云DNS API测试AccessKey..."

PYTHON_SCRIPT="$SCRIPT_DIR/update_aliyun_dns.py"
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "[ERROR] Python脚本不存在: $PYTHON_SCRIPT"
    exit 1
fi

# 使用Python测试API
python3 << EOF
import os
import sys
import json
import time
import hashlib
import hmac
import base64
import urllib.parse
import urllib.request

ACCESS_KEY_ID = "$ALIYUN_ACCESS_KEY_ID"
ACCESS_KEY_SECRET = "$ALIYUN_ACCESS_KEY_SECRET"
DOMAIN = "$ALIYUN_DOMAIN"
API_ENDPOINT = 'https://alidns.aliyuncs.com'

def sign_request(params, secret):
    sorted_params = sorted(params.items())
    query_string = urllib.parse.urlencode(sorted_params)
    string_to_sign = 'GET&%2F&' + urllib.parse.quote(query_string, safe='')
    signature = base64.b64encode(
        hmac.new(
            (secret + '&').encode('utf-8'),
            string_to_sign.encode('utf-8'),
            hashlib.sha1
        ).digest()
    ).decode('utf-8')
    return signature

def test_api():
    common_params = {
        'Format': 'JSON',
        'Version': '2015-01-09',
        'AccessKeyId': ACCESS_KEY_ID,
        'SignatureMethod': 'HMAC-SHA1',
        'Timestamp': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'SignatureVersion': '1.0',
        'SignatureNonce': str(int(time.time() * 1000)),
        'Action': 'DescribeDomains',
    }
    
    signature = sign_request(common_params, ACCESS_KEY_SECRET)
    common_params['Signature'] = signature
    
    query_string = urllib.parse.urlencode(common_params)
    url = f'{API_ENDPOINT}?{query_string}'
    
    try:
        response = urllib.request.urlopen(url, timeout=10)
        result_text = response.read().decode('utf-8')
        result = json.loads(result_text)
        
        if 'Domains' in result:
            print("[SUCCESS] AccessKey 有效！")
            print(f"[INFO] 您的账户下有 {len(result['Domains'].get('Domain', []))} 个域名")
            return True
        else:
            print("[ERROR] API返回异常: " + result_text)
            return False
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8')
        print(f"[ERROR] HTTP {e.code}")
        try:
            error_json = json.loads(error_body)
            code = error_json.get('Code', 'Unknown')
            message = error_json.get('Message', 'Unknown error')
            print(f"[ERROR] 错误代码: {code}")
            print(f"[ERROR] 错误消息: {message}")
            
            if code == 'InvalidAccessKeyId':
                print("")
                print("可能的原因：")
                print("  1. AccessKey ID 不正确")
                print("  2. AccessKey 已被删除或禁用")
                print("  3. AccessKey 属于错误的账号")
                print("")
                print("解决方法：")
                print("  1. 登录阿里云控制台检查AccessKey是否有效")
                print("  2. 如果是RAM子账号，确认已授予DNS管理权限")
                print("  3. 重新创建AccessKey并更新配置")
            elif code == 'SignatureDoesNotMatch':
                print("")
                print("可能的原因：")
                print("  1. AccessKey Secret 不正确")
                print("  2. 签名计算错误")
                print("")
                print("解决方法：")
                print("  1. 检查AccessKey Secret是否正确复制")
                print("  2. 确认没有多余的空格或换行符")
        except:
            print(f"[ERROR] 错误响应: {error_body}")
        return False
    except Exception as e:
        print(f"[ERROR] 测试失败: {e}")
        return False

if __name__ == '__main__':
    test_api()
EOF

echo ""
echo "========================================="
echo "测试完成"
echo "========================================="

