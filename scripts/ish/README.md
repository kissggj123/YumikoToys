# 🐚 iSH 移动端原生抓包指南 (Alpine Linux on iPhone)

专为在 iPhone 的 **iSH** 终端中运行设计，零第三方重度依赖，极速轻量。

---

## 🛠️ iSH 配置与运行步骤

### 第 1 步：在 iSH 中安装 Python3
打开 iPhone 上的 **iSH** App，输入：
```bash
apk update && apk add python3 curl
```

### 第 2 步：下载并运行抓包助手
```bash
curl -fsSL https://raw.githubusercontent.com/kissggj123/NIO-Dash-iOS/main/scripts/ish/sniff_ish.py -o sniff_ish.py
python3 sniff_ish.py
```

### 第 3 步：配置手机 Wi-Fi 代理
1. 进入 iPhone **「设置」->「无线局域网 (Wi-Fi)」**；
2. 点击当前已连接 Wi-Fi 最右侧的 **蓝色 (i)** 图标；
3. 滑动到底部 -> **「配置代理」** -> 选择 **「手动」**：
   - **服务器**：`127.0.0.1`
   - **端口**  ：`8080`
4. 点击右上角 **「存储」**。

### 第 4 步：抓取车况与胎压
1. 打开 **蔚来 App**；
2. 进入底部第二个标签页 **「爱车 / 车辆」**，并在页面中 **【下拉刷新一次】**；
3. 回到 **iSH** 界面，终端会自动打印出完整的 JSON 配置；
4. 长按全选复制，回到 **YumikoToysRR (iOS)** App 设置 -> 点击 **「📋 剪贴板读取并识别」** 即可！
