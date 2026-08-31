#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🐰 YumikoToys & NIO-Dash iSH 移动端原生抓包助手 (Alpine Linux on iOS)
---------------------------------------------------------------------
专为在 iPhone iSH 终端中直接运行设计，零第三方重度依赖，极速启动。

【使用步骤】
1. 在 iSH 终端中安装 Python3：
   apk update && apk add python3
2. 运行抓包助手：
   python3 sniff_ish.py
3. 在 iPhone【设置】->【Wi-Fi】-> 点击当前连接的 Wi-Fi 右侧 (i) ->【配置代理】->【手动】：
   - 服务器：127.0.0.1 (或本机 IP)
   - 端口  ：8080
4. 打开蔚来 App ->【爱车】主页 ->【下拉刷新一次】；
5. 终端会自动输出格式化好的 JSON，直接长按复制到 App 设置识别即可！
"""

import sys
import json
import time
import socket
import select
import threading
from urllib.parse import urlparse, parse_qs

PORT = 8080
DEFAULT_CHANGE_URL = "https://gateway-front-external.nio.com/moat/1100367/api/v1/otd/car/ext/general/serviceOrder/getTabOrder?offset=0&limit=200&orderTypes=pe_shaman,pe_shaman_change,service_pe_discharge,battery_flexible_upgrade,nsom_so_maintenance,nsom_so_chauffeur,chauffeur_vehicle_delivery,so_case_accident&hash_type=sha256&lang=zh&region=US&tz_offset=28800&app_ver=6.5.3"
DEFAULT_CHECKIN_URL = "https://gateway-front-external.nio.com/moat/10086//n/c/award/square?event=checkin&collection_id=1843940587332317185"

captured_data = {
    "mode": "url",
    "vehicle_url": "",
    "vehicle_token": "",
    "refresh_token": "",
    "vehicle_id": "",
    "device_id": "",
    "sign": "",
    "timestamp": "",
    "sign_secret": "",
    "sign_algo": "md5_append",
    "change_url": DEFAULT_CHANGE_URL,
    "change_token": "",
    "checkin_url": DEFAULT_CHECKIN_URL,
    "checkin_token": "",
    "widget_url": ""
}

has_captured_rvs = False

def parse_http_headers(raw_data):
    """解析 HTTP 报文中的请求行与请求头"""
    try:
        header_text = raw_data.decode("utf-8", errors="ignore")
        lines = header_text.split("\r\n")
        if not lines or len(lines) < 1:
            return None, {}, ""
        request_line = lines[0]
        headers = {}
        for line in lines[1:]:
            if ":" in line:
                k, v = line.split(":", 1)
                headers[k.strip().lower()] = v.strip()
        return request_line, headers, header_text
    except Exception:
        return None, {}, ""

def process_nio_request(req_line, headers):
    """分析蔚来 HTTP 请求，提取车况与凭证"""
    global has_captured_rvs
    if not req_line:
        return
    
    parts = req_line.split(" ")
    if len(parts) < 2:
        return
    method, path = parts[0], parts[1]
    
    host = headers.get("host", "")
    if "nio.com" not in host and "nio.com" not in path:
        return

    full_url = path if path.startswith("http") else f"https://{host}{path}"
    auth_header = headers.get("authorization", "")
    token = auth_header.replace("Bearer ", "").strip() if auth_header.startswith("Bearer ") else ""

    if token:
        captured_data["vehicle_token"] = token
        captured_data["change_token"] = token
        captured_data["checkin_token"] = token

    parsed = urlparse(full_url)
    query_params = {k: v[0] for k, v in parse_qs(parsed.query).items()}

    if query_params.get("vehicle_id"): captured_data["vehicle_id"] = query_params["vehicle_id"]
    if query_params.get("device_id"): captured_data["device_id"] = query_params["device_id"]
    if query_params.get("sign"): captured_data["sign"] = query_params["sign"]
    if query_params.get("timestamp"): captured_data["timestamp"] = query_params["timestamp"]
    if query_params.get("sign_secret"): captured_data["sign_secret"] = query_params["sign_secret"]

    is_full_rvs = ("icar.nio.com" in host or "icar.nio.com" in path) and "/status" in path
    is_widget = "/widget/info" in path

    if is_full_rvs:
        captured_data["vehicle_url"] = full_url
        captured_data["mode"] = "url"
        has_captured_rvs = True
        print_result_banner()
    elif is_widget:
        captured_data["widget_url"] = full_url
        if not captured_data["vehicle_url"]:
            captured_data["vehicle_url"] = full_url
            captured_data["mode"] = "widget"
        if not has_captured_rvs:
            print("\n[ℹ️] 已截获小组件凭证，请切换至【爱车】主页【下拉刷新一次】以捕获 4 轮胎压...")

def print_result_banner():
    """输出美化结果并写入本地文件"""
    json_str = json.dumps(captured_data, indent=2, ensure_ascii=False)
    with open("nio_config.json", "w", encoding="utf-8") as f:
        f.write(json_str)

    print("\n" + "═"*66)
    print("  🎉 【抓包完成】已成功捕获【爱车主页】全量车况与 4 轮胎压！")
    print("═"*66)
    print(f"  • 模式       : {captured_data['mode']}")
    print(f"  • 车辆 ID    : {captured_data['vehicle_id']}")
    print(f"  • 设备 ID    : {captured_data['device_id']}")
    print(f"  • 访问令牌   : {captured_data['vehicle_token'][:18]}...")
    print("═"*66)
    print("\n👇 请完整复制下方 JSON（已保存至 nio_config.json）：\n")
    print(json_str)
    print("\n" + "═"*66)
    print("👉 打开 YumikoToysRR App 设置 -> 点击【剪贴板读取并识别】即可！\n")

def handle_client(client_socket):
    """处理代理客户端连接"""
    try:
        req_raw = client_socket.recv(4096)
        if not req_raw:
            client_socket.close()
            return
        
        req_line, headers, _ = parse_http_headers(req_raw)
        if not req_line:
            client_socket.close()
            return

        parts = req_line.split(" ")
        method = parts[0]
        target = parts[1]

        if method == "CONNECT":
            # HTTPS 隧道连接
            host_port = target.split(":")
            remote_host = host_port[0]
            remote_port = int(host_port[1]) if len(host_port) > 1 else 443
            
            try:
                remote_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                remote_socket.connect((remote_host, remote_port))
                client_socket.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            except Exception as e:
                client_socket.close()
                return

            sockets = [client_socket, remote_socket]
            while True:
                r, _, _ = select.select(sockets, [], [], 30)
                if not r:
                    break
                if client_socket in r:
                    data = client_socket.recv(8192)
                    if not data:
                        break
                    remote_socket.sendall(data)
                if remote_socket in r:
                    data = remote_socket.recv(8192)
                    if not data:
                        break
                    client_socket.sendall(data)
            
            remote_socket.close()
            client_socket.close()
        else:
            # 普通 HTTP 请求
            process_nio_request(req_line, headers)
            # 转发至目标服务器
            parsed = urlparse(target)
            r_host = parsed.hostname or headers.get("host", "")
            r_port = parsed.port or 80
            
            remote_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote_socket.connect((r_host, r_port))
            remote_socket.sendall(req_raw)
            
            while True:
                resp = remote_socket.recv(8192)
                if not resp:
                    break
                client_socket.sendall(resp)
            
            remote_socket.close()
            client_socket.close()
    except Exception:
        pass
    finally:
        try:
            client_socket.close()
        except Exception:
            pass

def main():
    print("""
  🐰 YumikoToys & NIO-Dash iSH 原生抓包助手
  ───────────────────────────────────────────
  🚀 监听服务已启动 (0.0.0.0:8080)
  👉 请将手机 Wi-Fi 代理设置为：127.0.0.1:8080
  📱 打开蔚来 App ->【爱车】主页 ->【下拉刷新一次】！
    """)

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(("0.0.0.0", PORT))
    except Exception as e:
        print(f"❌ 端口 {PORT} 绑定失败: {e}")
        return
    server.listen(64)

    while True:
        client, addr = server.accept()
        t = threading.Thread(target=handle_client, args=(client,))
        t.daemon = True
        t.start()

if __name__ == "__main__":
    main()
