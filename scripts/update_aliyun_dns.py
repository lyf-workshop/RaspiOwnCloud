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
    # 创建请求头，模拟浏览器
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    
    # IP查询服务列表（按优先级）
    ip_services = [
        'https://api.ip.sb/ip',           # ip.sb API端点
        'https://ifconfig.me/ip',          # ifconfig.me
        'https://api.ipify.org?format=text',  # ipify
        'https://ipinfo.io/ip',           # ipinfo.io
        'https://icanhazip.com',          # icanhazip
        'https://api.myip.com',           # myip.com (返回JSON)
    ]
    
    for service_url in ip_services:
        try:
            req = urllib.request.Request(service_url, headers=headers)
            response = urllib.request.urlopen(req, timeout=10)
            content = response.read().decode('utf-8').strip()
            
            # 处理JSON响应（如myip.com）
            if content.startswith('{'):
                import json
                data = json.loads(content)
                ip = data.get('ip', '')
            else:
                ip = content
            
            # 验证IP格式（简单验证）
            if ip and '.' in ip and len(ip.split('.')) == 4:
                # 进一步验证每个段都是数字
                parts = ip.split('.')
                if all(part.isdigit() and 0 <= int(part) <= 255 for part in parts):
                    return ip
        except Exception as e:
            print(f"[DEBUG] {service_url} 失败: {e}")
            continue
    
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
        response = urllib.request.urlopen(url, timeout=15)
        result_text = response.read().decode('utf-8')
        result = json.loads(result_text)
        
        # 检查是否有错误
        if 'Code' in result and result['Code'] != 'DomainRecordDuplicate':
            print(f"[ERROR] API返回错误: {result.get('Code', 'Unknown')} - {result.get('Message', 'Unknown error')}")
            print(f"[DEBUG] 完整响应: {result_text}")
            return None
        
        return result
    except urllib.error.HTTPError as e:
        try:
            error_body = e.read().decode('utf-8')
            print(f"[ERROR] API调用失败: HTTP {e.code}")
            print(f"[DEBUG] 错误响应: {error_body}")
            try:
                error_json = json.loads(error_body)
                print(f"[ERROR] 错误代码: {error_json.get('Code', 'Unknown')}")
                print(f"[ERROR] 错误消息: {error_json.get('Message', 'Unknown error')}")
            except:
                pass
        except:
            print(f"[ERROR] API调用失败: HTTP {e.code}")
        return None
    except urllib.error.URLError as e:
        # 网络错误（DNS解析失败、连接超时等）
        error_msg = str(e)
        if 'Temporary failure in name resolution' in error_msg or 'Name or service not known' in error_msg:
            print(f"[WARNING] 网络错误: DNS解析失败，可能是临时网络问题")
            print(f"[INFO] 建议: 检查网络连接，脚本将在下次定时任务时重试")
        elif 'timed out' in error_msg.lower():
            print(f"[WARNING] 网络错误: 连接超时，可能是网络不稳定")
            print(f"[INFO] 建议: 检查网络连接，脚本将在下次定时任务时重试")
        else:
            print(f"[WARNING] 网络错误: {error_msg}")
        return None
    except Exception as e:
        print(f"[ERROR] API调用失败: {e}")
        return None


def get_dns_record():
    """获取DNS记录"""
    params = {
        'DomainName': DOMAIN,
        'Type': 'A',
    }
    
    # 如果SUBDOMAIN不是@，添加RR搜索关键词
    if SUBDOMAIN != '@':
        params['RRKeyWord'] = SUBDOMAIN
    
    result = call_aliyun_api('DescribeDomainRecords', params)
    
    if result and 'DomainRecords' in result and 'Record' in result['DomainRecords']:
        records = result['DomainRecords']['Record']
        # 查找匹配的记录
        for record in records:
            record_rr = record.get('RR', '')
            # @ 在API中返回为空字符串
            # 匹配逻辑：
            # 1. 如果配置的是@，查找RR为空字符串的记录
            # 2. 如果配置的是其他子域名，精确匹配
            if SUBDOMAIN == '@':
                if (record_rr == '' or record_rr == '@') and record.get('Type') == 'A':
                    print(f"[DEBUG] 找到主域名记录: RecordId={record.get('RecordId')}, RR='{record_rr}', Value={record.get('Value')}")
                    return record
            else:
                if record_rr == SUBDOMAIN and record.get('Type') == 'A':
                    print(f"[DEBUG] 找到子域名记录: RecordId={record.get('RecordId')}, RR='{record_rr}', Value={record.get('Value')}")
                    return record
    
    # 如果没有找到，列出所有A记录供调试
    if result and 'DomainRecords' in result and 'Record' in result['DomainRecords']:
        print(f"[DEBUG] 未找到匹配记录，当前域名下的所有A记录：")
        for record in result['DomainRecords']['Record']:
            print(f"  - RR='{record.get('RR', '')}', Type={record.get('Type')}, Value={record.get('Value')}")
    
    return None


def update_dns_record(record_id, new_ip, current_record):
    """更新DNS记录"""
    # 使用当前记录的RR值（保持完全一致）
    # 阿里云API：如果记录的RR是'@'，更新时也必须使用'@'，不能使用空字符串
    current_rr = current_record.get('RR', '')
    
    # 直接使用查询到的RR值，不做任何转换
    # 因为阿里云API要求更新时的RR必须与现有记录的RR完全一致
    rr_value = current_rr
    
    params = {
        'RecordId': record_id,
        'RR': rr_value,
        'Type': 'A',
        'Value': new_ip,
        'TTL': current_record.get('TTL', 600),  # 保持原有TTL或使用默认值
    }
    
    # 调试信息
    print(f"[DEBUG] 更新参数: RecordId={record_id}, RR='{rr_value}', Value={new_ip}, TTL={params['TTL']}")
    
    result = call_aliyun_api('UpdateDomainRecord', params)
    
    if result and 'RecordId' in result:
        return True
    else:
        if result:
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
        print("[ERROR] 无法获取当前公网IP，可能是网络问题")
        print("[INFO] 建议: 检查网络连接，脚本将在下次定时任务时重试")
        sys.exit(1)
    
    print(f"[INFO] 当前公网IP: {current_ip}")
    
    # 获取DNS记录
    print(f"[INFO] 正在查询DNS记录: {SUBDOMAIN}.{DOMAIN}")
    record = get_dns_record()
    
    if not record:
        print(f"[ERROR] 未找到DNS记录: {SUBDOMAIN}.{DOMAIN}")
        print("[INFO] 可能原因:")
        print("  1. 网络问题导致API调用失败")
        print("  2. DNS记录不存在，请先在阿里云控制台创建")
        print("  3. 配置的域名或子域名不正确")
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
    if update_dns_record(record_id, current_ip, record):
        display_name = DOMAIN if SUBDOMAIN == '@' else f"{SUBDOMAIN}.{DOMAIN}"
        print(f"[SUCCESS] DNS记录已更新: {display_name} -> {current_ip}")
    else:
        print(f"[ERROR] DNS记录更新失败")
        sys.exit(1)


if __name__ == '__main__':
    main()



