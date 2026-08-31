/**
 * 🐰 YumikoToys & NIO-Dash 蔚来车况全自动抓包脚本 (Shadowrocket / Surge / Loon / Qx 通用)
 *
 * 【功能说明】
 * 1. 自动在 iPhone 本机后台静默捕获蔚来 App 的车况凭证 (Bearer Token / Sign / Timestamp / VehicleID / DeviceID)；
 * 2. 区分并捕获【爱车主页】全量 RVS 状态（含 4 轮胎压）与【桌面小组件】Widget 请求；
 * 3. 自动生成 YumikoToys / YumikoToysRR 识别格式的完整 JSON，并发送系统通知提示。
 *
 * 【Shadowrocket 配置方法】
 * 1. 在 Shadowrocket -> 配置 -> 默认配置 (default.conf) -> 开启 HTTPS 解密 (MITM)，并安装信任证书；
 * 2. 在 [MITM] 中添加主机名：
 *    hostname = icar.nio.com, app.nio.com, gateway-front-external.nio.com
 * 3. 在 [Script] 中添加：
 *    蔚来看板抓包 = type=http-request,pattern=^https:\/\/(icar|app)\.nio\.com\/(api\/2\/rvs\/vehicle|app\/api\/icar\/v2\/widget\/info),script-path=https://raw.githubusercontent.com/kissggj123/NIO-Dash-iOS/main/scripts/shadowrocket/nio_sniff.js,requires-body=false
 */

const DEFAULT_CHANGE_URL = "https://gateway-front-external.nio.com/moat/1100367/api/v1/otd/car/ext/general/serviceOrder/getTabOrder?offset=0&limit=200&orderTypes=pe_shaman,pe_shaman_change,service_pe_discharge,battery_flexible_upgrade,nsom_so_maintenance,nsom_so_chauffeur,chauffeur_vehicle_delivery,so_case_accident&hash_type=sha256&lang=zh&region=US&tz_offset=28800&app_ver=6.5.3";
const DEFAULT_CHECKIN_URL = "https://gateway-front-external.nio.com/moat/10086//n/c/award/square?event=checkin&collection_id=1843940587332317185";

(function main() {
    const url = $request.url;
    const headers = $request.headers || {};
    
    // 提取 Authorization Bearer Token
    let token = headers["Authorization"] || headers["authorization"] || "";
    if (token.startsWith("Bearer ")) {
        token = token.replace("Bearer ", "").trim();
    }

    // 从 URL 中解析 query 参数
    const queryParams = parseQueryParams(url);
    const isFullRvs = url.includes("icar.nio.com") && url.includes("/status");
    const isWidget = url.includes("/widget/info");

    // 读取持久化缓存，增量合并已捕获的数据
    let stored = {};
    try {
        const raw = $persistentStore.read("nio_sniff_data");
        if (raw) stored = JSON.parse(raw);
    } catch (e) {
        stored = {};
    }

    // 提取关键字段
    if (token) stored.vehicle_token = token;
    if (queryParams["vehicle_id"]) stored.vehicle_id = queryParams["vehicle_id"];
    if (queryParams["device_id"]) stored.device_id = queryParams["device_id"];
    if (queryParams["sign"]) stored.sign = queryParams["sign"];
    if (queryParams["timestamp"]) stored.timestamp = queryParams["timestamp"];
    if (queryParams["sign_secret"]) stored.sign_secret = queryParams["sign_secret"];

    // 默认补充换电与签到网关
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

    // 保存最新状态
    $persistentStore.write(JSON.stringify(stored), "nio_sniff_data");

    // 当捕获到全量 RVS 状态（含胎压）或有效凭证时，发送系统横幅通知
    if (isFullRvs) {
        const jsonOutput = JSON.stringify(stored, null, 2);
        $notification.post(
            "🎉 蔚来【爱车主页】全量车况捕获成功！",
            "已捕获 4 轮胎压 + 动态鉴权凭证",
            "请打开 YumikoToys 并在设置中点击【剪贴板读取并识别】！\n\n" + jsonOutput
        );
    } else if (isWidget && !stored.tyre_ready) {
        $notification.post(
            "ℹ️ 已捕获小组件凭证",
            "等待捕获 4 轮胎压数据...",
            "请切换至蔚来 App【爱车】主页并下拉刷新一次，以捕获胎压数据！"
        );
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
