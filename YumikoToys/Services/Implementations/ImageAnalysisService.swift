//
//  ImageAnalysisService.swift
//  YumikoToys
//
//  综合图片分析服务 - 支持 OCR、元数据提取、条码检测、缩略图生成
//  基于 Vision / ImageIO 框架，支持所有常见图片格式
//

import Foundation
import AppKit
import Vision
import ImageIO
import UniformTypeIdentifiers
import OSLog

// MARK: - 支持的图片格式

/// 支持的图片格式枚举
enum SupportedImageFormat: String, CaseIterable, Sendable {
    case png
    case jpg
    case jpeg
    case webp
    case gif
    case bmp
    case tiff
    case tif
    case heic
    case heif
    case ico
    case svg
    case raw

    /// 文件扩展名
    var fileExtension: String {
        switch self {
        case .png:  return "png"
        case .jpg:  return "jpg"
        case .jpeg: return "jpeg"
        case .webp: return "webp"
        case .gif:  return "gif"
        case .bmp:  return "bmp"
        case .tiff: return "tiff"
        case .tif:  return "tif"
        case .heic: return "heic"
        case .heif: return "heif"
        case .ico:  return "ico"
        case .svg:  return "svg"
        case .raw:  return "raw"
        }
    }

    /// 显示名称
    var displayName: String {
        switch self {
        case .png:  return "PNG"
        case .jpg:  return "JPEG"
        case .jpeg: return "JPEG"
        case .webp: return "WebP"
        case .gif:  return "GIF"
        case .bmp:  return "BMP"
        case .tiff: return "TIFF"
        case .tif:  return "TIFF"
        case .heic: return "HEIC"
        case .heif: return "HEIF"
        case .ico:  return "ICO"
        case .svg:  return "SVG"
        case .raw:  return "RAW"
        }
    }

    /// MIME 类型
    var mimeType: String {
        switch self {
        case .png:  return "image/png"
        case .jpg:  return "image/jpeg"
        case .jpeg: return "image/jpeg"
        case .webp: return "image/webp"
        case .gif:  return "image/gif"
        case .bmp:  return "image/bmp"
        case .tiff: return "image/tiff"
        case .tif:  return "image/tiff"
        case .heic: return "image/heic"
        case .heif: return "image/heif"
        case .ico:  return "image/x-icon"
        case .svg:  return "image/svg+xml"
        case .raw:  return "image/raw"
        }
    }

    /// 系统是否原生支持该格式（可用于 Vision / ImageIO 处理）
    var isSupported: Bool {
        switch self {
        case .svg, .raw, .ico:
            return false
        default:
            return true
        }
    }

    /// 从文件扩展名自动检测格式
    static func detect(from pathExtension: String) -> SupportedImageFormat {
        let ext = pathExtension.lowercased()
        switch ext {
        case "png":  return .png
        case "jpg":  return .jpg
        case "jpeg": return .jpeg
        case "webp": return .webp
        case "gif":  return .gif
        case "bmp":  return .bmp
        case "tiff": return .tiff
        case "tif":  return .tif
        case "heic": return .heic
        case "heif": return .heif
        case "ico":  return .ico
        case "svg":  return .svg
        case "raw":  return .raw
        default:     return .png // 默认回退
        }
    }
}

// MARK: - 条码检测结果

/// 条码/二维码检测结果
struct BarcodeResult: Sendable {
    /// 条码类型（如 "QR"、"EAN-13" 等）
    let type: String
    /// 解码后的字符串值
    let value: String
    /// 条码在图片中的边界矩形
    let bounds: CGRect
}

// MARK: - 图片分析结果

/// 图片综合分析结果
struct ImageAnalysisResult: Sendable {

    /// 图片格式
    let format: SupportedImageFormat

    /// 图片尺寸（宽 x 高）
    let dimensions: CGSize?

    /// 色彩空间描述
    let colorSpace: String?

    /// OCR 提取的文本
    let ocrText: String?

    /// OCR 平均置信度（0.0 ~ 1.0）
    let ocrConfidence: Double?

    /// AI 生成的图片描述（macOS 15+）
    let caption: String?

    /// 元数据键值对（EXIF / IPTC / TIFF）
    let metadata: [String: String]

    /// 检测到的条码/二维码
    let barcodes: [BarcodeResult]

    /// 缩略图（在主线程访问）
    let thumbnail: NSImage?

    /// 文件大小（字节）
    let fileSize: Int64
}

// MARK: - 图片分析错误

/// 图片分析服务错误类型
enum ImageAnalysisError: Error, LocalizedError {
    /// 文件不存在
    case fileNotFound(URL)
    /// 无法读取图片
    case imageLoadFailed(String)
    /// OCR 识别失败
    case ocrFailed(String)
    /// 条码检测失败
    case barcodeDetectionFailed(String)
    /// 图片描述生成失败
    case captionFailed(String)
    /// 不支持的格式
    case unsupportedFormat(String)
    /// 内存不足
    case insufficientMemory

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "文件不存在: \(url.lastPathComponent)"
        case .imageLoadFailed(let reason):
            return "图片加载失败: \(reason)"
        case .ocrFailed(let reason):
            return "OCR 识别失败: \(reason)"
        case .barcodeDetectionFailed(let reason):
            return "条码检测失败: \(reason)"
        case .captionFailed(let reason):
            return "图片描述生成失败: \(reason)"
        case .unsupportedFormat(let format):
            return "不支持的图片格式: \(format)"
        case .insufficientMemory:
            return "内存不足，无法处理该图片"
        }
    }
}

// MARK: - 图片分析服务

/// 综合图片分析服务
/// 提供 OCR 文字识别、元数据提取、条码检测、缩略图生成等功能
final class ImageAnalysisService: Sendable {

    // MARK: - 常量

    /// 最大可处理文件大小（50MB）
    private static let maxFileSize: Int64 = 50 * 1024 * 1024

    /// 默认缩略图最大尺寸
    private static let defaultThumbnailMaxSize: NSSize = NSSize(width: 200, height: 200)

    /// OCR 支持的识别语言
    private static let recognitionLanguages = ["zh-Hans", "zh-Hant", "en", "ja", "ko"]

    /// 支持的条码类型
    private static let supportedBarcodeSymbologies: [VNBarcodeSymbology] = [
        .qr,
        .ean13,
        .ean8,
        .code128,
        .pdf417,
        .aztec,
        .upce,
        .code39,
        .code93,
        .dataMatrix,
        .itf14
    ]

    // MARK: - 属性

    /// 日志记录器
    private let logger = Logger(
        subsystem: "com.yumikotoys.app",
        category: "ImageAnalysis"
    )

    // MARK: - 初始化

    init() {
        logger.info("ImageAnalysisService 初始化完成")
    }

    // MARK: - 综合分析

    /// 综合分析图片
    /// - Parameter url: 图片文件 URL
    /// - Returns: 图片分析结果
    /// - Throws: 图片加载或分析过程中的错误
    func analyze(url: URL) async throws -> ImageAnalysisResult {
        logger.info("开始综合分析图片: \(url.lastPathComponent)")

        // 验证文件
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImageAnalysisError.fileNotFound(url)
        }

        let fileSize = getFileSize(url: url)
        guard fileSize <= Self.maxFileSize else {
            throw ImageAnalysisError.insufficientMemory
        }

        // 检测格式
        let format = detectFormat(url: url)

        // SVG 特殊处理：读取文本内容，不进行视觉分析
        if format == .svg {
            return try analyzeSVG(url: url, fileSize: fileSize)
        }

        // ICO / RAW 格式：仅提取基本元数据
        if !format.isSupported {
            return analyzeUnsupportedFormat(url: url, format: format, fileSize: fileSize)
        }

        // 创建 CGImageSource
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageAnalysisError.imageLoadFailed("无法创建图片源: \(url.lastPathComponent)")
        }

        // 提取元数据
        let metadata = extractMetadata(from: imageSource)

        // 获取尺寸
        let dimensions = extractDimensions(from: imageSource)

        // 获取色彩空间
        let colorSpace = extractColorSpace(from: imageSource)

        // 生成缩略图
        let thumbnail = generateThumbnail(from: imageSource, maxSize: Self.defaultThumbnailMaxSize)

        // 并行执行 OCR、条码检测、图片描述
        async let ocrTask = extractTextWithConfidence(from: url)
        async let barcodeTask = detectBarcodes(from: url)
        async let captionTask = generateCaption(from: url)

        // 等待所有任务完成
        let ocrResult = try await ocrTask
        let barcodeResult = await barcodeTask
        let captionResult = await captionTask

        logger.info("图片分析完成: \(url.lastPathComponent)")

        return ImageAnalysisResult(
            format: format,
            dimensions: dimensions,
            colorSpace: colorSpace,
            ocrText: ocrResult?.text,
            ocrConfidence: ocrResult?.confidence,
            caption: captionResult,
            metadata: metadata,
            barcodes: barcodeResult,
            thumbnail: thumbnail,
            fileSize: fileSize
        )
    }

    // MARK: - OCR 文字识别

    /// OCR 文字提取结果（内部使用）
    private struct OCRResult: Sendable {
        let text: String
        let confidence: Double
    }

    /// 从图片中提取文字（OCR）
    /// - Parameter url: 图片文件 URL
    /// - Returns: 提取的文本内容
    /// - Throws: OCR 识别失败
    func extractText(url: URL) async throws -> String {
        guard let result = try await extractTextWithConfidence(from: url) else {
            return ""
        }
        return result.text
    }

    /// 从图片中提取文字及置信度
    /// - Parameter url: 图片文件 URL
    /// - Returns: OCR 结果（文本 + 置信度），如果无法识别则返回 nil
    private func extractTextWithConfidence(from url: URL) async throws -> OCRResult? {
        logger.debug("开始 OCR 文字识别: \(url.lastPathComponent)")

        guard let cgImage = loadCGImage(from: url) else {
            throw ImageAnalysisError.imageLoadFailed("无法加载图片用于 OCR: \(url.lastPathComponent)")
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = Self.recognitionLanguages
        request.usesLanguageCorrection = true

        // 处理大图片：限制最大尺寸以节省内存
        let maxDimension: CGFloat = 4096
        let processingImage: CGImage
        if CGFloat(cgImage.width) > maxDimension || CGFloat(cgImage.height) > maxDimension {
            processingImage = downsample(image: cgImage, maxDimension: maxDimension) ?? cgImage
        } else {
            processingImage = cgImage
        }

        let handler = VNImageRequestHandler(cgImage: processingImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            logger.error("OCR 请求执行失败: \(error.localizedDescription)")
            throw ImageAnalysisError.ocrFailed(error.localizedDescription)
        }

        guard let observations = request.results, !observations.isEmpty else {
            logger.debug("OCR 未识别到文字: \(url.lastPathComponent)")
            return nil
        }

        // 合并所有识别结果
        var fullText = ""
        var totalConfidence: Double = 0
        var confidenceCount: Int = 0

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            fullText += topCandidate.string + "\n"
            totalConfidence += Double(topCandidate.confidence)
            confidenceCount += 1
        }

        let avgConfidence = confidenceCount > 0 ? totalConfidence / Double(confidenceCount) : 0

        // 清理文本
        let cleanedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)

        logger.info("OCR 识别完成，共 \(confidenceCount) 个文本块，平均置信度: \(avgConfidence)")

        return OCRResult(text: cleanedText, confidence: avgConfidence)
    }

    // MARK: - 图片描述生成（macOS 15+）

    /// 生成图片的 AI 描述
    /// - Parameter url: 图片文件 URL
    /// - Returns: 图片描述文本，如果不可用则返回 nil
    /// 生成图片描述（当前系统不支持，预留接口）
    private func generateCaption(from url: URL) async -> String? {
        logger.debug("当前系统不支持图片描述生成（需要 macOS 15+ Vision 框架）")
        return nil
    }

    // MARK: - 元数据提取

    /// 提取图片元数据
    /// - Parameter url: 图片文件 URL
    /// - Returns: 元数据键值对
    func extractMetadata(url: URL) -> [String: String] {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            logger.warning("无法创建图片源以提取元数据: \(url.lastPathComponent)")
            return [:]
        }
        return extractMetadata(from: imageSource)
    }

    /// 从 CGImageSource 提取元数据
    /// - Parameter imageSource: 图片源
    /// - Returns: 元数据键值对
    private func extractMetadata(from imageSource: CGImageSource) -> [String: String] {
        var result: [String: String] = [:]

        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            logger.debug("无法读取图片属性")
            return result
        }

        // 基本属性
        if let width = properties[kCGImagePropertyPixelWidth] as? Int {
            result["宽度"] = "\(width) px"
        }
        if let height = properties[kCGImagePropertyPixelHeight] as? Int {
            result["高度"] = "\(height) px"
        }
        if let depth = properties[kCGImagePropertyDepth] as? Int {
            result["位深度"] = "\(depth)"
        }
        if let dpiWidth = properties[kCGImagePropertyDPIWidth] as? Int {
            result["水平 DPI"] = "\(dpiWidth)"
        }
        if let dpiHeight = properties[kCGImagePropertyDPIHeight] as? Int {
            result["垂直 DPI"] = "\(dpiHeight)"
        }

        // 色彩模型
        if let colorModel = properties[kCGImagePropertyColorModel] as? String {
            result["色彩模型"] = colorModel
        }

        // EXIF 元数据
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            extractExifMetadata(exif, into: &result)
        }

        // TIFF 元数据
        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            extractTIFFMetadata(tiff, into: &result)
        }

        // GPS 元数据
        if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            extractGPSMetadata(gps, into: &result)
        }

        // IPTC 元数据
        if let iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any] {
            extractIPTCMetadata(iptc, into: &result)
        }

        return result
    }

    /// 提取 EXIF 元数据
    private func extractExifMetadata(_ exif: [CFString: Any], into result: inout [String: String]) {
        let mapping: [CFString: String] = [
            kCGImagePropertyExifDateTimeOriginal:    "拍摄时间",
            kCGImagePropertyExifDateTimeDigitized:   "数字化时间",
            kCGImagePropertyExifFocalLength:         "焦距",
            kCGImagePropertyExifFNumber:             "光圈",
            kCGImagePropertyExifExposureTime:        "曝光时间",
            kCGImagePropertyExifISOSpeedRatings:     "ISO",
            kCGImagePropertyExifLensModel:           "镜头型号",
            kCGImagePropertyExifFlash:               "闪光灯",
            kCGImagePropertyExifExposureProgram:     "曝光程序",
            kCGImagePropertyExifMeteringMode:        "测光模式",
            kCGImagePropertyExifWhiteBalance:        "白平衡",
            kCGImagePropertyExifSceneType:           "场景类型",
            kCGImagePropertyExifSharpness:           "锐度",
            kCGImagePropertyExifSaturation:          "饱和度",
            kCGImagePropertyExifContrast:            "对比度"
        ]

        for (key, label) in mapping {
            if let value = exif[key] {
                result[label] = formatMetadataValue(value)
            }
        }

        // 特殊处理：曝光时间
        if let exposureTime = exif[kCGImagePropertyExifExposureTime] as? Double {
            if exposureTime < 1 {
                result["曝光时间"] = String(format: "1/%.0f 秒", 1.0 / exposureTime)
            } else {
                result["曝光时间"] = String(format: "%.1f 秒", exposureTime)
            }
        }

        // 特殊处理：闪光灯
        if let flash = exif[kCGImagePropertyExifFlash] as? Int32 {
            result["闪光灯"] = (flash & 1) != 0 ? "已闪光" : "未闪光"
        }

        // 特殊处理：ISO
        if let iso = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], let first = iso.first {
            result["ISO"] = "\(first)"
        } else if let iso = exif[kCGImagePropertyExifISOSpeedRatings] as? Int {
            result["ISO"] = "\(iso)"
        }

        // 特殊处理：白平衡
        if let wb = exif[kCGImagePropertyExifWhiteBalance] as? Int32 {
            result["白平衡"] = wb == 0 ? "自动" : "手动"
        }
    }

    /// 提取 TIFF 元数据
    private func extractTIFFMetadata(_ tiff: [CFString: Any], into result: inout [String: String]) {
        let mapping: [CFString: String] = [
            kCGImagePropertyTIFFMake:            "相机制造商",
            kCGImagePropertyTIFFModel:           "相机型号",
            kCGImagePropertyTIFFSoftware:        "软件",
            kCGImagePropertyTIFFArtist:          "作者",
            kCGImagePropertyTIFFCopyright:       "版权",
            kCGImagePropertyTIFFDateTime:        "修改时间",
            kCGImagePropertyTIFFImageDescription:"图片描述",
            kCGImagePropertyTIFFDocumentName:    "文档名称"
        ]

        for (key, label) in mapping {
            if let value = tiff[key] {
                result[label] = formatMetadataValue(value)
            }
        }
    }

    /// 提取 GPS 元数据
    private func extractGPSMetadata(_ gps: [CFString: Any], into result: inout [String: String]) {
        // 纬度
        if let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
           let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String {
            result["纬度"] = String(format: "%f° %@", latitude, latitudeRef)
        }

        // 经度
        if let longitude = gps[kCGImagePropertyGPSLongitude] as? Double,
           let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String {
            result["经度"] = String(format: "%f° %@", longitude, longitudeRef)
        }

        // 海拔
        if let altitude = gps[kCGImagePropertyGPSAltitude] as? Double {
            let ref = gps[kCGImagePropertyGPSAltitudeRef] as? Int32 ?? 0
            let unit = ref == 0 ? "米" : "海里以下"
            result["海拔"] = String(format: "%.1f %@", altitude, unit)
        }

        // GPS 时间戳
        if let dateStamp = gps[kCGImagePropertyGPSDateStamp] as? String {
            var gpsTime = dateStamp
            if let time = gps[kCGImagePropertyGPSTimeStamp] as? String {
                gpsTime += " " + time
            }
            result["GPS 时间"] = gpsTime
        }
    }

    /// 提取 IPTC 元数据
    private func extractIPTCMetadata(_ iptc: [CFString: Any], into result: inout [String: String]) {
        let mapping: [CFString: String] = [
            "IPTC/Headline" as CFString:         "IPTC 标题",
            "IPTC/Keywords" as CFString:         "IPTC 关键词",
            "IPTC/City" as CFString:             "城市",
            "IPTC/ProvinceState" as CFString:    "省/州",
            "IPTC/Country" as CFString:          "国家",
            "IPTC/CopyrightNotice" as CFString:  "IPTC 版权",
            "IPTC/ObjectName" as CFString:       "对象名称"
        ]

        for (key, label) in mapping {
            if let value = iptc[key] {
                result[label] = formatMetadataValue(value)
            }
        }
    }

    /// 格式化元数据值为字符串
    private func formatMetadataValue(_ value: Any) -> String {
        if let str = value as? String { return str }
        if let num = value as? Int { return "\(num)" }
        if let num = value as? Double { return String(format: "%.2f", num) }
        if let num = value as? Float { return String(format: "%.2f", num) }
        if let arr = value as? [Any] {
            return arr.compactMap { formatMetadataValue($0) }.joined(separator: ", ")
        }
        return "\(value)"
    }

    // MARK: - 条码/二维码检测

    /// 检测图片中的条码和二维码
    /// - Parameter url: 图片文件 URL
    /// - Returns: 条码检测结果数组
    /// - Throws: 检测失败错误
    func detectBarcodes(url: URL) async throws -> [BarcodeResult] {
        return await detectBarcodes(from: url)
    }

    /// 内部条码检测方法（不抛出错误，失败时返回空数组）
    private func detectBarcodes(from url: URL) async -> [BarcodeResult] {
        logger.debug("开始条码检测: \(url.lastPathComponent)")

        guard let cgImage = loadCGImage(from: url) else {
            logger.warning("无法加载图片用于条码检测: \(url.lastPathComponent)")
            return []
        }

        let request = VNDetectBarcodesRequest()
        request.symbologies = Self.supportedBarcodeSymbologies as [VNBarcodeSymbology]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            logger.error("条码检测请求失败: \(error.localizedDescription)")
            return []
        }

        guard let observations = request.results, !observations.isEmpty else {
            logger.debug("未检测到条码: \(url.lastPathComponent)")
            return []
        }

        let results: [BarcodeResult] = observations.compactMap { observation in
            guard let payloadString = observation.payloadStringValue else { return nil }

            let typeName: String
            switch observation.symbology {
            case .qr:     typeName = "QR"
            case .ean13:  typeName = "EAN-13"
            case .ean8:   typeName = "EAN-8"
            case .code128: typeName = "Code 128"
            case .pdf417: typeName = "PDF417"
            case .aztec:  typeName = "Aztec"
            case .upce:   typeName = "UPC-E"
            case .code39: typeName = "Code 39"
            case .code93: typeName = "Code 93"
            case .dataMatrix: typeName = "Data Matrix"
            case .itf14:  typeName = "ITF-14"
            default:      typeName = observation.symbology.rawValue
            }

            return BarcodeResult(
                type: typeName,
                value: payloadString,
                bounds: observation.boundingBox
            )
        }

        logger.info("条码检测完成，共检测到 \(results.count) 个条码")
        return results
    }

    // MARK: - 缩略图生成

    /// 生成图片缩略图
    /// - Parameters:
    ///   - url: 图片文件 URL
    ///   - maxSize: 缩略图最大尺寸（默认 200x200）
    /// - Returns: 缩略图 NSImage，失败时返回 nil
    func generateThumbnail(url: URL, maxSize: NSSize = NSSize(width: 200, height: 200)) -> NSImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            logger.warning("无法创建图片源以生成缩略图: \(url.lastPathComponent)")
            return nil
        }
        return generateThumbnail(from: imageSource, maxSize: maxSize)
    }

    /// 从 CGImageSource 生成缩略图
    /// - Parameters:
    ///   - imageSource: 图片源
    ///   - maxSize: 缩略图最大尺寸
    /// - Returns: 缩略图 NSImage，失败时返回 nil
    private func generateThumbnail(from imageSource: CGImageSource, maxSize: NSSize) -> NSImage? {
        // 计算缩略图尺寸（保持宽高比）
        let maxPixelSize = max(maxSize.width, maxSize.height)

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            logger.debug("缩略图生成失败")
            return nil
        }

        let nsImage = NSImage(cgImage: thumbnail, size: NSSize(width: thumbnail.width, height: thumbnail.height))
        return nsImage
    }

    // MARK: - 格式检测

    /// 检测图片格式
    /// - Parameter url: 图片文件 URL
    /// - Returns: 检测到的图片格式
    func detectFormat(url: URL) -> SupportedImageFormat {
        let pathExtension = url.pathExtension.lowercased()

        // 优先使用 UTType 检测
        if let utType = UTType(filenameExtension: pathExtension) {
            if utType.conforms(to: .png) { return .png }
            if utType.conforms(to: .jpeg) { return .jpeg }
            if utType.conforms(to: .webP) { return .webp }
            if utType.conforms(to: .gif) { return .gif }
            if utType.conforms(to: .bmp) { return .bmp }
            if utType.conforms(to: .tiff) { return .tiff }
            if utType.conforms(to: .heic) { return .heic }
            if utType.conforms(to: .heif) { return .heif }
            if utType.conforms(to: .ico) { return .ico }
            if utType.conforms(to: .svg) { return .svg }
        }

        // 回退到扩展名匹配
        return SupportedImageFormat.detect(from: pathExtension)
    }

    // MARK: - SVG 特殊处理

    /// 分析 SVG 文件（读取 XML 文本内容）
    /// - Parameters:
    ///   - url: SVG 文件 URL
    ///   - fileSize: 文件大小
    /// - Returns: 图片分析结果
    private func analyzeSVG(url: URL, fileSize: Int64) throws -> ImageAnalysisResult {
        logger.debug("分析 SVG 文件: \(url.lastPathComponent)")

        let svgContent = try String(contentsOf: url, encoding: .utf8)

        // 尝试从 SVG 中提取尺寸信息
        var width: CGFloat?
        var height: CGFloat?
        var viewBox: String?

        // 使用简单的字符串匹配提取 width/height/viewBox
        if let widthMatch = svgContent.range(of: #"<svg[^>]*\swidth\s*=\s*"([^"]+)""#, options: .regularExpression) {
            let substring = svgContent[widthMatch]
            if let valueMatch = substring.range(of: #""([^"]+)""#, options: .regularExpression) {
                let value = String(substring[valueMatch]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                width = CGFloat(Double(value.replacingOccurrences(of: "px", with: "")) ?? 0)
            }
        }

        if let heightMatch = svgContent.range(of: #"<svg[^>]*\sheight\s*=\s*"([^"]+)""#, options: .regularExpression) {
            let substring = svgContent[heightMatch]
            if let valueMatch = substring.range(of: #""([^"]+)""#, options: .regularExpression) {
                let value = String(substring[valueMatch]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                height = CGFloat(Double(value.replacingOccurrences(of: "px", with: "")) ?? 0)
            }
        }

        if let vbMatch = svgContent.range(of: #"<svg[^>]*\sviewBox\s*=\s*"([^"]+)""#, options: .regularExpression) {
            let substring = svgContent[vbMatch]
            if let valueMatch = substring.range(of: #""([^"]+)""#, options: .regularExpression) {
                viewBox = String(substring[valueMatch]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }

        // 如果没有明确的 width/height，尝试从 viewBox 解析
        if width == nil || height == nil, let vb = viewBox {
            let parts = vb.split(separator: " ").compactMap { Double($0) }
            if parts.count >= 4 {
                if width == nil { width = CGFloat(parts[2]) }
                if height == nil { height = CGFloat(parts[3]) }
            }
        }

        let dimensions: CGSize? = (width != nil && height != nil) ? CGSize(width: width!, height: height!) : nil

        var metadata: [String: String] = [:]
        metadata["类型"] = "SVG 矢量图"
        if let viewBox { metadata["ViewBox"] = viewBox }
        metadata["文件大小"] = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)

        return ImageAnalysisResult(
            format: .svg,
            dimensions: dimensions,
            colorSpace: "SVG（矢量）",
            ocrText: nil,
            ocrConfidence: nil,
            caption: nil,
            metadata: metadata,
            barcodes: [],
            thumbnail: nil,
            fileSize: fileSize
        )
    }

    // MARK: - 不支持格式的处理

    /// 处理系统不原生支持的格式（ICO / RAW）
    private func analyzeUnsupportedFormat(url: URL, format: SupportedImageFormat, fileSize: Int64) -> ImageAnalysisResult {
        var metadata: [String: String] = [:]
        metadata["类型"] = format.displayName
        metadata["文件大小"] = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        metadata["备注"] = "该格式不支持详细分析"

        return ImageAnalysisResult(
            format: format,
            dimensions: nil,
            colorSpace: nil,
            ocrText: nil,
            ocrConfidence: nil,
            caption: nil,
            metadata: metadata,
            barcodes: [],
            thumbnail: nil,
            fileSize: fileSize
        )
    }

    // MARK: - 辅助方法

    /// 加载 CGImage
    /// - Parameter url: 图片文件 URL
    /// - Returns: CGImage，失败时返回 nil
    private func loadCGImage(from url: URL) -> CGImage? {
        // 优先使用 CGImageSource（内存效率更高）
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            logger.warning("无法创建图片源: \(url.lastPathComponent)")
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false // 延迟解码以节省内存
        ]

        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) else {
            logger.warning("无法从图片源创建 CGImage: \(url.lastPathComponent)")
            return nil
        }

        return cgImage
    }

    /// 降低图片分辨率（处理大图片）
    /// - Parameters:
    ///   - image: 原始 CGImage
    ///   - maxDimension: 最大边长
    /// - Returns: 缩小后的 CGImage，失败时返回 nil
    private func downsample(image: CGImage, maxDimension: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        guard width > maxDimension || height > maxDimension else { return image }

        let scale = min(maxDimension / width, maxDimension / height)
        let newWidth = Int(width * scale)
        let newHeight = Int(height * scale)

        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            logger.warning("无法创建降采样位图上下文")
            return nil
        }

        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
        )

        return context.makeImage()
    }

    /// 提取图片尺寸
    /// - Parameter imageSource: 图片源
    /// - Returns: 图片尺寸，失败时返回 nil
    private func extractDimensions(from imageSource: CGImageSource) -> CGSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    /// 提取色彩空间描述
    /// - Parameter imageSource: 图片源
    /// - Returns: 色彩空间字符串，失败时返回 nil
    private func extractColorSpace(from imageSource: CGImageSource) -> String? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return nil
        }

        // 色彩模型
        if let colorModel = properties[kCGImagePropertyColorModel] as? String {
            return colorModel
        }

        // 从 CGImage 获取色彩空间名称
        if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
           let colorSpace = cgImage.colorSpace,
           let name = colorSpace.name {
            return name as String
        }

        return nil
    }

    /// 获取文件大小
    /// - Parameter url: 文件 URL
    /// - Returns: 文件大小（字节）
    private func getFileSize(url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return (attributes[.size] as? Int64) ?? 0
        } catch {
            logger.warning("无法获取文件大小: \(url.lastPathComponent)")
            return 0
        }
    }
}
