//
//  ModelPickerMenu.swift
//  YumikoToys
//
//  模型选择下拉菜单
//

import SwiftUI

struct ModelPickerMenu: View {
    @Binding var selectedModel: String
    let availableModels: [AIModelInfo]
    let onModelChange: (String) -> Void

    var body: some View {
        Menu {
            if availableModels.isEmpty {
                Text("暂无可用模型")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(availableModels) { model in
                    Button(action: {
                        if selectedModel != model.id {
                            selectedModel = model.id
                            onModelChange(model.id)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.name)
                                    .font(.system(size: 12))
                                if !model.description.isEmpty {
                                    Text(model.description)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if selectedModel == model.id {
                                Image(systemName: "checkmark")
                            }
                            Spacer()
                            if model.supportsThinking {
                                Text("🧠")
                                    .font(.system(size: 10))
                            }
                            if model.supportsVision {
                                Text("👁")
                                    .font(.system(size: 10))
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedModel.isEmpty ? "选择模型" : selectedModel.components(separatedBy: "/").last ?? selectedModel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: 180)
    }
}
