//
//  FileUploadView.swift
//  YumikoToys
//
//  文件上传视图组件
//

import SwiftUI
import UniformTypeIdentifiers
import OSLog

// MARK: - Logger 扩展

private extension Logger {
    static let ui = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yumikotoys",
        category: "UI"
    )
}

/// 文件上传视图
struct FileUploadView: View {
    @Binding var uploadedFiles: [UploadedFile]
    let onFilesAdded: ([URL]) -> Void

    @State private var isDragging = false
    @State private var showFilePicker = false

    /// 支持的文件类型
    private let supportedContentTypes: [UTType] = [
        .pdf,
        .image,
        .plainText,
        .sourceCode
    ]

    var body: some View {
        VStack(spacing: 0) {
            if uploadedFiles.isEmpty {
                FileDropZone(
                    isDragging: $isDragging,
                    onTap: { showFilePicker = true }
                )
                .frame(height: 80)
            } else {
                filesPreviewArea
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(dropZoneBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(dropZoneBorder, lineWidth: isDragging ? 2 : 1)
        )
        .onDrop(of: supportedContentTypes, isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: supportedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFilePickerResult(result)
        }
    }

    // MARK: - 文件预览区域

    private var filesPreviewArea: some View {
        HStack(spacing: 12) {
            // Paperclip 按钮
            paperclipButton

            // 水平滚动的文件 Chip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(uploadedFiles) { file in
                        FilePreviewChip(file: file) {
                            removeFile(file)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .frame(height: 52)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Paperclip 按钮

    private var paperclipButton: some View {
        Button(action: { showFilePicker = true }) {
            Image(systemName: "paperclip")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help("添加文件")
    }

    // MARK: - 拖放区域背景

    private var dropZoneBackground: Color {
        if isDragging {
            return Color(hex: "3B82F6").opacity(0.1)
        }
        return Color(hex: "1A1A1E")
    }

    private var dropZoneBorder: Color {
        if isDragging {
            return Color(hex: "3B82F6").opacity(0.5)
        }
        return Color.primary.opacity(0.1)
    }

    // MARK: - 文件操作

    private func removeFile(_ file: UploadedFile) {
        withAnimation(.easeInOut(duration: 0.2)) {
            uploadedFiles.removeAll { $0.id == file.id }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                onFilesAdded(urls)
            }
        }

        return true
    }

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            onFilesAdded(urls)
        case .failure(let error):
            Logger.ui.error("文件选择失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 紧凑型文件上传按钮（仅回形针图标，不渲染拖拽占位区域）

struct CompactFileUploadButton: View {
    let onFilesAdded: ([URL]) -> Void

    @State private var showFilePicker = false
    @State private var isDragging = false

    private let supportedContentTypes: [UTType] = [
        .pdf, .image, .plainText, .sourceCode
    ]

    var body: some View {
        Button(action: { showFilePicker = true }) {
            Image(systemName: "paperclip")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isDragging ? Color(hex: "3B82F6") : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isDragging ? Color(hex: "3B82F6").opacity(0.15) : Color.white.opacity(0.06))
                )
                .overlay(
                    Circle()
                        .stroke(
                            isDragging ? Color(hex: "3B82F6").opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help("添加文件（支持 PDF、图片、文本、代码）")
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: supportedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): onFilesAdded(urls)
            case .failure(let error): Logger.ui.error("文件选择失败: \(error.localizedDescription)")
            }
        }
        .onDrop(of: supportedContentTypes, isTargeted: $isDragging) { providers in
            var urls: [URL] = []
            let group = DispatchGroup()
            for provider in providers {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    }
                }
            }
            group.notify(queue: .main) {
                if !urls.isEmpty { onFilesAdded(urls) }
            }
            return true
        }
    }
}

// MARK: - 文件拖放区域（空状态）

struct FileDropZone: View {
    @Binding var isDragging: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(isDragging ? Color(hex: "3B82F6") : .secondary)

                Text("点击或拖拽文件到此处")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Text("支持 PDF、图片、文本、代码文件")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isDragging
                            ? Color(hex: "3B82F6").opacity(0.5)
                            : Color.primary.opacity(0.1),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 预览

struct FileUploadView_Previews: SwiftUI.PreviewProvider {
    static var previews: some View {
        Group {
            // 空状态
            FileUploadView(
                uploadedFiles: .constant([]),
                onFilesAdded: { urls in
                    print("Files added: \(urls)")
                }
            )
            .padding()
            .background(Color(hex: "0F0F12"))
            .frame(width: 400)
            .previewDisplayName("空状态")

            // 有文件
            FileUploadView(
                uploadedFiles: .constant(UploadedFile.previewList),
                onFilesAdded: { urls in
                    print("Files added: \(urls)")
                }
            )
            .padding()
            .background(Color(hex: "0F0F12"))
            .frame(width: 400)
            .previewDisplayName("有文件")
        }
    }
}
