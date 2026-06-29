//
//  FileAnalysisService.swift
//  YumikoToys
//
//  文件分析服务 - 支持 PDF 解析、图片 OCR 和文本提取
//

import Foundation
import PDFKit
import Vision
import AppKit
import OSLog

// MARK: - 错误类型

/// 文件分析错误
enum FileAnalysisError: Error, LocalizedError {
    case fileNotFound
    case invalidFile
    case fileTooLarge(Int64)
    case unsupportedType(String)
    case pdfLoadFailed
    case imageLoadFailed
    case ocrFailed(Error)
    case textExtractionFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "文件不存在"
        case .invalidFile:
            return "无效的文件"
        case .fileTooLarge(let max):
            return "文件大小超过限制（最大 \(max / 1024 / 1024)MB）"
        case .unsupportedType(let type):
            return "不支持的文件类型: \(type)"
        case .pdfLoadFailed:
            return "PDF 加载失败"
        case .imageLoadFailed:
            return "图片加载失败"
        case .ocrFailed(let error):
            return "OCR 识别失败: \(error.localizedDescription)"
        case .textExtractionFailed:
            return "文本提取失败"
        case .encodingFailed:
            return "文件编码无法识别"
        }
    }
}

// MARK: - 文件分析服务

/// 文件分析服务 - 支持 PDF、图片 OCR 和文本文件分析
final class FileAnalysisService: Sendable {

    // MARK: - 属性

    /// 最大文件大小（10MB）
    let maxFileSize: Int64 = 10 * 1024 * 1024

    /// 最大文本长度
    let maxTextLength: Int = 50000

    /// 日志记录器
    private let logger = Logger(subsystem: "com.yumikotoys.app", category: "FileAnalysis")

    // MARK: - 初始化

    init() {}

    // MARK: - 公共方法

    /// 上传并分析文件
    /// - Parameter url: 文件 URL
    /// - Returns: 文件分析结果
    func uploadAndAnalyze(url: URL) async throws -> FileAnalysisResult {
        logger.info("开始上传并分析文件: \(url.lastPathComponent)")

        // 验证文件存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.error("文件不存在: \(url.path)")
            throw FileAnalysisError.fileNotFound
        }

        // 获取文件信息
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0

        // 验证文件大小
        guard fileSize <= maxFileSize else {
            logger.error("文件过大: \(fileSize) 字节")
            throw FileAnalysisError.fileTooLarge(maxFileSize)
        }

        // 推断文件类型
        let fileExtension = url.pathExtension.lowercased()
        let fileType = SupportedFileType.infer(from: fileExtension)

        logger.info("文件类型: \(fileType.rawValue), 大小: \(fileSize) 字节")

        // 执行分析
        return try await analyze(url: url, fileType: fileType)
    }

    /// 根据文件类型分析文件
    /// - Parameters:
    ///   - url: 文件 URL
    ///   - fileType: 文件类型
    /// - Returns: 文件分析结果
    func analyze(url: URL, fileType: SupportedFileType) async throws -> FileAnalysisResult {
        logger.info("开始分析文件，类型: \(fileType.rawValue)")

        let extractedText: String
        var metadata: [String: String] = [:]

        switch fileType {
        case .pdf:
            (extractedText, metadata) = try await analyzePDF(at: url)

        case .image:
            // 使用增强版图片分析服务
            let imageService = ImageAnalysisService()
            let imageResult = try await imageService.analyze(url: url)
            extractedText = imageResult.ocrText ?? ""
            metadata["ocr"] = imageResult.ocrText != nil ? "true" : "false"
            if let conf = imageResult.ocrConfidence {
                metadata["ocr_confidence"] = String(format: "%.2f", conf)
            }
            if let caption = imageResult.caption {
                metadata["caption"] = caption
            }
            if let w = imageResult.dimensions?.width, let h = imageResult.dimensions?.height {
                metadata["dimensions"] = "\(Int(w))x\(Int(h))"
            }
            if !imageResult.barcodes.isEmpty {
                metadata["barcodes"] = imageResult.barcodes.map(\.value).joined(separator: ", ")
            }
            // 合并图片元数据
            for (key, value) in imageResult.metadata {
                metadata[key] = value
            }

        case .text, .code:
            extractedText = try await analyzeTextFile(at: url)
            metadata["lines"] = "\(extractedText.components(separatedBy: .newlines).count)"

        case .document:
            // 使用 Office 文档解析器
            let officeParser = OfficeDocumentParser()
            let officeResult = try await officeParser.parse(url: url)
            extractedText = officeResult.textContent
            metadata["word_count"] = "\(officeResult.wordCount)"
            metadata["char_count"] = "\(officeResult.charCount)"
            for (key, value) in officeResult.metadata {
                metadata[key] = value
            }

        case .unknown:
            // 尝试 Office 解析器自动检测
            let officeParser = OfficeDocumentParser()
            let docType = await officeParser.detectFileType(url: url)
            if docType.isSupported {
                logger.info("自动检测为 Office 文档: \(docType.displayName)")
                let officeResult = try await officeParser.parse(url: url)
                extractedText = officeResult.textContent
                metadata["detected_type"] = docType.displayName
                metadata["word_count"] = "\(officeResult.wordCount)"
                for (key, value) in officeResult.metadata {
                    metadata[key] = value
                }
            } else {
                logger.error("不支持的文件类型")
                throw FileAnalysisError.unsupportedType(url.pathExtension)
            }
        }

        // 截断文本到最大长度
        let truncatedText = String(extractedText.prefix(maxTextLength))
        let tokenCount = estimateTokenCount(for: truncatedText)

        let result = FileAnalysisResult(
            fileId: UUID(),
            extractedText: truncatedText.isEmpty ? nil : truncatedText,
            summary: nil,
            metadata: metadata,
            tokenCount: tokenCount
        )

        logger.info("文件分析完成，提取 \(truncatedText.count) 字符，约 \(tokenCount) tokens")

        return result
    }

    /// 从文件提取内容
    /// - Parameter url: 文件 URL
    /// - Returns: 提取的文本内容
    func extractContent(from url: URL) async throws -> String {
        logger.info("提取文件内容: \(url.lastPathComponent)")

        let fileExtension = url.pathExtension.lowercased()
        let fileType = SupportedFileType.infer(from: fileExtension)

        let result = try await analyze(url: url, fileType: fileType)
        return result.extractedText ?? ""
    }

    // MARK: - 私有方法 - PDF 分析

    /// 分析 PDF 文件
    /// - Parameter url: PDF 文件 URL
    /// - Returns: (提取的文本, 元数据)
    private func analyzePDF(at url: URL) async throws -> (String, [String: String]) {
        logger.info("开始分析 PDF: \(url.lastPathComponent)")

        guard let pdfDocument = PDFDocument(url: url) else {
            logger.error("无法加载 PDF 文档")
            throw FileAnalysisError.pdfLoadFailed
        }

        var extractedText = ""
        let pageCount = pdfDocument.pageCount
        var metadata: [String: String] = [
            "pages": "\(pageCount)",
            "type": "pdf"
        ]

        // 提取文档属性
        if let documentAttributes = pdfDocument.documentAttributes {
            if let title = documentAttributes[PDFDocumentAttribute.titleAttribute] as? String {
                metadata["title"] = title
            }
            if let author = documentAttributes[PDFDocumentAttribute.authorAttribute] as? String {
                metadata["author"] = author
            }
        }

        // 逐页提取文本
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            if let pageText = page.string {
                extractedText += pageText + "\n"
            }

            // 检查文本长度限制
            if extractedText.count >= maxTextLength {
                logger.warning("PDF 文本超过最大长度限制，截断处理")
                extractedText = String(extractedText.prefix(maxTextLength))
                metadata["truncated"] = "true"
                break
            }
        }

        logger.info("PDF 分析完成，共 \(pageCount) 页，提取 \(extractedText.count) 字符")

        return (extractedText, metadata)
    }

    // MARK: - 私有方法 - 图片分析

    /// 分析图片文件（OCR）
    /// - Parameter url: 图片文件 URL
    /// - Returns: 识别的文本
    private func analyzeImage(at url: URL) async throws -> String {
        logger.info("开始分析图片: \(url.lastPathComponent)")

        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            logger.error("无法加载图片")
            throw FileAnalysisError.imageLoadFailed
        }

        return try await performOCR(on: cgImage)
    }

    /// 执行 OCR 识别
    /// - Parameter cgImage: CGImage
    /// - Returns: 识别的文本
    private func performOCR(on cgImage: CGImage) async throws -> String {
        logger.info("开始 OCR 识别")

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    self.logger.error("OCR 失败: \(error.localizedDescription)")
                    continuation.resume(throwing: FileAnalysisError.ocrFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                self.logger.info("OCR 完成，识别 \(recognizedText.count) 字符")
                continuation.resume(returning: recognizedText)
            }

            // 配置识别选项
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]

            let requestHandler = VNImageRequestHandler(
                cgImage: cgImage,
                options: [:]
            )

            do {
                try requestHandler.perform([request])
            } catch {
                logger.error("OCR 请求执行失败: \(error.localizedDescription)")
                continuation.resume(throwing: FileAnalysisError.ocrFailed(error))
            }
        }
    }

    // MARK: - 私有方法 - 文本文件分析

    /// 分析文本文件
    /// - Parameter url: 文本文件 URL
    /// - Returns: 文件内容
    private func analyzeTextFile(at url: URL) async throws -> String {
        logger.info("开始分析文本文件: \(url.lastPathComponent)")

        // 尝试读取文件数据
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            logger.error("无法读取文件: \(error.localizedDescription)")
            throw FileAnalysisError.invalidFile
        }

        // 尝试多种编码
        let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .ascii]

        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                logger.info("文本文件读取成功，编码: \(encoding)，长度: \(text.count)")
                return text
            }
        }

        logger.error("无法识别文件编码")
        throw FileAnalysisError.encodingFailed
    }

    // MARK: - 辅助方法

    /// 估算 Token 数量（简化算法）
    /// - Parameter text: 文本内容
    /// - Returns: 估算的 token 数量
    private func estimateTokenCount(for text: String) -> Int {
        // 简化估算：中文约 1.5 字符/token，英文约 4 字符/token
        // 这里使用保守估计
        let chineseCharacterCount = text.reduce(0) { count, char in
            return count + (char.isASCII ? 0 : 1)
        }
        let asciiCharacterCount = text.count - chineseCharacterCount

        let chineseTokens = Int(ceil(Double(chineseCharacterCount) / 1.5))
        let asciiTokens = Int(ceil(Double(asciiCharacterCount) / 4.0))

        return chineseTokens + asciiTokens
    }
}

// MARK: - 扩展支持

extension FileAnalysisService {

    /// 批量分析多个文件
    /// - Parameter urls: 文件 URL 数组
    /// - Returns: 分析结果数组（与输入顺序对应，失败的返回 nil）
    func batchAnalyze(urls: [URL]) async -> [FileAnalysisResult?] {
        logger.info("开始批量分析 \(urls.count) 个文件")

        return await withTaskGroup(of: (Int, FileAnalysisResult?).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    do {
                        let result = try await self.uploadAndAnalyze(url: url)
                        return (index, result)
                    } catch {
                        self.logger.error("分析文件失败 \(url.lastPathComponent): \(error.localizedDescription)")
                        return (index, nil)
                    }
                }
            }

            var results: [(Int, FileAnalysisResult?)] = []
            for await result in group {
                results.append(result)
            }

            // 按原始顺序排序
            results.sort { $0.0 < $1.0 }
            return results.map { $0.1 }
        }
    }

    /// 检查文件是否支持分析
    /// - Parameter url: 文件 URL
    /// - Returns: 是否支持
    func isSupportedFile(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        let fileType = SupportedFileType.infer(from: fileExtension)
        return fileType != .unknown
    }

    /// 获取文件信息
    /// - Parameter url: 文件 URL
    /// - Returns: 文件信息字典
    func getFileInfo(_ url: URL) -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileExtension = url.pathExtension.lowercased()
            let fileType = SupportedFileType.infer(from: fileExtension)

            return [
                "name": url.lastPathComponent,
                "extension": fileExtension,
                "type": fileType.rawValue,
                "size": attributes[.size] as? Int64 ?? 0,
                "creationDate": attributes[.creationDate] as? Date ?? Date(),
                "modificationDate": attributes[.modificationDate] as? Date ?? Date()
            ]
        } catch {
            logger.error("获取文件信息失败: \(error.localizedDescription)")
            return nil
        }
    }
}
