# 四人爬爬乐（PetPlayground）

这是一个使用 SwiftUI 和 Swift Package Manager 编写的 macOS/iOS 桌宠项目。四个 Q 版角色会以独立的速度、方向和六帧肢体动画，在 macOS Dock 上方平滑爬行。

> 这个仓库目前以**完整源代码包**的形式分发，不是已经打包和签名的 `.app`。请保留整个目录，不要只复制 `.build` 中的可执行文件。

## 最快启动方式

### 环境要求

- Mac，macOS 13 或更高版本
- Xcode 15 或更高版本
- 完整的 `PetPlayground` 项目目录

### 使用终端启动（推荐）

打开“终端”，进入解压后的项目根目录：

```bash
cd /这里替换成实际路径/PetPlayground
swift run
```

例如项目在“下载”目录：

```bash
cd ~/Downloads/PetPlayground
swift run
```

第一次运行需要编译并复制 24 张动画资源，可能要等待十几秒。看到控制台窗口和桌面底部的四个角色后即表示启动成功。

`swift run` 是一个持续运行的命令，不是卡住了。运行期间不要关闭这个终端窗口。

## 使用 Xcode 启动

1. 双击项目根目录的 `Package.swift`，或者执行：

   ```bash
   open Package.swift
   ```

2. 等待 Xcode 完成 Package 解析。
3. 顶部 Scheme 选择 `PetPlayground`。
4. 运行目标选择 **My Mac**。
5. 按 `Command + R`，或点击左上角运行按钮 ▶︎。

不要选择 iPhone/iPad 模拟器来测试桌面悬浮效果。iOS 不允许应用覆盖其他 App，角色只能显示在自己的应用窗口中。

## 如何退出

推荐点击控制面板中的 **退出桌宠**。它会：

- 停止动画定时器
- 关闭所有透明桌宠悬浮层
- 关闭控制面板
- 退出应用进程

控制面板左上角的红色按钮只关闭控制面板，不会关闭桌宠。

如果控制面板已经被关闭，可以按启动方式退出：

- 终端启动：回到运行 `swift run` 的终端，按 `Control + C`。
- Xcode 启动：点击 Xcode 左上角停止按钮 ■。
- 最后的备用方式：在终端执行 `pkill -x PetPlayground`。

## 运行测试

在项目根目录执行：

```bash
swift test
```

当前测试会检查角色独立速度、动作帧率、边缘转向、暂停、重新集合、资源打包、朝向和 60 Hz 更新。

如果想做一次完全干净的编译：

```bash
swift package clean
swift test
swift run
```

## 给 AI Agent 的操作说明

可以直接把下面这段话发给 AI Agent：

```text
这是一个 Swift Package Manager 项目，根目录包含 Package.swift。
请不要只运行或复制 .build 里的二进制文件，也不要移动 Resources 目录。
先在项目根目录运行 `swift test`，确认测试通过；然后运行 `swift run` 启动应用。
`swift run` 是持续运行的 GUI 应用，需要保持进程存活。
macOS 桌宠由一个控制面板和一个点击穿透的透明 NSPanel 组成。
需要退出时，使用控制面板的“退出桌宠”，或向 swift run 发送 Control+C。
```

## 常见问题

### `swift: command not found`

安装完整 Xcode，首次打开并同意许可协议。然后执行：

```bash
xcode-select -p
swift --version
```

如果系统选择的不是正式 Xcode，可以执行：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### 运行了，但没有桌宠

依次检查：

1. 确认运行目标是 **My Mac**。
2. 确认没有同时运行多个 `PetPlayground` 实例。
3. 先退出旧实例，再执行：

   ```bash
   swift package clean
   swift run
   ```

4. 确认没有移动或删除 `Sources/PetPlayground/Resources`。

### 出现两套或更多桌宠

通常是终端和 Xcode 同时启动了应用。点击其中一个控制面板的 **退出桌宠**，关闭全部实例后，只选择一种方式重新启动。

### Xcode 显示旧效果

先点击停止按钮，然后使用 **Product → Clean Build Folder**，再按 `Command + R`。

## 项目结构

```text
PetPlayground/
├── Package.swift                         # Swift Package 配置
├── README.md                             # 本运行说明
├── Sources/PetPlayground/
│   ├── PetPlaygroundApp.swift            # 应用、控制面板、macOS 悬浮层
│   ├── PetEngine.swift                   # 独立运动与动作帧引擎
│   ├── PetModels.swift                   # 角色配置和状态模型
│   ├── PetSprite.swift                   # PNG 帧加载、缓存和方向渲染
│   └── Resources/Characters/Animated/    # 24 张透明运行时动作帧
├── Tests/PetPlaygroundTests/             # 自动化测试
├── DesignAssets/                         # 单人参考图和生成动作表
└── Scripts/                              # 动作帧基线处理工具
```

`DesignAssets` 和根目录的旧版人物 PNG 是素材与生成过程记录；应用运行时实际加载的是 `Sources/PetPlayground/Resources/Characters/Animated/` 中的 24 张透明 PNG。

## 把项目发给朋友

压缩并发送整个 `PetPlayground` 文件夹即可。为了减小体积，可以先清理本机构建缓存，再到项目的上一级目录压缩：

```bash
cd /这里替换成实际路径/PetPlayground
swift package clean
cd ..
ditto -c -k --keepParent PetPlayground PetPlayground-source.zip
```

朋友解压 `PetPlayground-source.zip` 后，按照本文“最快启动方式”运行。`.build` 是本机生成的缓存，可以保留，也可以在压缩前删除；真正不能缺少的是 `Package.swift`、`Sources` 和其中的 `Resources`。
