//
//  PromptTemplatePicker.swift
//  YumikoToys
//
//  提示词模板选择器组件
//

import SwiftUI
import OSLog

/// 提示词模板选择器
/// 用于浏览、搜索和选择提示词模板
struct PromptTemplatePicker: View {
    @StateObject private var templateService = PromptTemplateService()
    @Binding var selectedTemplate: PromptTemplate?

    @State private var showingVariableSheet = false
    @State private var selectedTemplateForVariables: PromptTemplate?
    @State private var variableValues: [String: String] = [:]
    @State private var showingSettings = false

    private let logger = Logger(subsystem: "com.yumikotoys", category: "PromptTemplatePicker")

    // 所有分类选项（包含"全部"）
    private let allCategories: [PromptCategory?] = [nil] + PromptCategory.allCases.filter { $0 != .custom }

    var body: some View {
        VStack(spacing: 0) {
            // 头部区域
            headerView

            Divider()
                .background(Color.primary.opacity(0.1))

            // 分类筛选
            categoryFilterView
                .padding(.vertical, 12)

            // 搜索框
            searchFieldView
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // 模板列表
            templateListView
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showingVariableSheet) {
            TemplateVariableSheet(
                template: selectedTemplateForVariables,
                variableValues: $variableValues,
                onApply: applyTemplateWithVariables,
                onCancel: { showingVariableSheet = false }
            )
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Text("📝")
                    .font(.system(size: 20))
                Text("提示词模板")
                    .font(.system(size: 16, weight: .semibold))
            }

            Spacer()

            Button(action: { showingSettings = true }) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .help("模板设置")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Category Filter View

    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(allCategories.enumerated()), id: \.offset) { _, category in
                    CategoryChip(
                        title: category?.displayName ?? "全部",
                        icon: category?.icon,
                        isSelected: templateService.selectedCategory == category
                    ) {
                        templateService.selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Search Field View

    private var searchFieldView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            TextField("搜索模板...", text: $templateService.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !templateService.searchText.isEmpty {
                Button(action: { templateService.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Template List View

    private var templateListView: some View {
        ScrollView(showsIndicators: true) {
            LazyVStack(spacing: 8) {
                ForEach(templateService.filteredTemplates) { template in
                    TemplateRow(
                        template: template,
                        isFavorite: templateService.isFavorite(template)
                    ) {
                        selectTemplate(template)
                    } onToggleFavorite: {
                        templateService.toggleFavorite(template)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Actions

    private func selectTemplate(_ template: PromptTemplate) {
        if template.variables.isEmpty {
            // 无变量，直接选择
            selectedTemplate = template
        } else {
            // 有变量，显示变量输入弹窗
            selectedTemplateForVariables = template
            variableValues = [:]
            showingVariableSheet = true
        }
    }

    private func applyTemplateWithVariables() {
        guard let template = selectedTemplateForVariables else { return }

        // 验证必填变量
        let missingVariables = template.variables
            .filter { $0.isRequired && (variableValues[$0.name]?.isEmpty ?? true) }
            .map { $0.name }
        if !missingVariables.isEmpty {
            logger.warning("Missing required variables: \(missingVariables.joined(separator: ", "))")
            return
        }

        // 应用变量并选择模板
        let appliedTemplate = PromptTemplate(
            id: template.id,
            name: template.name,
            category: template.category,
            template: templateService.apply(template: template, variables: variableValues),
            variables: [],
            description: template.templateDescription,
            isBuiltIn: template.isBuiltIn
        )

        selectedTemplate = appliedTemplate
        showingVariableSheet = false
        selectedTemplateForVariables = nil
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "3B82F6"), Color(hex: "06B6D4")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        : AnyShapeStyle(Color.primary.opacity(isHovered ? 0.08 : 0.04))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected
                        ? Color(hex: "3B82F6").opacity(0.3)
                        : Color.primary.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Template Row

private struct TemplateRow: View {
    let template: PromptTemplate
    let isFavorite: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 图标
                Image(systemName: template.category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(iconColor.opacity(0.1))
                    )

                // 内容
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(template.templateDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // 收藏按钮
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(isFavorite ? Color(hex: "F59E0B") : .secondary)
                }
                .buttonStyle(.plain)
                .help(isFavorite ? "取消收藏" : "收藏模板")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(isHovered ? 0.05 : 0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var iconColor: Color {
        switch template.category {
        case .writing:
            return Color(hex: "3B82F6")
        case .coding:
            return Color(hex: "8B5CF6")
        case .analysis:
            return Color(hex: "10B981")
        case .translation:
            return Color(hex: "F59E0B")
        case .creative:
            return Color(hex: "EC4899")
        case .custom:
            return Color(hex: "6B7280")
        }
    }
}

// MARK: - Template Variable Sheet

private struct TemplateVariableSheet: View {
    let template: PromptTemplate?
    @Binding var variableValues: [String: String]
    let onApply: () -> Void
    let onCancel: () -> Void

    @State private var validationErrors: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("填写模板变量")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // 变量输入区域
            if let template = template {
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 16) {
                        ForEach(template.variables) { variable in
                            VariableInputField(
                                variable: variable,
                                value: binding(for: variable),
                                hasError: validationErrors.contains(variable.name)
                            )
                        }
                    }
                    .padding(20)
                }
            }

            Divider()

            // 底部按钮
            HStack(spacing: 12) {
                Button("取消", action: onCancel)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.05))
                    )

                Button("应用模板", action: validateAndApply)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: [Color(hex: "3B82F6"), Color(hex: "06B6D4")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                    .foregroundStyle(.white)
            }
            .padding(20)
        }
        .frame(width: 480, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func binding(for variable: PromptVariable) -> Binding<String> {
        Binding(
            get: { variableValues[variable.name] ?? "" },
            set: { variableValues[variable.name] = $0 }
        )
    }

    private func validateAndApply() {
        guard let template = template else { return }

        // 验证必填字段
        var errors: Set<String> = []
        for variable in template.variables {
            if variable.isRequired && (variableValues[variable.name]?.isEmpty ?? true) {
                errors.insert(variable.name)
            }
        }

        validationErrors = errors

        if errors.isEmpty {
            onApply()
        }
    }
}

// MARK: - Variable Input Field

private struct VariableInputField: View {
    let variable: PromptVariable
    @Binding var value: String
    let hasError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(variable.name)
                    .font(.system(size: 13, weight: .medium))

                if variable.isRequired {
                    Text("*")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "EF4444"))
                }
            }

            if variable.name.lowercased().contains("content") ||
               variable.name.lowercased().contains("code") ||
               variable.name.lowercased().contains("text") ||
               variable.name.lowercased().contains("data") {
                // 多行文本输入
                TextEditor(text: $value)
                    .font(.system(size: 13))
                    .frame(minHeight: 80, maxHeight: 150)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(hasError ? Color(hex: "EF4444") : Color.primary.opacity(0.1), lineWidth: 1)
                    )
            } else {
                // 单行文本输入
                TextField(variable.placeholder, text: $value)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(hasError ? Color(hex: "EF4444") : Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }

            if hasError {
                Text("此字段为必填项")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "EF4444"))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PromptTemplatePicker(selectedTemplate: .constant(nil))
        .frame(width: 400, height: 600)
}
