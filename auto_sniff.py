# -*- coding: utf-8 -*-
"""
auto_sniff.py - 智能蔚来 API 全能抓包与安全增强嗅探插件 (mitmproxy)
1. 完整捕获 RVS 车辆全维状态（含胎压/胎温/电量/车门）、换电足迹订单、每日签到接口；
2. 深度双向探测 Request & Response，智能提取 Token、Refresh Token、Sign Secret、Vehicle ID、Device ID；
3. 严格遵循「完整 RVS URL 优先」策略，彻底避免因模式误判导致的胎压数据丢失；
4. 内置 RVS 动态重签名自校验引擎（支持排序与原始顺序拼串 × 3 种签名算法），实现永不过期；
5. 实时监控 401/403/sign_failed 状态码并提供诊断建议。
"""

from mitmproxy import ctx, http
import json
import hashlib
import os
import subprocess
import sys
import threading
import time
from urllib.parse import parse_qs, urlparse

# 捕获全局数据字典
captured_data = {
    "mode": "url",                     # 默认遵循 URL 优先，确保 tyre_status 胎压不丢失
    "vehicle_url": "",
    "vehicle_token": "",
    "refresh_token": "",
    "token_expire_time": "",
    "vehicle_id": "",
    "device_id": "",
    "sign": "",
    "timestamp": "",
    "sign_secret": os.environ.get("NIO_VEHICLE_SIGN_SECRET", ""),
    "sign_algo": "md5_append",
    "resign_verified": False,
    "change_url": "",
    "change_token": "",
    "checkin_url": "",
    "checkin_token": "",
    "captured_headers": {},
    "curl_command": ""
}

# 默认官方换电与签到 API 模板
DEFAULT_CHANGE_URL = "https://app.nio.com/app/api/service_charge/v1/serviceOrder/getTabOrder?app_ver=6.5.3&lang=zh-CN&region=cn"
DEFAULT_CHECKIN_URL = "https://app.nio.com/app/api/users/checkin?app_ver=6.5.3&lang=zh-CN&region=cn"

has_notified_ready = False
save_lock = threading.Lock()

def md5(text: str) -> str:
    """计算 UTF-8 字符串的 32 位小写 MD5 哈希"""
    return hashlib.md5(text.encode("utf-8")).hexdigest().lower()

def copy_to_clipboard(text: str):
    """复制内容至 macOS 系统剪贴板"""
    try:
        process = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE)
        process.communicate(text.encode("utf-8"))
    except Exception:
        pass

def play_alert_sound():
    """播放系统提示音提醒抓取成功"""
    try:
        subprocess.Popen(["afplay", "/System/Library/Sounds/Glass.aiff"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def verify_and_test_resign():
    """
    RVS 动态重签名自校验引擎：
    在内存中用候选 secret/algo 验证抓包所得 RVS URL 的 sign 签名。
    """
    secret = captured_data.get("sign_secret", "").strip()
    url_str = captured_data.get("vehicle_url", "").strip()
    if not secret or not url_str or "?" not in url_str:
        return

    q_idx = url_str.find("?")
    query = url_str[q_idx + 1:]
    pairs = []
    captured_sign = None

    for pair in query.split("&"):
        if not pair:
            continue
        parts = pair.split("=", 1)
        k = parts[0]
        v = parts[1] if len(parts) > 1 else ""
        if k == "sign":
            captured_sign = v.lower()
        else:
            pairs.append((k, v))

    if not captured_sign or not pairs:
        return

    def canon_sorted(list_pairs):
        return "&".join(sorted([f"{k}={v}" for k, v in list_pairs]))

    def canon_raw(list_pairs):
        return "&".join([f"{k}={v}" for k, v in list_pairs])

    def calc_sign(canonical: str, algo_name: str) -> str:
        if algo_name == "md5_prepend":
            return md5(secret + canonical)
        elif algo_name == "md5_append_key":
            return md5(f"{canonical}&key={secret}")
        else:
            return md5(canonical + secret)

    algos = [captured_data.get("sign_algo", "md5_append"), "md5_append", "md5_prepend", "md5_append_key"]
    seen = set()

    for a in algos:
        if not a or a in seen:
            continue
        seen.add(a)
        if calc_sign(canon_sorted(pairs), a) == captured_sign:
            captured_data["sign_algo"] = a
            captured_data["resign_verified"] = True
            print(f"\n  [✓] 成功通过 RVS URL 重签名自校验 (算法: {a}, 排序拼串)！胎压与永不过期兼得 🚀")
            return
        if calc_sign(canon_raw(pairs), a) == captured_sign:
            captured_data["sign_algo"] = a
            captured_data["resign_verified"] = True
            print(f"\n  [✓] 成功通过 RVS URL 重签名自校验 (算法: {a}, 原始顺序拼串)！胎压与永不过期兼得 🚀")
            return

def search_json_keys(obj, target_keys):
    """递归搜索 JSON 对象中的指定键"""
    results = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            k_lower = str(k).lower()
            for tk in target_keys:
                if tk in k_lower and isinstance(v, (str, int, float)) and v:
                    results[tk] = str(v)
            if isinstance(v, (dict, list)):
                results.update(search_json_keys(v, target_keys))
    elif isinstance(obj, list):
        for item in obj:
            if isinstance(item, (dict, list)):
                results.update(search_json_keys(item, target_keys))
    return results

def persist_results():
    """保存抓包配置到本地文件并同步到剪贴板"""
    global has_notified_ready
is_rvs_status_captured = False

def persist_results(is_final_rvs: bool = False):
    """保存抓包配置到本地文件并同步到剪贴板"""
    global has_notified_ready, is_rvs_status_captured
    if is_final_rvs:
        is_rvs_status_captured = True

    with save_lock:
        token = captured_data["vehicle_token"] or captured_data["change_token"] or captured_data["checkin_token"]
        
        # 若已截获 Token 但未单独进入换电/签到页，自动补全默认配置
        if token:
            if not captured_data["vehicle_token"]:
                captured_data["vehicle_token"] = token
            if not captured_data["change_token"]:
                captured_data["change_token"] = token
            if not captured_data["checkin_token"]:
                captured_data["checkin_token"] = token
            if not captured_data["change_url"]:
                captured_data["change_url"] = DEFAULT_CHANGE_URL
            if not captured_data["checkin_url"]:
                captured_data["checkin_url"] = DEFAULT_CHECKIN_URL

        # 尝试自校验重签名
        verify_and_test_resign()

        # 1. 写入 nio_config.env
        with open("nio_config.env", "w", encoding="utf-8") as f:
            f.write(f'# 蔚来全能 API 抓包增强配置 ({time.strftime("%Y-%m-%d %H:%M:%S")})\n')
            f.write(f'NIO_API_MODE="{captured_data["mode"]}"\n')
            f.write(f'NIO_VEHICLE_API_URL="{captured_data["vehicle_url"]}"\n')
            f.write(f'NIO_VEHICLE_ACCESS_TOKEN="{captured_data["vehicle_token"]}"\n')
            f.write(f'NIO_REFRESH_TOKEN="{captured_data["refresh_token"]}"\n')
            f.write(f'NIO_VEHICLE_ID="{captured_data["vehicle_id"]}"\n')
            f.write(f'NIO_DEVICE_ID="{captured_data["device_id"]}"\n')
            f.write(f'NIO_VEHICLE_SIGN_SECRET="{captured_data["sign_secret"]}"\n')
            f.write(f'NIO_VEHICLE_SIGN_ALGO="{captured_data["sign_algo"]}"\n')
            f.write(f'NIO_CHANGE_API_URL="{captured_data["change_url"]}"\n')
            f.write(f'NIO_CHANGE_ACCESS_TOKEN="{captured_data["change_token"]}"\n')
            f.write(f'NIO_CHECKIN_API_URL="{captured_data["checkin_url"]}"\n')
            f.write(f'NIO_CHECKIN_ACCESS_TOKEN="{captured_data["checkin_token"]}"\n')

        # 2. 写入 JSON 方便各平台直接一键解析导入
        clean_json_str = json.dumps(captured_data, indent=2, ensure_ascii=False)
        with open("nio_sniff_result.json", "w", encoding="utf-8") as f:
            f.write(clean_json_str)

        # 只有真正捕获到【爱车】主页下拉刷新的全量 RVS 状态接口时，才正式触发完成通知
        if is_rvs_status_captured and not has_notified_ready:
            has_notified_ready = True
            copy_to_clipboard(clean_json_str)
            play_alert_sound()
            print("\n" + "═"*70)
            print("  🎉 【抓包完成】已成功捕获【爱车主页】全量车况与 4 轮胎压数据！")
            print("═"*70)
            print(f"  • 抓包模式    : {captured_data['mode']} (包含 tyre_status 4 轮胎压胎温)")
            print(f"  • 车辆状态 URL: {captured_data['vehicle_url'][:65]}...")
            if captured_data["vehicle_id"]:
                print(f"  • Vehicle ID  : {captured_data['vehicle_id']}")
            if captured_data["device_id"]:
                print(f"  • Device ID   : {captured_data['device_id']}")
            if captured_data["sign_secret"]:
                print(f"  • Sign Secret : {captured_data['sign_secret'][:6]}****** (已捕获/配置)")
                if captured_data["resign_verified"]:
                    print(f"  • 动态重签名  : [✓] 已通过自校验 ({captured_data['sign_algo']})，永不过期！")
            if token:
                print(f"  • Bearer Token: {token[:18]}... (已自动同步给车况/换电/签到)")
            if captured_data["refresh_token"]:
                print(f"  • RefreshToken: {captured_data['refresh_token'][:18]}... (长期保活凭证)")
            print("═"*70)
            print("  [✓] 包含 4 轮胎压的全量配置 JSON 已自动复制到系统剪贴板！")
            print("  👉 在 macOS / iOS App 设置 -> 点击「⚡️ 一键识别并填充」即可！")
            print("  💡 按 Ctrl+C 可随时退出抓包助手。")
            print("═"*70 + "\n")

def request(flow: http.HTTPFlow) -> None:
    """监听并捕获客户端发送的 HTTP 请求"""
    host = flow.request.pretty_host
    path = flow.request.path
    full_url = flow.request.url
    headers = flow.request.headers

    # 仅过滤蔚来相关域名
    if "nio.com" not in host:
        return

    # 提取 Bearer Token
    auth_token = headers.get("Authorization", "")
    if auth_token.startswith("Bearer "):
        auth_token = auth_token[7:].strip()

    parsed_url = urlparse(full_url)
    query_params = {k: v[0] for k, v in parse_qs(parsed_url.query).items()}

    # 记录典型标头用于模拟原生请求
    captured_data["captured_headers"] = {
        "User-Agent": headers.get("User-Agent", ""),
        "Host": headers.get("Host", ""),
        "Accept": headers.get("Accept", ""),
        "Accept-Language": headers.get("Accept-Language", "")
    }

    # 1. 识别车辆状态接口（优先完整 RVS /status 接口）
    is_full_rvs_status = (
        ("icar.nio.com" in host and "/status" in path) or
        ("app.nio.com" in host and "/status" in path and "field" in query_params) or
        ("/rvs/vehicle/" in path and "/status" in path)
    )
    is_widget_info = ("app.nio.com" in host and "/widget/info" in path)

    if is_full_rvs_status:
        captured_data["vehicle_url"] = full_url
        captured_data["mode"] = "url"
        if auth_token:
            captured_data["vehicle_token"] = auth_token
        
        # 提取 vehicle_id
        vid = query_params.get("vehicle_id", "")
        if not vid and "/vehicle/" in path:
            parts = path.split("/vehicle/")
            if len(parts) > 1:
                vid = parts[1].split("/")[0]
        if vid:
            captured_data["vehicle_id"] = vid
        
        did = query_params.get("device_id", "")
        if did:
            captured_data["device_id"] = did

        sgn = query_params.get("sign", "")
        if sgn:
            captured_data["sign"] = sgn

        ts = query_params.get("timestamp", "")
        if ts:
            captured_data["timestamp"] = ts

        curl_headers = " ".join([f"-H '{k}: {v}'" for k, v in headers.items() if k.lower() in ["authorization", "user-agent", "accept"]])
        captured_data["curl_command"] = f"curl '{captured_data['vehicle_url']}' {curl_headers}"
        
        persist_results(is_final_rvs=True)

    elif is_widget_info:
        captured_data["widget_url"] = full_url
        if auth_token:
            captured_data["vehicle_token"] = auth_token
        vid = query_params.get("vehicle_id", "")
        if vid: captured_data["vehicle_id"] = vid
        did = query_params.get("device_id", "")
        if did: captured_data["device_id"] = did
        sgn = query_params.get("sign", "")
        if sgn: captured_data["sign"] = sgn
        ts = query_params.get("timestamp", "")
        if ts: captured_data["timestamp"] = ts

        persist_results(is_final_rvs=False)
        if not is_rvs_status_captured:
            print("\n  [ℹ️] 已截获小组件凭证，请继续在蔚来 App【爱车 / 车辆】主页【下拉刷新一次】以抓取 4 轮胎压...")

    # 2. 识别换电/服务订单接口
    elif ("service-order" in path or "service_charge" in path or "serviceOrder" in path or "power_swap" in path or "/order/list" in path):
        captured_data["change_url"] = full_url
        if auth_token:
            captured_data["change_token"] = auth_token
        print(f"\n[+] 成功捕获真实换电/服务订单接口: {full_url[:65]}...")
        persist_results()

    # 3. 识别每日签到接口
    elif ("checkin" in path or "sign_in" in path or "/users/checkin" in path or "community/checkin" in path):
        captured_data["checkin_url"] = full_url
        if auth_token:
            captured_data["checkin_token"] = auth_token
        print(f"\n[+] 成功捕获真实每日签到接口: {full_url[:65]}...")
        persist_results()

    # 4. 其他任何携带有效 Token 的蔚来请求
    elif auth_token:
        if not captured_data["vehicle_token"]:
            captured_data["vehicle_token"] = auth_token
            persist_results()

def response(flow: http.HTTPFlow) -> None:
    """监听服务端 Response，提取 sign_secret、refresh_token 与 Token 续期数据"""
    if not flow.response or not flow.response.content:
        return

    host = flow.request.pretty_host
    if "nio.com" not in host:
        return

    content_type = flow.response.headers.get("Content-Type", "")
    if "application/json" not in content_type and "text/json" not in content_type:
        return

    try:
        json_obj = json.loads(flow.response.get_text())
    except Exception:
        return

    # 深度递归提取潜在的 sign_secret、refresh_token、access_token
    targets = ["sign_secret", "widget_secret", "app_secret", "secret", "refresh_token", "access_token", "token"]
    found = search_json_keys(json_obj, targets)

    updated = False
    if "sign_secret" in found or "widget_secret" in found or "app_secret" in found:
        sec = found.get("sign_secret") or found.get("widget_secret") or found.get("app_secret")
        if sec and len(sec) >= 16 and sec != captured_data.get("sign_secret"):
            captured_data["sign_secret"] = sec
            updated = True
            print(f"\n[★] 从接口响应体中成功捕获 sign_secret 密钥: {sec[:6]}******")

    if "refresh_token" in found:
        rf = found["refresh_token"]
        if rf and rf != captured_data.get("refresh_token"):
            captured_data["refresh_token"] = rf
            updated = True
            print(f"\n[★] 成功捕获 Refresh Token 长期保活凭证: {rf[:18]}...")

    if "access_token" in found or "token" in found:
        new_tk = found.get("access_token") or found.get("token")
        if new_tk and len(new_tk) > 20 and new_tk != captured_data.get("vehicle_token"):
            captured_data["vehicle_token"] = new_tk
            captured_data["change_token"] = new_tk
            captured_data["checkin_token"] = new_tk
            updated = True
            print(f"\n[★] 捕获到最新的 Token 刷新凭证: {new_tk[:18]}...")

    if updated:
        persist_results()