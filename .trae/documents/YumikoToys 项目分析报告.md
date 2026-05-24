# YumikoToys 修复计划

## 问题分析

### 1. 首次启动布局错位问题
- 原因：数据加载和UI创建的时序问题，可能导致模块布局异常
- 表现：首次启动时界面元素排列混乱或重叠

### 2. 小组件背景效果问题
- 原因：当前使用的是半透明灰色背景，不是毛玻璃效果
- 表现：小组件背后显示丑的灰黑色背景，与整体UI风格不协调

## 修复方案

### 1. 修复首次启动布局错位

**修改点：** `AppDelegate.swift` 中的 `MainViewController` 类

**具体措施：**
- 在 `loadView()` 方法中，确保在设置模块后添加强制布局刷新
- 在 `viewDidLoad()` 方法中增强布局检查逻辑
- 优化 `setupModules()` 方法，确保模块添加顺序和约束设置正确
- 添加延迟初始化机制，确保数据完全加载后再构建UI

### 2. 实现半透明毛玻璃背景效果

**修改点：** `AppDelegate.swift` 中的 `ModernCardView` 类

**具体措施：**
- 重写 `ModernCardView` 类，使用 `NSVisualEffectView` 作为底层视图
- 配置视觉效果视图属性：
  - `material` 设置为 `.sidebar` 或 `.contentBackground`
  - `blendingMode` 设置为 `.withinWindow`
  - `state` 设置为 `.active`
- 保持圆角和边框效果
- 确保子视图正确添加到视觉效果视图上

## 技术实现细节

### 1. 布局修复实现

```swift
// 在 setupModules() 方法末尾添加
func setupModules() {
    // 现有代码...
    
    // 添加模块后强制刷新布局
    mainStackView.needsLayout = true
    mainStackView.layoutSubtreeIfNeeded()
    
    // 确保滚动视图内容大小正确
    scrollView.contentView.needsLayout = true
    scrollView.contentView.layoutSubtreeIfNeeded()
}

// 在 viewDidLoad() 方法中增强检查
override func viewDidLoad() {
    super.viewDidLoad()
    
    // 现有代码...
    
    // 强制布局刷新
    DispatchQueue.main.async {
        self.view.needsLayout = true
        self.view.layoutSubtreeIfNeeded()
    }
}
```

### 2. 毛玻璃背景实现

```swift
class ModernCardView: NSView {
    private let visualEffectView: NSVisualEffectView
    
    init() {
        // 创建视觉效果视图
        visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.cornerCurve = .continuous
        visualEffectView.layer?.masksToBounds = true
        
        super.init(frame: .zero)
        
        // 设置自身属性
        self.wantsLayer = true
        self.layer?.cornerRadius = 12
        self.layer?.cornerCurve = .continuous
        self.layer?.masksToBounds = true
        
        // 添加视觉效果视图作为子视图
        addSubview(visualEffectView)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 重写 addSubview 方法，确保子视图添加到视觉效果视图上
    override func addSubview(_ view: NSView) {
        visualEffectView.addSubview(view)
    }
}
```

## 预期效果

### 1. 布局修复
- 首次启动时界面布局正确，无错位现象
- 模块排列整齐，约束生效
- 滚动视图内容大小合适

### 2. 背景效果
- 小组件显示半透明毛玻璃效果
- 与系统UI风格一致
- 背景能模糊显示下方内容
- 保持圆角和边框的美观性

## 测试计划

1. **布局测试**
   - 首次启动应用，检查布局是否正确
   - 多次重启应用，确保布局稳定
   - 测试不同模块显示/隐藏组合下的布局

2. **背景效果测试**
   - 检查所有小组件的背景效果
   - 测试不同系统背景下的显示效果
   - 验证暗黑模式下的背景表现

3. **功能测试**
   - 确保所有原有功能正常工作
   - 测试模块交互和点击事件
   - 验证滚动和缩放功能

## 风险评估

- **低风险**：修改仅涉及UI布局和视觉效果，不影响核心功能
- **兼容性**：使用系统原生API，支持所有现代macOS版本
- **性能**：毛玻璃效果可能轻微增加GPU使用率，但在现代设备上可忽略不计