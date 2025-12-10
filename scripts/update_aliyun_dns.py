#!/usr/bin/env python3
"""
阿里云DNS自动更新脚本
用于动态IP（VPN）环境下自动更新DNS记录

使用方法：
1. 配置阿里云AccessKey
2. 设置定时任务（crontab）
"""

import os
import sys
import json
import time
import hashlib
import hmac
import base64
import urllib.parse
import urllib.request
from datetime import datetime

# 配置信息（从环境变量读取）
ACCESS_KEY_ID = os.getenv('ALIYUN_ACCESS_KEY_ID', '')
ACCESS_KEY_SECRET = os.getenv('ALIYUN_ACCESS_KEY_SECRET', '')
DOMAIN = os.getenv('ALIYUN_DOMAIN', '')  # 例如: example.com
SUBDOMAIN = os.getenv('ALIYUN_SUBDOMAIN', '@')  # @ 表示主域名，www 表示www子域名

# 阿里云API端点
API_ENDPOINT = 'https://alidns.aliyuncs.com'


def get_current_ip():
    """获取当前公网IP"""
    try:
        # 方法1: ip.sb
        response = urllib.request.urlopen('https://ip.sb', timeout=10)
        ip = response.read().decode('utf-8').strip()
        if ip and '.' in ip:
            return ip
    except:
        pass
    
    try:
        # 方法2: ifconfig.me
        response = urllib.request.urlopen('https://ifconfig.me', timeout=10)
        ip = response.read().decode('utf-8').strip()
        if ip and '.' in ip:
            return ip
    except:
        pass
    
    try:
        # 方法3: ipinfo.io
        response = urllib.request.urlopen('https://ipinfo.io/ip', timeout=10)
        ip = response.read().decode('utf-8').strip()
        if ip and '.' in ip:
            return ip
    except:
        pass
    
    return None


def sign_request(params, secret):
    """生成阿里云API签名"""
    # 排序参数
    sorted_params = sorted(params.items())
    
    # 构建查询字符串
    query_string = urllib.parse.urlencode(sorted_params)
    
    # 构建签名字符串
    string_to_sign = 'GET&%2F&' + urllib.parse.quote(query_string, safe='')
    
    # 计算签名
    signature = base64.b64encode(
        hmac.new(
            (secret + '&').encode('utf-8'),
            string_to_sign.encode('utf-8'),
            hashlib.sha1
        ).digest()
    ).decode('utf-8')
    
    return signature


def call_aliyun_api(action, params):
    """调用阿里云API"""
    # 公共参数
    common_params = {
        'Format': 'JSON',
        'Version': '2015-01-09',
        'AccessKeyId': ACCESS_KEY_ID,
        'SignatureMethod': 'HMAC-SHA1',
        'Timestamp': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'SignatureVersion': '1.0',
        'SignatureNonce': str(int(time.time() * 1000)),
        'Action': action,
    }
    
    # 合并参数
    all_params = {**common_params, **params}
    
    # 生成签名
    signature = sign_request(all_params, ACCESS_KEY_SECRET)
    all_params['Signature'] = signature
    
    # 构建请求URL
    query_string = urllib.parse.urlencode(all_params)
    url = f'{API_ENDPOINT}?{query_string}'
    
    # 发送请求
    try:
        response = urllib.request.urlopen(url, timeout=10)
        result = json.loads(response.read().decode('utf-8'))
        return result
    except Exception as e:
        print(f"[ERROR] API调用失败: {e}")
        return None


def get_dns_record():
    """获取DNS记录"""
    params = {
        'DomainName': DOMAIN,
        'RRKeyWord': SUBDOMAIN,
        'Type': 'A',
    }
    
    result = call_aliyun_api('DescribeDomainRecords', params)
    
    if result and 'DomainRecords' in result and 'Record' in result['DomainRecords']:
        records = result['DomainRecords']['Record']
        # 查找匹配的记录
        for record in records:
            if record.get('RR') == SUBDOMAIN and record.get('Type') == 'A':
                return record
    
    return None


def update_dns_record(record_id, new_ip):
    """更新DNS记录"""
    params = {
        'RecordId': record_id,
        'RR': SUBDOMAIN,
        'Type': 'A',
        'Value': new_ip,
        'TTL': 600,  # 10分钟
    }
    
    result = call_aliyun_api('UpdateDomainRecord', params)
    
    if result and 'RecordId' in result:
        return True
    else:
        print(f"[ERROR] 更新DNS记录失败: {result}")
        return False


def main():
    """主函数"""
    # 检查配置
    if not ACCESS_KEY_ID or not ACCESS_KEY_SECRET:
        print("[ERROR] 请配置 ALIYUN_ACCESS_KEY_ID 和 ALIYUN_ACCESS_KEY_SECRET")
        sys.exit(1)
    
    if not DOMAIN:
        print("[ERROR] 请配置 ALIYUN_DOMAIN")
        sys.exit(1)
    
    # 获取当前IP
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 正在获取当前公网IP...")
    current_ip = get_current_ip()
    
    if not current_ip:
        print("[ERROR] 无法获取当前公网IP")
        sys.exit(1)
    
    print(f"[INFO] 当前公网IP: {current_ip}")
    
    # 获取DNS记录
    print(f"[INFO] 正在查询DNS记录: {SUBDOMAIN}.{DOMAIN}")
    record = get_dns_record()
    
    if not record:
        print(f"[ERROR] 未找到DNS记录: {SUBDOMAIN}.{DOMAIN}")
        sys.exit(1)
    
    record_id = record['RecordId']
    record_ip = record['Value']
    
    print(f"[INFO] DNS记录当前IP: {record_ip}")
    
    # 比较IP
    if current_ip == record_ip:
        print(f"[INFO] IP未变化，无需更新")
        return
    
    # 更新DNS记录
    print(f"[INFO] IP已变化，正在更新DNS记录...")
    if update_dns_record(record_id, current_ip):
        print(f"[SUCCESS] DNS记录已更新: {SUBDOMAIN}.{DOMAIN} -> {current_ip}")
    else:
        print(f"[ERROR] DNS记录更新失败")
        sys.exit(1)


if __name__ == '__main__':
    main()



