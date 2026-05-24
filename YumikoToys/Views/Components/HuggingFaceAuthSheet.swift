//
//  HuggingFaceAuthSheet.swift
//  YumikoToys
//
//  HuggingFace Token 认证弹窗
//

import SwiftUI

struct HuggingFaceAuthSheet: View {
    @ObservedObject var authService: HuggingFaceAuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var tokenInput = ""
    @State private var isValidating = false
    @State private var validationError: String?
    @State private var showToken = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            headerView
            
            // 说明文字
            instructionView
            
            // Token 输入框
            tokenInputView
            
            // 错误提示
            if let error = validationError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            // 按钮
            actionButtons
            
            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color(hex: "FF9500"))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("HuggingFace 认证")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("使用 Access Token 登录")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var instructionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1. 访问 HuggingFace 个人设置页面")
                .font(.system(size: 12))
            
            Text("2. 点击「New token」创建 Access Token")
                .font(.system(size: 12))
            
            Text("3. 复制 Token 并粘贴到下方")
                .font(.system(size: 12))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.05))
        )
    }
    
    private var tokenInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Access Token")
                    .font(.system(size: 12, weight: .medium))
                
                Spacer()
                
                Button {
                    showToken.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                        Text(showToken ? "隐藏" : "显示")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 8) {
                // 始终使用 SecureField，通过显示模式展示明文
                SecureField("hf_...", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .disabled(showToken)
                    .opacity(showToken ? 0.5 : 1)
                
                Button {
                    openTokenSettings()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("打开 HuggingFace Token 设置页面")
            }
            
            // 显示模式下展示明文
            if showToken && !tokenInput.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(tokenInput)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(height: 20)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("取消") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
            Spacer()
            
            Button {
                validateAndSave()
            } label: {
                HStack(spacing: 6) {
                    if isValidating {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                    }
                    Text(isValidating ? "验证中..." : "登录")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(tokenInput.isEmpty || isValidating)
        }
    }
    
    // MARK: - Actions
    
    private func openTokenSettings() {
        authService.openTokenSettings()
    }
    
    private func validateAndSave() {
        isValidating = true
        validationError = nil
        
        Task {
            let success = await authService.authenticate(with: tokenInput)
            
            await MainActor.run {
                isValidating = false
                
                if success {
                    dismiss()
                } else if let error = authService.lastError {
                    validationError = error
                }
            }
        }
    }
}

#Preview {
    HuggingFaceAuthSheet(authService: HuggingFaceAuthService.shared)
}
