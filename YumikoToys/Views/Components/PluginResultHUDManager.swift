//
//  PluginResultHUDManager.swift
//  YumikoToys
//
//  插件运行结果独立悬浮卡片管理器（支持超长文本、全格式高亮、一键复制、自动/手动关闭、全链路主题跟随）
//

import SwiftUI
import AppKit
import Combine

/// 插件运行结果 HUD 管理器
@MainActor
final class PluginResultHUDManager: ObservableObject {
    static let shared = PluginResultHUDManager()
    
    @Published var isShowing: Bool = false
    @Published var title: String = ""
    @Published var message: String = ""
    @Published var icon: String = "bolt.fill"
    @Published var isSuccess: Bool = true
    @Published var timestamp: Date = Date()
    
    private var hudPanel: NSPanel?
    private var autoDismissTask: Task<Void, Never>?
    
    private init() {}
    
    /// 展示插件结果悬浮弹窗
    func show(title: String, message: String, icon: String = "bolt.fill", isSuccess: Bool = true, autoDismissSeconds: Double = 12.0) {
        self.title = title
        self.message = message
        self.icon = icon
        self.isSuccess = isSuccess
        self.timestamp = Date()
        self.isShowing = true
        
        createOrUpdatePanel()
        
        // 自动关闭倒计时
        autoDismissTask?.cancel()
        if autoDismissSeconds > 0 {
            autoDismissTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(autoDismissSeconds * 1_000_000_000))
                if !Task.isCancelled {
                    self.dismiss()
                }
            }
        }
    }
    
    /// 关闭弹窗
    func dismiss() {
        autoDismissTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.isShowing = false
        }
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            self.hudPanel?.orderOut(nil)
            self.hudPanel = nil
        }
    }
    
    private func createOrUpdatePanel() {
        if hudPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 390, height: 270),
                styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            panel.hidesOnDeactivate = false
            
            let hostingView = NSHostingView(rootView: PluginResultHUDView(manager: self))
            panel.contentView = hostingView
            self.hudPanel = panel
        }
        
        guard let panel = hudPanel else { return }
        
        // 定位到主屏幕右上角（状态栏下方）
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let panelWidth: CGFloat = 390
            let panelHeight: CGFloat = 280
            let x = screenRect.maxX - panelWidth - 20
            let y = screenRect.maxY - panelHeight - 10
            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }
        
        panel.orderFrontRegardless()
    }
}

// MARK: - 悬浮结果卡片视图 (全链路动态跟随全局主题)

struct PluginResultHUDView: View {
    @ObservedObject var manager: PluginResultHUDManager
    @ObservedObject private var animeThemeService = AnimeThemeService.shared
    
    @State private var isCopied: Bool = false
    @State private var isHovered: Bool = false
    
    private var theme: AboutThemeConfig {
        AboutThemeConfig.current()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(theme.primaryColor.opacity(0.18))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle()
                                .stroke(theme.primaryColor.opacity(0.35), lineWidth: 1)
                        )
                    
                    SafeSFSymbolView(manager.icon, fallback: "bolt.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.primaryColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(manager.title)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        // 状态标签
                        HStack(spacing: 3) {
                            Image(systemName: manager.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.system(size: 9))
                            Text(manager.isSuccess ? "运行完成" : "运行提示")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .foregroundStyle(manager.isSuccess ? Color.green : Color.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill((manager.isSuccess ? Color.green : Color.orange).opacity(0.12)))
                    }
                    
                    Text(formatTime(manager.timestamp))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                // 关闭按钮
                Button {
                    manager.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            Divider()
                .background(Color.primary.opacity(0.08))
            
            // 结果内容展示区（支持超长文本滚动）
            ScrollView(.vertical, showsIndicators: true) {
                Text(manager.message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 150)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.04))
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            // 底部操作栏
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                    Text("YumiScript 实时渲染")
                        .font(.system(size: 10))
                }
                .foregroundStyle(theme.primaryColor.opacity(0.8))
                
                Spacer()
                
                // 一键复制结果按钮（主题渐变）
                Button {
                    copyToClipboard(manager.message)
                    isCopied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        isCopied = false
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                        Text(isCopied ? "已复制到剪贴板" : "复制完整结果")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5.5)
                    .background(theme.linearGradient)
                    .clipShape(Capsule())
                    .shadow(color: theme.primaryColor.opacity(0.35), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            ZStack {
                VisualEffectBlurRepresentable(material: .hudWindow, blendingMode: .behindWindow)
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.88))
                
                // 动态主题渐变流光边框
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        theme.linearGradient,
                        lineWidth: 1.5
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 6)
            .shadow(color: theme.primaryColor.opacity(0.25), radius: 10, x: 0, y: 2)
        )
        .padding(6)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - AppKit 模糊效果支持

struct VisualEffectBlurRepresentable: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
