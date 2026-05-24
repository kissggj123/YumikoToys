import Foundation

/// 支持的文件类型
enum SupportedFileType: String, CaseIterable, Identifiable, Codable {
    case pdf = "pdf"
    case image = "image"
    case code = "code"
    case text = "text"
    case document = "document"
    case unknown = "unknown"

    var id: String { rawValue }

    /// 根据文件扩展名推断文件类型
    static func infer(from fileExtension: String) -> SupportedFileType {
        let ext = fileExtension.lowercased()

        switch ext {
        case "pdf":
            return .pdf
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif",
             "ico", "icns", "svg", "raw", "cr2", "nef", "arw", "dng":
            return .image
        case "swift", "m", "h", "c", "cpp", "cc", "cxx", "java", "kt", "py", "js", "ts",
             "jsx", "tsx", "html", "htm", "css", "scss", "sass", "less", "json", "xml",
             "yaml", "yml", "toml", "ini", "conf", "sh", "bash", "zsh", "rb", "go",
             "rs", "php", "cs", "vb", "pl", "sql", "r", "matlab", "scala", "groovy",
             "dart", "lua", "perl", "clj", "cljs", "coffee", "elm", "erl", "fs", "fsx",
             "hs", "lhs", "jl", "ml", "mli", "pas", "pp", "proto", "purs", "sol",
             "tf", "vue", "svelte", "cmake", "makefile", "gradle", "dockerfile",
             "protobuf", "graphql", "gql", "lock", "env":
            return .code
        case "txt", "md", "markdown", "log", "csv", "tsv", "rtf":
            return .text
        case "doc", "docx", "pages", "odt", "xls", "xlsx", "numbers", "ods", "ppt",
             "pptx", "key", "odp", "dotx", "xltx", "potx", "docm", "xlsm", "pptm",
             "xlt", "xlm", "dif", "slk", "wks", "wk1", "wq1", "dbf":
            return .document
        default:
            return .unknown
        }
    }

    /// 文件类型显示名称
    var displayName: String {
        switch self {
        case .pdf:
            return "PDF"
        case .image:
            return "图片"
        case .code:
            return "代码"
        case .text:
            return "文本"
        case .document:
            return "文档"
        case .unknown:
            return "未知"
        }
    }

    /// 文件类型图标名称
    var iconName: String {
        switch self {
        case .pdf:
            return "doc.text.fill"
        case .image:
            return "photo.fill"
        case .code:
            return "curlybraces"
        case .text:
            return "text.alignleft"
        case .document:
            return "doc.fill"
        case .unknown:
            return "questionmark.document.fill"
        }
    }

    /// 是否支持文本提取
    var supportsTextExtraction: Bool {
        switch self {
        case .pdf, .code, .text, .document:
            return true
        case .image:
            return true // 通过 OCR
        case .unknown:
            return false
        }
    }
}

/// 文件上传状态
enum FileUploadStatus: String, CaseIterable, Identifiable, Codable {
    case pending = "pending"
    case uploading = "uploading"
    case uploaded = "uploaded"
    case analyzing = "analyzing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"

    var id: String { rawValue }

    /// 状态显示名称
    var displayName: String {
        switch self {
        case .pending:
            return "等待中"
        case .uploading:
            return "上传中"
        case .uploaded:
            return "已上传"
        case .analyzing:
            return "分析中"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        case .cancelled:
            return "已取消"
        }
    }

    /// 状态对应的颜色标识
    var isError: Bool {
        self == .failed || self == .cancelled
    }

    var isSuccess: Bool {
        self == .completed
    }

    var isProcessing: Bool {
        self == .uploading || self == .analyzing
    }

    var isTerminal: Bool {
        self == .completed || self == .failed || self == .cancelled
    }
}

/// 文件分析结果
struct FileAnalysisResult: Identifiable, Codable, Equatable {
    let id: UUID
    let fileId: UUID
    var extractedText: String?
    var summary: String?
    var metadata: [String: String]
    var tokenCount: Int
    let analysisDate: Date

    init(
        id: UUID = UUID(),
        fileId: UUID,
        extractedText: String? = nil,
        summary: String? = nil,
        metadata: [String: String] = [:],
        tokenCount: Int = 0,
        analysisDate: Date = Date()
    ) {
        self.id = id
        self.fileId = fileId
        self.extractedText = extractedText
        self.summary = summary
        self.metadata = metadata
        self.tokenCount = tokenCount
        self.analysisDate = analysisDate
    }
}

/// 已上传文件模型
struct UploadedFile: Identifiable, Codable, Equatable {
    let id: UUID
    var fileName: String
    var fileURL: URL?
    var fileType: SupportedFileType
    var fileSize: Int64
    let uploadDate: Date
    var status: FileUploadStatus
    var errorMessage: String?
    var analysisResult: FileAnalysisResult?

    init(
        id: UUID = UUID(),
        fileName: String,
        fileURL: URL? = nil,
        fileType: SupportedFileType = .unknown,
        fileSize: Int64 = 0,
        uploadDate: Date = Date(),
        status: FileUploadStatus = .pending,
        errorMessage: String? = nil,
        analysisResult: FileAnalysisResult? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.fileURL = fileURL
        self.fileType = fileType
        self.fileSize = fileSize
        self.uploadDate = uploadDate
        self.status = status
        self.errorMessage = errorMessage
        self.analysisResult = analysisResult
    }

    /// 从 URL 创建文件实例
    init?(url: URL) {
        guard url.isFileURL else { return nil }

        let fileName = url.lastPathComponent
        let fileExtension = url.pathExtension
        let fileType = SupportedFileType.infer(from: fileExtension)

        var fileSize: Int64 = 0
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            // 如果无法获取文件大小，继续使用 0
        }

        self.init(
            fileName: fileName,
            fileURL: url,
            fileType: fileType,
            fileSize: fileSize
        )
    }

    /// 文件大小格式化显示
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// 文件扩展名
    var fileExtension: String {
        URL(fileURLWithPath: fileName).pathExtension
    }

    /// 文件是否存在
    var fileExists: Bool {
        guard let fileURL = fileURL else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// 更新状态并清除错误信息
    mutating func updateStatus(_ newStatus: FileUploadStatus) {
        status = newStatus
        if newStatus != .failed {
            errorMessage = nil
        }
    }

    /// 标记为失败
    mutating func markFailed(with error: String) {
        status = .failed
        errorMessage = error
    }

    /// 设置分析结果
    mutating func setAnalysisResult(_ result: FileAnalysisResult) {
        analysisResult = result
        status = .completed
    }
}

// MARK: - 扩展支持

extension UploadedFile {
    /// 用于预览的示例数据
    static var preview: UploadedFile {
        UploadedFile(
            fileName: "example.pdf",
            fileType: .pdf,
            fileSize: 1024 * 1024, // 1 MB
            status: .completed,
            analysisResult: FileAnalysisResult(
                fileId: UUID(),
                extractedText: "这是提取的文本内容示例...",
                summary: "这是一个示例文件的摘要",
                metadata: ["pages": "10", "author": "Yumiko"],
                tokenCount: 500
            )
        )
    }

    /// 多个预览示例
    static var previewList: [UploadedFile] {
        [
            UploadedFile(
                fileName: "document.pdf",
                fileType: .pdf,
                fileSize: 2_500_000,
                status: .completed
            ),
            UploadedFile(
                fileName: "screenshot.png",
                fileType: .image,
                fileSize: 850_000,
                status: .analyzing
            ),
            UploadedFile(
                fileName: "main.swift",
                fileType: .code,
                fileSize: 15_000,
                status: .pending
            ),
            UploadedFile(
                fileName: "notes.txt",
                fileType: .text,
                fileSize: 5_000,
                status: .failed,
                errorMessage: "文件格式不支持"
            )
        ]
    }
}
