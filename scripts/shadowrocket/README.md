# 🚀 Shadowrocket (小火箭) 蔚来车况免电脑一键抓包配置指南

无需电脑，在 iPhone 上通过 **Shadowrocket (小火箭)** 即可全自动抓取包含 **4 轮胎压** 的全量车况与凭证！

---

## 📖 快速配置步骤（只需配置一次）

### 第 1 步：开启 HTTPS 解密 (MITM)
1. 打开 **Shadowrocket** -> 点击底部 **「配置」** 标签页；
2. 点击当前正在使用的配置文件（通常为 `default.conf`）右侧的 **「i」** 图标（或点击进入编辑）；
3. 找到 **「HTTPS 解密」 (MITM)** 并开启开关；
4. 点击 **「生成新的 CA 证书」** -> 点击 **「安装证书到系统」**；
5. 进入 iPhone **「设置」->「通用」->「VPN与设备管理」** 安装描述文件；
6. 进入 iPhone **「设置」->「通用」->「关于本机」->「证书信任设置」**，将刚安装的 Shadowrocket 证书勾选 **完全信任**。

---

### 第 2 步：添加域名与脚本规则
在 Shadowrocket 配置文件中添加以下规则：

#### 1. 主机名 (MITM Hostname)：
在 `[MITM]` 下添加：
```ini
hostname = icar.nio.com, app.nio.com, gateway-front-external.nio.com
```

#### 2. 脚本规则 (Script)：
在 `[Script]` 下添加：
```ini
蔚来看板抓包 = type=http-request,pattern=^https:\/\/(icar|app)\.nio\.com\/(api\/2\/rvs\/vehicle|app\/api\/icar\/v2\/widget\/info),script-path=https://raw.githubusercontent.com/kissggj123/NIO-Dash-iOS/main/scripts/shadowrocket/nio_sniff.js,requires-body=false
```

---

## 🚗 如何抓取

1. 开启 Shadowrocket VPN 开关；
2. 打开手机 **「蔚来 App」**；
3. 点击底部第二个标签页 **「爱车 / 车辆」**，并在页面中 **【下拉刷新一次】**；
4. 屏幕顶部会立即弹出系统通知：
   > 🎉 **蔚来【爱车主页】全量车况捕获成功！**  
   > *已捕获 4 轮胎压 + 动态鉴权凭证*
5. 打开 **YumikoToysRR (iOS)** App 设置 -> 点击 **「📋 剪贴板读取并识别」** 即可！
