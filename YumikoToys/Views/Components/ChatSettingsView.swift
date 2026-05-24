//
//  ChatSettingsView.swift
//  YumikoToys
//
//  可爱像素风格 AI 对话设置面板（v4.2 - 万能多厂商适配、动态 BaseURL 及预设切换版）
//

import SwiftUI
import AppKit
import Combine

struct ChatSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ChatSettingsViewModel()
    @State private var selectedTab = 0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // 可爱标题栏
            cuteHeader

            // 可爱 Tab 选择器
            cuteTabSelector

            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case 0:
                        apiConfigTab
                    case 1:
                        searchConfigTab
                    case 2:
                        assistantModeTab
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }

            // 可爱底部栏
            cuteFooter
        }
        .frame(width: 500, height: 680) // 👈 稍微加高了面板，以容纳自定义端点配置区
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                // 可爱背景装饰
                VStack {
                    HStack {
                        Text("🌸")
                            .font(.system(size: 50))
                            .opacity(0.03)
                            .offset(x: -30, y: 30)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("⭐")
                            .font(.system(size: 40))
                            .opacity(0.03)
                            .offset(x: 20, y: -20)
                    }
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "FF6B9D").opacity(0.3), Color(hex: "C44FE2").opacity(0.2), Color(hex: "22D3EE").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color(hex: "FF6B9D").opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(appeared ? 1.0 : 0.95)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appeared)
        .onAppear { appeared = true }
        .onDisappear {
            // 👈 在设置面板消失时，自动进行兜底保存
            viewModel.saveSettings()
        }
    }

    // MARK: - 可爱标题栏

    private var cuteHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Text("⚙️")
                    .font(.system(size: 18))
                Text("AI 对话设置")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            Spacer()

            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 28, height: 28)

                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - 可爱 Tab 选择器

    private var cuteTabSelector: some View {
        HStack(spacing: 8) {
            ForEach([(0, "🖥️", "API 配置"), (1, "🔍", "搜索配置"), (2, "✨", "助手模式")], id: \.0) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab.0 }
                } label: {
                    HStack(spacing: 6) {
                        Text(tab.1)
                            .font(.system(size: 14))
                        Text(tab.2)
                            .font(.system(size: 12, weight: selectedTab == tab.0 ? .semibold : .medium, design: .rounded))
                    }
                    .foregroundStyle(selectedTab == tab.0 ? Color.white : Color.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedTab == tab.0 ?
                                  AnyShapeStyle(LinearGradient(colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")], startPoint: .leading, endPoint: .trailing)) :
                                  AnyShapeStyle(Color.primary.opacity(0.05))
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - 可爱底部栏

    private var cuteFooter: some View {
        HStack {
            if !viewModel.saveStatus.isEmpty {
                HStack(spacing: 4) {
                    Text("✓")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "34C759"))
                    Text(viewModel.saveStatus)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: {
                viewModel.saveSettings()
                dismiss()
            }) {
                Text("完成")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Tab 1: API 配置

    private var currentPresets: [(title: String, url: String)] {
        switch viewModel.currentProvider {
        case .openai:
            return [
                ("官方", "https://api.openai.com/v1"),
                ("ChatAnywhere", "https://api.chatanywhere.tech/v1")
            ]
        case .anthropic:
            return [
                ("官方", "https://api.anthropic.com"),
                ("OneAPI 代理", "https://api.oneapi.run/v1")
            ]
        case .gemini:
            return [
                ("官方 OpenAI 端点", "https://generativelanguage.googleapis.com/v1beta"),
                ("官方 Native 端点", "https://generativelanguage.googleapis.com/v1beta")
            ]
        case .deepseek:
            return [
                ("官方", "https://api.deepseek.com/v1"),
                ("硅基流动镜像", "https://api.siliconflow.cn/v1")
            ]
        case .siliconflow:
            return [("官方", "https://api.siliconflow.cn/v1")]
        case .ollama:
            return [
                ("本地 v1", "http://localhost:11434/v1"),
                ("本地默认", "http://localhost:11434")
            ]
        case .nvidia:
            return [("官方 NIM", "https://integrate.api.nvidia.com/v1")]
        case .glm:
            return [("官方", "https://open.bigmodel.cn/api/paas/v4")]
        }
    }

    private var apiConfigTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 提供商选择 - 重构为 LazyVGrid 2列排版防止宽度溢出
            cuteSectionCard(title: "API 提供商", icon: "🖥️") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(AIProviderType.allCases) { provider in
                        let isSelected = viewModel.currentProvider == provider
                        Button {
                            viewModel.switchProvider(to: provider)
                        } label: {
                            HStack(spacing: 6) {
                                Text(provider.icon)
                                    .font(.system(size: 14))
                                Text(provider.displayName)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected ?
                                          AnyShapeStyle(LinearGradient(colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                                          AnyShapeStyle(Color.primary.opacity(0.04))
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 当前提供商配置
            if viewModel.currentProvider == .glm {
                glmConfigCard
            } else {
                nvidiaConfigCard
            }

            // Token 用量
            cuteSectionCard(title: "Token 用量", icon: "📊") {
                HStack(spacing: 20) {
                    cuteStatItem(emoji: "📤", label: "发送", value: "\(viewModel.settings.estimatedSentTokens.formatted())")
                    cuteStatItem(emoji: "📥", label: "接收", value: "\(viewModel.settings.estimatedReceivedTokens.formatted())")
                    cuteStatItem(emoji: "📈", label: "总计", value: "\(viewModel.settings.totalEstimatedTokens.formatted())", highlight: true)
                }
            }
        }
    }

    // MARK: - Tab 2: 搜索配置

    private var searchConfigTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 联网搜索开关
            cuteSectionCard(title: "联网搜索", icon: "🌐") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("启用联网搜索")
                            .font(.system(size: 13, design: .rounded))
                        Spacer()
                        Toggle("", isOn: $viewModel.enableWebSearch)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    if viewModel.enableWebSearch {
                        HStack {
                            Text("自动判断是否需要联网")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Toggle("", isOn: $viewModel.autoWebSearch)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }
                }
            }

            // Tavily API
            cuteSectionCard(title: "Tavily 搜索 API", icon: "🔍") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tavily 提供高质量的 AI 搜索 API")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text("🔑")
                            .font(.system(size: 12))
                        SecureField("tvly-xxxxxxxxxxxxxxxxxx", text: $viewModel.tavilyAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }

                    if !viewModel.tavilyAPIKey.isEmpty {
                        HStack(spacing: 4) {
                            Text("✅")
                                .font(.system(size: 10))
                            Text("已配置")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Color(hex: "34C759"))
                        }
                    }
                }
            }

            // SearXNG 备用
            cuteSectionCard(title: "SearXNG 备用搜索", icon: "🔄") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("当 Tavily 不可用时自动回退")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text("🔗")
                            .font(.system(size: 12))
                        TextField("https://searx.example.com", text: $viewModel.searchAPIURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                    }

                    HStack(spacing: 8) {
                        Text("🔐")
                            .font(.system(size: 12))
                        SecureField("API Key（可选）", text: $viewModel.searchAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                    }
                }
            }
        }
    }

    // MARK: - Tab 3: 助手模式

    private var assistantModeTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 默认对话模式
            cuteSectionCard(title: "默认对话模式", icon: "💬") {
                Picker("默认模式", selection: $viewModel.defaultChatMode) {
                    ForEach(ChatMode.allCases) { mode in
                        HStack {
                            Text(mode.icon)
                            Text(mode.displayName)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 深度思考
            cuteSectionCard(title: "深度思考", icon: "🧠") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("启用深度思考模式")
                            .font(.system(size: 13, design: .rounded))
                        Spacer()
                        Toggle("", isOn: $viewModel.enableDeepThinking)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }

            // Agent 模式
            cuteSectionCard(title: "Agent 模式", icon: "🤖") {
                HStack {
                    Text("启用 Agent 模式（多步骤推理 + 工具调用）")
                        .font(.system(size: 13, design: .rounded))
                    Spacer()
                    Toggle("", isOn: $viewModel.enableAgentMode)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            // 自定义提示词
            cuteSectionCard(title: "自定义系统提示词", icon: "📝") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("留空则使用默认提示词")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $viewModel.customSystemPrompt)
                        .font(.system(size: 12))
                        .frame(height: 80)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.primary.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - GLM 配置卡片

    private var glmConfigCard: some View {
        cuteSectionCard(title: "智谱 GLM 配置", icon: "🤗") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("🔑")
                        .font(.system(size: 12))
                    SecureField("输入 GLM API Key", text: $viewModel.glmAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }

                HStack(spacing: 8) {
                    Text("📦")
                        .font(.system(size: 12))
                    Picker("模型", selection: $viewModel.glmSelectedModel) {
                        ForEach(GLMModelInfo.availableModels, id: \.id) { model in
                            HStack {
                                Text(model.name)
                                if model.isRecommended {
                                    Text("推荐")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }
                            }
                            .tag(model.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    // MARK: - 通用配置卡片

    private var nvidiaConfigCard: some View {
        cuteSectionCard(title: "\(viewModel.currentProvider.displayName) 配置", icon: "🔗") {
            VStack(alignment: .leading, spacing: 14) {
                
                // 1. 自定义端点 URL 输入区
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Base URL (端点地址)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Text("🌐")
                            .font(.system(size: 12))
                        TextField("例如: https://api.openai.com/v1", text: $viewModel.nvidiaBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
                
                // 2. 一键预设快捷按钮区
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(currentPresets, id: \.url) { preset in
                            PresetEndpointButton(title: preset.title, url: preset.url, currentURL: $viewModel.nvidiaBaseURL)
                        }
                    }
                }

                // 3. API Key 输入区
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(viewModel.currentProvider == .ollama ? "API Key (本地 Ollama 不需要填)" : "API Key")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        Text("🔑")
                            .font(.system(size: 12))
                        SecureField(viewModel.currentProvider == .ollama ? "（可选/本地无需填写）" : "输入上方厂商对应的 API Key", text: $viewModel.nvidiaAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                    }
                }

                // 4. 验证与模型拉取操作区
                HStack {
                    Button(action: { Task { await viewModel.verifyNVIDIAKey() } }) {
                        HStack(spacing: 4) {
                            if viewModel.isNvidiaVerifying {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Text("🔍")
                                    .font(.system(size: 10))
                            }
                            Text(viewModel.isNvidiaVerifying ? "连接端点并获取模型..." : (viewModel.currentProvider == .anthropic ? "同步内置预设模型" : "验证并拉取官方模型"))
                                .font(.system(size: 11, design: .rounded))
                        }
                        .foregroundStyle((viewModel.currentProvider != .ollama && viewModel.nvidiaAPIKey.isEmpty) || viewModel.nvidiaBaseURL.isEmpty ? Color.secondary : Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill((viewModel.currentProvider != .ollama && viewModel.nvidiaAPIKey.isEmpty) || viewModel.nvidiaBaseURL.isEmpty ? Color.primary.opacity(0.1) : Color(hex: "22D3EE"))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(((viewModel.currentProvider != .ollama && viewModel.nvidiaAPIKey.isEmpty) || viewModel.nvidiaBaseURL.isEmpty || viewModel.isNvidiaVerifying))

                    if viewModel.isNvidiaVerified {
                        Text("✅ 同步成功")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color(hex: "34C759"))
                    }
                }

                // 5. 官方模型下拉框
                if viewModel.isNvidiaVerified && !viewModel.nvidiaModels.isEmpty {
                    HStack(spacing: 8) {
                        Text("📦")
                            .font(.system(size: 12))
                        Picker("激活模型 (\(viewModel.nvidiaModels.count) 个可用)", selection: $viewModel.nvidiaSelectedModel) {
                            Text("请选择").tag("")
                            ForEach(viewModel.nvidiaModels) { model in
                                HStack {
                                    Text(model.name)
                                    if model.supportsThinking {
                                        Text("🧠").font(.caption2)
                                    }
                                }
                                .tag(model.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        }
    }

    // MARK: - 辅助组件

    private func cuteSectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
            }

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func cuteStatItem(emoji: String, label: String, value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 16))
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: highlight ? .bold : .medium, design: .monospaced))
                .foregroundStyle(highlight ? Color(hex: "FF6B9D") : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(highlight ? Color(hex: "FF6B9D").opacity(0.08) : Color.primary.opacity(0.02))
        )
    }
}

// MARK: - 快捷预设端点按钮组件

private struct PresetEndpointButton: View {
    let title: String
    let url: String
    @Binding var currentURL: String
    
    @State private var isHovered = false
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.1)) {
                currentURL = url
            }
        } label: {
            Text(title)
                .font(.system(size: 10, weight: currentURL == url ? .bold : .medium, design: .rounded))
                .foregroundStyle(currentURL == url ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(currentURL == url ? Color(hex: "8B5CF6") : (isHovered ? Color.primary.opacity(0.1) : Color.primary.opacity(0.04)))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - ViewModel

@MainActor
final class ChatSettingsViewModel: ObservableObject {
    @Published var settings: APISettings = .default

    // 提供商
    @Published var currentProvider: AIProviderType = .glm

    // GLM
    @Published var glmAPIKey: String = ""
    @Published var glmSelectedModel: String = "glm-4.7"

    // 通用兼容端点（原 NVIDIA）
    @Published var nvidiaAPIKey: String = ""
    @Published var nvidiaBaseURL: String = "" // 👈 新增动态 Base URL 状态
    @Published var nvidiaSelectedModel: String = ""
    @Published var nvidiaModels: [AIModelInfo] = []
    @Published var isNvidiaVerifying: Bool = false
    @Published var isNvidiaVerified: Bool = false

    // 搜索配置
    @Published var tavilyAPIKey: String = ""
    @Published var searchAPIURL: String = ""
    @Published var searchAPIKey: String = ""
    @Published var enableWebSearch: Bool = true
    @Published var autoWebSearch: Bool = true

    // 助手模式
    @Published var defaultChatMode: ChatMode = .petCompanion
    @Published var enableDeepThinking: Bool = false
    @Published var thinkingModel: String = ""
    @Published var enableAgentMode: Bool = false
    @Published var customSystemPrompt: String = ""

    // 保存状态
    @Published var saveStatus: String = ""

    var currentModelName: String {
        switch currentProvider {
        case .glm: return glmSelectedModel
        default: return nvidiaSelectedModel.isEmpty ? "未选择" : nvidiaSelectedModel
        }
    }

    private let container = DependencyContainer.shared

    init() {
        loadSettings()
    }

    func loadSettings() {
        settings = container.apiSettingsService.getSettings()
        currentProvider = settings.currentProvider

        // GLM 配置
        let glmConfig = settings.providerConfigs[.glm]
        glmAPIKey = glmConfig?.apiKey ?? ""
        glmSelectedModel = glmConfig?.model ?? "glm-4.7"

        // 加载当前活跃的非 GLM 提供商配置
        if currentProvider != .glm {
            let activeConfig = settings.providerConfigs[currentProvider]
            nvidiaAPIKey = activeConfig?.apiKey ?? ""
            nvidiaBaseURL = activeConfig?.apiURL ?? currentProvider.defaultBaseURL
            nvidiaSelectedModel = activeConfig?.model ?? ""
            nvidiaModels = activeConfig?.availableModels ?? []
            isNvidiaVerified = !nvidiaAPIKey.isEmpty && !nvidiaModels.isEmpty
        } else {
            // 如果是 GLM，默认把 openai 的配置作为初始备用加载，防止空值
            let backupConfig = settings.providerConfigs[.openai]
            nvidiaAPIKey = backupConfig?.apiKey ?? ""
            nvidiaBaseURL = backupConfig?.apiURL ?? AIProviderType.openai.defaultBaseURL
            nvidiaSelectedModel = backupConfig?.model ?? ""
            nvidiaModels = backupConfig?.availableModels ?? []
            isNvidiaVerified = !nvidiaAPIKey.isEmpty && !nvidiaModels.isEmpty
        }

        let appSettings = container.settingsService.settings
        tavilyAPIKey = appSettings.assistantConfig.tavilyAPIKey
        searchAPIURL = appSettings.assistantConfig.searchAPIURL
        searchAPIKey = appSettings.assistantConfig.searchAPIKey
        enableWebSearch = appSettings.assistantConfig.enableWebSearch
        autoWebSearch = appSettings.assistantConfig.autoWebSearch

        defaultChatMode = appSettings.defaultChatMode
        enableDeepThinking = appSettings.assistantConfig.enableDeepThinking
        thinkingModel = appSettings.assistantConfig.thinkingModel
        enableAgentMode = appSettings.assistantConfig.enableAgentMode
        customSystemPrompt = appSettings.assistantConfig.customSystemPrompt
    }

    func switchProvider(to provider: AIProviderType) {
        // 1. 先保存当前的配置到本地内存 settings (如果是 GLM 或非 GLM)
        var settings = container.apiSettingsService.getSettings()
        let oldProvider = currentProvider
        var configs = settings.providerConfigs
        
        if oldProvider != .glm {
            var config = configs[oldProvider] ?? ProviderConfig(apiURL: oldProvider.defaultBaseURL, model: "")
            config.apiKey = nvidiaAPIKey
            config.apiURL = nvidiaBaseURL
            config.model = nvidiaSelectedModel
            config.availableModels = nvidiaModels
            configs[oldProvider] = config
        } else {
            var config = configs[.glm] ?? .glmDefault
            config.apiKey = glmAPIKey
            config.model = glmSelectedModel
            configs[.glm] = config
        }

        // 2. 切换提供商
        currentProvider = provider
        settings.currentProvider = provider

        // 3. 为新提供商补全默认配置（如果不存在）
        if configs[provider] == nil {
            switch provider {
            case .glm: configs[.glm] = .glmDefault
            case .openai: configs[.openai] = .openaiDefault
            case .anthropic: configs[.anthropic] = .anthropicDefault
            case .gemini: configs[.gemini] = .geminiDefault
            case .deepseek: configs[.deepseek] = .deepseekDefault
            case .siliconflow: configs[.siliconflow] = .siliconflowDefault
            case .ollama: configs[.ollama] = .ollamaDefault
            case .nvidia: configs[.nvidia] = .nvidiaDefault
            }
        }
        
        settings.providerConfigs = configs

        // 4. 保存一下
        container.apiSettingsService.updateSettings(settings)

        // 5. 加载新提供商的配置到绑定的 State 变量中
        if provider == .glm {
            let config = settings.providerConfigs[.glm]
            glmAPIKey = config?.apiKey ?? ""
            glmSelectedModel = config?.model ?? "glm-4.7"
            
            container.glmService.updateConfiguration(
                apiURL: config?.apiURL ?? provider.defaultBaseURL,
                apiKey: glmAPIKey,
                model: glmSelectedModel
            )
        } else {
            let config = settings.providerConfigs[provider]
            nvidiaAPIKey = config?.apiKey ?? ""
            nvidiaBaseURL = config?.apiURL ?? provider.defaultBaseURL
            nvidiaSelectedModel = config?.model ?? ""
            nvidiaModels = config?.availableModels ?? []
            isNvidiaVerified = !nvidiaAPIKey.isEmpty && !nvidiaModels.isEmpty
        }

        saveStatus = "已切换到 \(provider.displayName)"
    }

    func verifyNVIDIAKey() async {
        // Ollama 本地不需要 Key，放宽校验
        if currentProvider != .ollama {
            guard !nvidiaAPIKey.isEmpty, !nvidiaBaseURL.isEmpty else { return }
        } else {
            guard !nvidiaBaseURL.isEmpty else { return }
        }
        
        isNvidiaVerifying = true

        do {
            try Task.checkCancellation()
            
            let universalProvider = UniversalLLMProvider(providerType: currentProvider)
            universalProvider.updateBaseURL(nvidiaBaseURL)
            let models: [AIModelInfo]
            
            if currentProvider == .anthropic {
                // Anthropic 不支持 /models，抛出错误，触发 catch 并加载硬编码预设
                throw AIProviderError.apiError("Anthropic does not support standard /models endpoint.")
            } else {
                models = try await universalProvider.fetchAvailableModels(apiKey: nvidiaAPIKey)
            }

            try Task.checkCancellation()

            nvidiaModels = models
            isNvidiaVerified = true

            if nvidiaSelectedModel.isEmpty, let first = models.first {
                nvidiaSelectedModel = first.id
            }

            var settings = container.apiSettingsService.getSettings()
            var configs = settings.providerConfigs
            var config = configs[currentProvider] ?? ProviderConfig(apiURL: nvidiaBaseURL, model: "")
            config.apiKey = nvidiaAPIKey
            config.apiURL = nvidiaBaseURL
            config.availableModels = models
            config.lastModelFetchDate = Date()
            
            if !models.contains(where: { $0.id == nvidiaSelectedModel }) {
                nvidiaSelectedModel = models.first?.id ?? ""
            }
            
            config.model = nvidiaSelectedModel
            configs[currentProvider] = config
            settings.providerConfigs = configs
            container.apiSettingsService.updateSettings(settings)

            saveStatus = "同步成功，拉取到 \(models.count) 个模型"
        } catch is CancellationError {
            LoggerService.shared.debug("API verification Task was cancelled.")
        } catch {
            // 出错时，自动加载硬编码预设列表以进行降级保护
            let presetModels = getPresetModels(for: currentProvider)
            nvidiaModels = presetModels
            isNvidiaVerified = true
            
            if !presetModels.contains(where: { $0.id == nvidiaSelectedModel }) {
                nvidiaSelectedModel = presetModels.first?.id ?? ""
            }
            
            var settings = container.apiSettingsService.getSettings()
            var configs = settings.providerConfigs
            var config = configs[currentProvider] ?? ProviderConfig(apiURL: nvidiaBaseURL, model: "")
            config.apiKey = nvidiaAPIKey
            config.apiURL = nvidiaBaseURL
            config.availableModels = presetModels
            config.model = nvidiaSelectedModel
            configs[currentProvider] = config
            settings.providerConfigs = configs
            container.apiSettingsService.updateSettings(settings)
            
            saveStatus = "已成功加载 \(currentProvider.displayName) 预设模型"
            LoggerService.shared.warning("API verification fallback: \(error)")
        }

        isNvidiaVerifying = false
    }

    func getPresetModels(for provider: AIProviderType) -> [AIModelInfo] {
        switch provider {
        case .glm:
            return GLMModelInfo.availableModels.map { $0.toAIModelInfo() }
        case .openai:
            return ProviderConfig.openaiDefault.availableModels
        case .anthropic:
            return ProviderConfig.anthropicDefault.availableModels
        case .gemini:
            return ProviderConfig.geminiDefault.availableModels
        case .deepseek:
            return ProviderConfig.deepseekDefault.availableModels
        case .siliconflow:
            return ProviderConfig.siliconflowDefault.availableModels
        case .ollama:
            return ProviderConfig.ollamaDefault.availableModels
        case .nvidia:
            return []
        }
    }

    func saveSettings() {
        var settings = container.apiSettingsService.getSettings()
        settings.currentProvider = currentProvider
        var configs = settings.providerConfigs

        var glmConfig = configs[.glm] ?? .glmDefault
        glmConfig.apiKey = glmAPIKey
        glmConfig.model = glmSelectedModel
        configs[.glm] = glmConfig

        if currentProvider != .glm {
            var config = configs[currentProvider] ?? ProviderConfig(apiURL: nvidiaBaseURL, model: "")
            config.apiKey = nvidiaAPIKey
            config.apiURL = nvidiaBaseURL
            config.model = nvidiaSelectedModel
            config.availableModels = nvidiaModels
            configs[currentProvider] = config
        }

        settings.providerConfigs = configs
        container.apiSettingsService.updateSettings(settings)

        if currentProvider == .glm, let glmConfig = settings.providerConfigs[.glm] {
            container.glmService.updateConfiguration(
                apiURL: glmConfig.apiURL,
                apiKey: glmConfig.apiKey,
                model: glmConfig.model
            )
        }

        var appSettings = container.settingsService.settings
        appSettings.defaultChatMode = defaultChatMode
        appSettings.assistantConfig.enableDeepThinking = enableDeepThinking
        appSettings.assistantConfig.thinkingModel = thinkingModel
        appSettings.assistantConfig.enableWebSearch = enableWebSearch
        appSettings.assistantConfig.autoWebSearch = autoWebSearch
        appSettings.assistantConfig.enableAgentMode = enableAgentMode
        appSettings.assistantConfig.customSystemPrompt = customSystemPrompt
        appSettings.assistantConfig.tavilyAPIKey = tavilyAPIKey
        appSettings.assistantConfig.searchAPIURL = searchAPIURL
        appSettings.assistantConfig.searchAPIKey = searchAPIKey
        container.settingsService.updateSettings(appSettings)

        saveStatus = "设置已保存"
    }
}
