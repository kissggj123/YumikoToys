# 🚀 Shadowrocket (小火箭) 蔚来车况一键模块配置指南

无需电脑，在 iPhone 上使用 Shadowrocket 模块全自动捕获包含 **4 轮胎压** 的全量车况与凭证！

---

## ⚡️ 方式一：一键模块导入（最简单）

### 1. 复制模块链接
```text
https://raw.githubusercontent.com/kissggj123/NIO-Dash-iOS/main/scripts/shadowrocket/nio_sniff.sgmodule
```

### 2. 导入到小火箭
1. 打开 **Shadowrocket** -> 点击底部 **「配置」**；
2. 滑动到下方找到 **「模块」**（或在右上角点击 **+** 号）；
3. 在 URL 输入框中粘贴上面的链接，点击 **保存 / 下载**；
4. 勾选启用该模块！

---

## 🔒 证书准备（只需首次配置一次）
1. 在 Shadowrocket 中点击 **「配置」** -> 当前配置文件 -> **「HTTPS 解密」**；
2. 生成并安装 CA 证书到系统；
3. 进入 iPhone **「设置」->「通用」->「关于本机」->「证书信任设置」**，勾选**完全信任**该证书。

---

## 🚗 如何抓取车况与 4 轮胎压

1. 开启 Shadowrocket 连接；
2. 打开手机 **蔚来 App** -> 切换到底部 **「爱车 / 车辆」** 页面 -> **【下拉刷新一次】**；
3. 打开 Safari 浏览器访问：
   ```text
   http://boxjs.com
   或
   http://app.nio.com/dash
   ```
4. 点击页面上的 **「📋 一键复制配置到剪贴板」**；
5. 打开 **YumikoToys (iOS)** 设置 -> 点击 **「📋 剪贴板读取并识别」** 即可！
