/**
 * 🐰 YumikoToys & NIO-Dash 蔚来车况全自动抓包脚本 (Shadowrocket / Surge / Loon 通用)
 *
 * 【双重输出保障】
 * 1. 🌐 Safari 本机看板：抓包后在 Safari 打开 http://boxjs.com 或 http://app.nio.com/dash 即可直接一键复制最新配置 JSON！
 * 2. 📢 系统通知：捕获成功时通过 $notification.post 发送横幅（需在 iOS 设置中允许小火箭通知）；
 */

const DEFAULT_CHANGE_URL = "https://gateway-front-external.nio.com/moat/1100367/api/v1/otd/car/ext/general/serviceOrder/getTabOrder?offset=0&limit=200&orderTypes=pe_shaman,pe_shaman_change,service_pe_discharge,battery_flexible_upgrade,nsom_so_maintenance,nsom_so_chauffeur,chauffeur_vehicle_delivery,so_case_accident&hash_type=sha256&lang=zh&region=US&tz_offset=28800&app_ver=6.5.3";
const DEFAULT_CHECKIN_URL = "https://gateway-front-external.nio.com/moat/10086//n/c/award/square?event=checkin&collection_id=1843940587332317185";

(function main() {
    const url = $request.url;
    const headers = $request.headers || {};

    // 1. 本机 Web 看板：在 Safari 打开 http://boxjs.com 或 http://app.nio.com/dash 或 http://boxjs.net
    if (url.includes("boxjs.com") || url.includes("boxjs.net") || url.includes("/dash") || url.includes("nio.toys") || url.includes("nio.local")) {
        let storedData = {};
        try {
            const raw = $persistentStore.read("nio_sniff_data");
            if (raw) storedData = JSON.parse(raw);
        } catch (e) {
            storedData = {};
        }

        const jsonStr = JSON.stringify(storedData, null, 2);
        const hasData = !!storedData.vehicle_token || !!storedData.vehicle_url;
        const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
    <title>🐰 蔚来看板配置提取器</title>
    <style>
        * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: #0f172a; color: #f8fafc; margin: 0; padding: 20px;
            display: flex; flex-direction: column; align-items: center; min-height: 100vh;
        }
        .card {
            background: #1e293b; border-radius: 20px; padding: 24px; width: 100%; max-width: 480px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.4); border: 1px solid #334155; margin-top: 10px;
        }
        h2 { margin: 0 0 8px 0; font-size: 20px; color: #38bdf8; display: flex; align-items: center; gap: 8px; }
        p { color: #94a3b8; font-size: 13px; margin: 0 0 16px 0; line-height: 1.5; }
        .status-badge {
            display: inline-block; padding: 6px 12px; border-radius: 99px; font-size: 13px; font-weight: 700;
            background: ${hasData ? "rgba(34, 197, 94, 0.2)" : "rgba(234, 179, 8, 0.2)"};
            color: ${hasData ? "#4ade80" : "#facc15"}; margin-bottom: 16px; border: 1px solid ${hasData ? "rgba(34, 197, 94, 0.3)" : "rgba(234, 179, 8, 0.3)"};
        }
        textarea {
            width: 100%; height: 220px; background: #090d16; color: #38bdf8; border: 1px solid #334155;
            border-radius: 12px; padding: 12px; font-family: monospace; font-size: 12px; resize: none; outline: none;
        }
        button {
            width: 100%; background: linear-gradient(135deg, #0284c7, #0ea5e9); color: white; border: none;
            padding: 15px; border-radius: 14px; font-size: 16px; font-weight: 700; margin-top: 16px;
            cursor: pointer; transition: all 0.2s; box-shadow: 0 4px 12px rgba(14, 165, 233, 0.3);
        }
        button:active { transform: scale(0.98); opacity: 0.9; }
        .tip { margin-top: 16px; font-size: 12px; color: #64748b; text-align: center; }
    </style>
</head>
<body>
    <div class="card">
        <h2>🐰 蔚来看板配置提取器</h2>
        <p>免电脑提取车辆 RVS 车况、4 轮胎压与鉴权 Token</p>
        <div class="status-badge">${hasData ? "✅ 已捕获车况凭证" : "⏳ 暂未捕获，请进入蔚来 App 下拉刷新"}</div>
        <textarea id="jsonBox" readonly>${jsonStr}</textarea>
        <button onclick="copyConfig()">📋 一键复制配置到剪贴板</button>
        <div class="tip">复制后回到 YumikoToys App 设置点击「剪贴板读取并识别」即可</div>
    </div>
    <script>
        function copyConfig() {
            const text = document.getElementById('jsonBox').value;
            if (!navigator.clipboard) {
                document.getElementById('jsonBox').select();
                document.execCommand('copy');
            } else {
                navigator.clipboard.writeText(text);
            }
            const btn = document.querySelector('button');
            btn.innerText = '✅ 复制成功！请切换回 YumikoToys App';
            btn.style.background = 'linear-gradient(135deg, #16a34a, #22c55e)';
            setTimeout(() => {
                btn.innerText = '📋 一键复制配置到剪贴板';
                btn.style.background = 'linear-gradient(135deg, #0284c7, #0ea5e9)';
            }, 3000);
        }
    </script>
</body>
</html>`;

        $done({
            response: {
                status: 200,
                headers: { "Content-Type": "text/html;charset=utf-8" },
                body: html
            }
        });
        return;
    }

    // 2. 捕获蔚来 API 请求
    let token = headers["Authorization"] || headers["authorization"] || "";
    if (token.startsWith("Bearer ")) {
        token = token.replace("Bearer ", "").trim();
    }

    const queryParams = parseQueryParams(url);
    const isFullRvs = url.includes("icar.nio.com") && url.includes("/status");
    const isWidget = url.includes("/widget/info");

    let stored = {};
    try {
        const raw = $persistentStore.read("nio_sniff_data");
        if (raw) stored = JSON.parse(raw);
    } catch (e) {
        stored = {};
    }

    if (token) stored.vehicle_token = token;
    if (queryParams["vehicle_id"]) stored.vehicle_id = queryParams["vehicle_id"];
    if (queryParams["device_id"]) stored.device_id = queryParams["device_id"];
    if (queryParams["sign"]) stored.sign = queryParams["sign"];
    if (queryParams["timestamp"]) stored.timestamp = queryParams["timestamp"];
    if (queryParams["sign_secret"]) stored.sign_secret = queryParams["sign_secret"];

    stored.change_url = DEFAULT_CHANGE_URL;
    stored.checkin_url = DEFAULT_CHECKIN_URL;
    if (token) {
        stored.change_token = token;
        stored.checkin_token = token;
    }

    if (isFullRvs) {
        stored.mode = "url";
        stored.vehicle_url = url;
        stored.tyre_ready = true;
    } else if (isWidget) {
        stored.widget_url = url;
        if (!stored.vehicle_url || stored.mode === "widget") {
            stored.vehicle_url = url;
            stored.mode = "widget";
        }
    }

    $persistentStore.write(JSON.stringify(stored), "nio_sniff_data");

    // 尝试发送通知
    try {
        if (isFullRvs && typeof $notification !== "undefined") {
            $notification.post(
                "🎉 蔚来【爱车主页】车况捕获成功！",
                "包含 4 轮胎压与全能凭证",
                "请打开 http://boxjs.com 复制或在 App 点击【剪贴板读取并识别】"
            );
        } else if (isWidget && !stored.tyre_ready && typeof $notification !== "undefined") {
            $notification.post(
                "ℹ️ 已捕获小组件凭证",
                "等待捕获 4 轮胎压...",
                "请在蔚来 App【爱车】主页下拉刷新一次"
            );
        }
    } catch (err) {
        console.log("Notification error: " + err);
    }

    $done({});
})();

function parseQueryParams(urlString) {
    const params = {};
    const qIdx = urlString.indexOf("?");
    if (qIdx === -1) return params;
    const query = urlString.substring(qIdx + 1);
    const pairs = query.split("&");
    for (let i = 0; i < pairs.length; i++) {
        const pair = pairs[i].split("=");
        if (pair.length === 2) {
            params[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1]);
        }
    }
    return params;
}
