//
//  FilePreviewChip.swift
//  YumikoToys
//
//  文件预览 Chip 组件
//

import SwiftUI
import UniformTypeIdentifiers

/// 文件预览 Chip 组件
struct FilePreviewChip: View {
    let file: UploadedFile
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // 文件类型图标
            Image(systemName: file.fileType.iconName)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(iconBackgroundColor)
                )

            // 文件名
            Text(file.fileName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 120)

            // 状态指示器或删除按钮
            if file.status.isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            } else if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "FF6B9D"))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            } else {
                statusIndicator
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderStroke, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(fileTooltip)
    }

    // MARK: - 状态指示器

    @ViewBuilder
    private var statusIndicator: some View {
        if file.status.isSuccess {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "22C55E"))
                .frame(width: 16, height: 16)
        } else if file.status.isError {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "EF4444"))
                .frame(width: 16, height: 16)
        } else {
            Circle()
                .fill(Color.primary.opacity(0.3))
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - 样式计算

    private var iconColor: Color {
        switch file.fileType {
        case .pdf:
            return Color(hex: "F87171")
        case .image:
            return Color(hex: "22C55E")
        case .code:
            return Color(hex: "3B82F6")
        case .text:
            return Color(hex: "A78BFA")
        case .document:
            return Color(hex: "F59E0B")
        case .unknown:
            return .secondary
        }
    }

    private var iconBackgroundColor: Color {
        iconColor.opacity(0.15)
    }

    private var backgroundFill: Color {
        if isHovered {
            return Color(hex: "2A2A2E")
        }
        return Color(hex: "1A1A1E")
    }

    private var borderStroke: Color {
        if isHovered {
            return Color.primary.opacity(0.2)
        }
        return Color.primary.opacity(0.1)
    }

    private var fileTooltip: String {
        var tooltip = "\(file.fileName)\n类型: \(file.fileType.displayName)\n大小: \(file.formattedFileSize)"
        if let error = file.errorMessage {
            tooltip += "\n错误: \(error)"
        }
        return tooltip
    }
}

// MARK: - 预览

struct FilePreviewChip_Previews: SwiftUI.PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            FilePreviewChip(file: UploadedFile.preview) {
                print("Remove clicked")
            }

            FilePreviewChip(file: UploadedFile(
                fileName: "screenshot.png",
                fileType: .image,
                fileSize: 850_000,
                status: .analyzing
            )) {
                print("Remove clicked")
            }

            FilePreviewChip(file: UploadedFile(
                fileName: "main.swift",
                fileType: .code,
                fileSize: 15_000,
                status: .pending
            )) {
                print("Remove clicked")
            }

            FilePreviewChip(file: UploadedFile(
                fileName: "notes.txt",
                fileType: .text,
                fileSize: 5_000,
                status: .failed,
                errorMessage: "文件格式不支持"
            )) {
                print("Remove clicked")
            }
        }
        .padding()
        .background(Color(hex: "0F0F12"))
    }
}
