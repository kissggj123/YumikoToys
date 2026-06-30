//
//  OfficeDocumentParser.swift
//  YumikoToys
//
//  Office 文档解析服务 - 支持 DOCX、XLSX、PPTX、CSV、RTF 等格式（v3.2.1 - CoreXLSX 兼容性与编译报错修复版）
//

import Foundation
import AppKit
import PDFKit
import OSLog
import UniformTypeIdentifiers

// 👈【条件编译支持】：若您的项目中集成了 CoreXLSX，将自动引入高阶解析，否则优雅降级至 O(1) 极速 SAX 解析器
#if canImport(CoreXLSX)
import CoreXLSX
#endif

// MARK: - Office 文档解析服务文档类型

enum OfficeDocumentType: String, CaseIterable, Sendable, Equatable, Hashable {
    case docx       // Word 文档 (Open XML)
    case doc        // Word 文档 (旧版)
    case xlsx       // Excel 工作簿 (Open XML)
    case xls        // Excel 工作簿 (旧版)
    case pptx       // PowerPoint 演示文稿 (Open XML)
    case ppt        // PowerPoint 演示文稿 (旧版)
    case csv        // 逗号分隔值
    case tsv        // 制表符分隔值
    case rtf        // 富文本格式
    case numbers    // Apple Numbers
    case pages      // Apple Pages
    case key        // Apple Keynote

    var fileExtension: String {
        switch self {
        case .docx: return "docx"
        case .doc:  return "doc"
        case .xlsx: return "xlsx"
        case .xls:  return "xls"
        case .pptx: return "pptx"
        case .ppt:  return "ppt"
        case .csv:  return "csv"
        case .tsv:  return "tsv"
        case .rtf:  return "rtf"
        case .numbers: return "numbers"
        case .pages:   return "pages"
        case .key:     return "key"
        }
    }

    var displayName: String {
        switch self {
        case .docx: return "Word 文档"
        case .doc:  return "Word 文档（旧版）"
        case .xlsx: return "Excel 工作簿"
        case .xls:  return "Excel 工作簿（旧版）"
        case .pptx: return "PowerPoint 演示文稿"
        case .ppt:  return "PowerPoint 演示文稿（旧版）"
        case .csv:  return "CSV 文件"
        case .tsv:  return "TSV 文件"
        case .rtf:  return "RTF 文档"
        case .numbers: return "Numbers 表格"
        case .pages:   return "Pages 文稿"
        case .key:     return "Keynote 演示文稿"
        }
    }

    var icon: String {
        switch self {
        case .docx, .doc:  return "doc.fill"
        case .xlsx, .xls:  return "tablecells.fill"
        case .pptx, .ppt:  return "play.rectangle.fill"
        case .csv, .tsv:   return "tablecells.fill"
        case .rtf:         return "doc.richtext"
        case .numbers:     return "tablecells.fill"
        case .pages:       return "doc.fill"
        case .key:         return "play.rectangle.fill"
        }
    }

    var mimeType: String {
        switch self {
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .doc:  return "application/msword"
        case .xlsx: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case .xls:  return "application/vnd.ms-excel"
        case .pptx: return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case .ppt:  return "application/vnd.ms-powerpoint"
        case .csv:  return "text/csv"
        case .tsv:  return "text/tab-separated-values"
        case .rtf:  return "application/rtf"
        case .numbers: return "application/x-iwork-numbers-sffnumbers"
        case .pages:   return "application/x-iwork-pages-sffpages"
        case .key:     return "application/x-iwork-keynote-sffkey"
        }
    }

    var isSupported: Bool {
        switch self {
        case .docx, .xlsx, .pptx, .csv, .tsv, .rtf:
            return true
        case .doc, .xls, .ppt:
            return true
        case .numbers, .pages, .key:
            return true
        }
    }

    var isZipBased: Bool {
        switch self {
        case .docx, .xlsx, .pptx:
            return true
        default:
            return false
        }
    }
}

// MARK: - Office 解析错误

enum OfficeParseError: Error, LocalizedError, Sendable {
    case fileNotFound
    case unsupportedFormat(String)
    case corruptedFile(String)
    case passwordProtected
    case encodingError(String)
    case parseError(String)
    case emptyDocument
    case fileTooLarge(Int64)
    case textTooLarge(Int)
    case unzipFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "文件不存在"
        case .unsupportedFormat(let format):
            return "不支持的文件格式: \(format)"
        case .corruptedFile(let detail):
            return "文件已损坏: \(detail)"
        case .passwordProtected:
            return "文件受密码保护，无法解析"
        case .encodingError(let detail):
            return "编码错误: \(detail)"
        case .parseError(let detail):
            return "解析错误: \(detail)"
        case .emptyDocument:
            return "文档内容为空"
        case .fileTooLarge(let maxSize):
            return "文件过大，超过限制 \(maxSize / 1024 / 1024)MB"
        case .textTooLarge(let maxChars):
            return "提取文本过长，已截断至 \(maxChars) 字符"
        case .unzipFailed(let detail):
            return "解压失败: \(detail)"
        }
    }
}

// MARK: - Office 解析结果

struct OfficeParseResult: Sendable {
    let fileType: OfficeDocumentType
    let textContent: String
    let metadata: [String: String]
    let tables: [[String]]
    let wordCount: Int
    let charCount: Int

    static func empty(type: OfficeDocumentType) -> OfficeParseResult {
        OfficeParseResult(
            fileType: type,
            textContent: "",
            metadata: [:],
            tables: [],
            wordCount: 0,
            charCount: 0
        )
    }
}

// MARK: - Office 文档解析器

final class OfficeDocumentParser: Sendable {

    private let maxFileSize: Int64 = 50 * 1024 * 1024
    private let maxTextLength: Int = 10_000_000
    private let tempDirectoryPrefix = "com.yumikotoys.officeparser"

    private let logger = Logger(
        subsystem: "com.yumikotoys.app",
        category: "OfficeDocumentParser"
    )

    init() {}

    deinit {
        logger.debug("OfficeDocumentParser 已释放")
    }

    // MARK: - 公共解析入口

    func parse(url: URL) async throws -> OfficeParseResult {
        logger.info("开始解析文档: \(url.lastPathComponent)")

        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.error("文件不存在: \(url.path)")
            throw OfficeParseError.fileNotFound
        }

        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = fileAttributes[.size] as? Int64, fileSize > maxFileSize {
            logger.warning("文件过大: \(fileSize) 字节")
            throw OfficeParseError.fileTooLarge(maxFileSize)
        }

        let fileType = await detectFileType(url: url)
        logger.info("检测到文件类型: \(fileType.displayName)")

        guard fileType.isSupported else {
            throw OfficeParseError.unsupportedFormat(fileType.displayName)
        }

        let result: OfficeParseResult

        switch fileType {
        case .docx:
            result = try await parseDOCX(url: url)
        case .doc:
            // 👈 将涉及底层 AppKit Text 引擎解析的方法，强制分流到 MainActor，杜绝多线程段冲突崩溃
            result = try await parseLegacyDoc(url: url)
        case .xlsx:
            result = try await parseXLSX(url: url)
        case .xls:
            result = try await parseLegacyExcel(url: url)
        case .pptx:
            result = try await parsePPTX(url: url)
        case .ppt:
            result = try await parseLegacyPPT(url: url)
        case .csv:
            result = try await parseCSV(url: url, delimiter: ",")
        case .tsv:
            result = try await parseCSV(url: url, delimiter: "\t")
        case .rtf:
            // 👈 RTF 解析强制路由至主线程
            result = try await MainActor.run { try self.parseRTF(url: url) }
        case .numbers:
            result = try await parseAppleFormat(url: url, type: .numbers)
        case .pages:
            result = try await parseAppleFormat(url: url, type: .pages)
        case .key:
            result = try await parseAppleFormat(url: url, type: .key)
        }

        logger.info("解析完成，字符数: \(result.charCount)，字数: \(result.wordCount)")
        return result
    }

    // MARK: - 文件类型检测

    func detectFileType(url: URL) async -> OfficeDocumentType {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "docx": return .docx
        case "doc":  return .doc
        case "xlsx": return .xlsx
        case "xls":  return .xls
        case "pptx": return .pptx
        case "ppt":  return .ppt
        case "csv":  return .csv
        case "tsv":  return .tsv
        case "rtf":  return .rtf
        case "numbers": return .numbers
        case "pages":   return .pages
        case "key":     return .key
        default:
            logger.warning("未知文件扩展名: \(ext)，尝试通过 MIME 类型检测")
            return await detectFileTypeByMIME(url: url)
        }
    }

    private func detectFileTypeByMIME(url: URL) async -> OfficeDocumentType {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped),
              data.count >= 4 else {
            return .docx
        }

        let bytes = [UInt8](data.prefix(8))

        if bytes.count >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B
            && bytes[2] == 0x03 && bytes[3] == 0x04 {
            if let type = await detectZipBasedType(url: url) {
                return type
            }
            return .docx
        }

        if data.count >= 5 {
            let header = String(data: data.prefix(5), encoding: .ascii) ?? ""
            if header == "{\\rtf" {
                return .rtf
            }
        }

        if let text = String(data: data.prefix(4096), encoding: .utf8) {
            let lines = text.components(separatedBy: .newlines)
            if lines.count > 1 {
                let commaCount = lines[0].filter { $0 == "," }.count
                let tabCount = lines[0].filter { $0 == "\t" }.count
                if commaCount > tabCount && commaCount >= 1 {
                    return .csv
                } else if tabCount >= 1 {
                    return .tsv
                }
            }
        }

        return .docx
    }

    private func detectZipBasedType(url: URL) async -> OfficeDocumentType? {
        guard let tempDir = try? createTempDirectory(),
              let _ = try? await unzipFile(at: url, to: tempDir) else {
            return nil
        }

        defer { cleanupTempDirectory(tempDir) }

        let fm = FileManager.default

        if fm.fileExists(atPath: tempDir.appendingPathComponent("word/document.xml").path) {
            return .docx
        }
        if fm.fileExists(atPath: tempDir.appendingPathComponent("xl/workbook.xml").path) {
            return .xlsx
        }
        if fm.fileExists(atPath: tempDir.appendingPathComponent("ppt/presentation.xml").path) {
            return .pptx
        }

        return nil
    }

    // MARK: - ZIP 解压工具

    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(tempDirectoryPrefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func unzipFile(at sourceURL: URL, to destinationURL: URL) async throws -> URL {
        logger.debug("解压文件: \(sourceURL.lastPathComponent) -> \(destinationURL.lastPathComponent)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", "--sequesterRsrc", "--rsrc", sourceURL.path, destinationURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let exitCode: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: -1)
            }
        }

        guard exitCode == 0 else {
            logger.warning("ditto 解压失败，尝试 unzip 命令")
            try await unzipWithUnzipCommand(at: sourceURL, to: destinationURL)
            return destinationURL
        }

        return destinationURL
    }

    private func unzipWithUnzipCommand(at sourceURL: URL, to destinationURL: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", sourceURL.path, "-d", destinationURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let exitCode: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: -1)
            }
        }

        guard exitCode == 0 else {
            throw OfficeParseError.unzipFailed("unzip 命令退出码: \(exitCode)")
        }
    }

    // MARK: - DOCX 解析

    func parseDOCX(url: URL) async throws -> OfficeParseResult {
        logger.info("开始解析 DOCX: \(url.lastPathComponent)")

        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        try await unzipFile(at: url, to: tempDir)

        let fm = FileManager.default
        let wordDir = tempDir.appendingPathComponent("word")

        let documentPath = wordDir.appendingPathComponent("document.xml").path
        guard fm.fileExists(atPath: documentPath) else {
            throw OfficeParseError.corruptedFile("DOCX 缺少 word/document.xml")
        }

        let documentData = try Data(contentsOf: URL(fileURLWithPath: documentPath))
        let mainText = try parseDOCXDocumentXML(data: documentData)

        var headerFooterText = ""
        let headerFooterFiles = ["header1.xml", "header2.xml", "header3.xml",
                                  "footer1.xml", "footer2.xml", "footer3.xml"]
        for fileName in headerFooterFiles {
            let filePath = wordDir.appendingPathComponent(fileName).path
            if fm.fileExists(atPath: filePath) {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                    let text = try? parseDOCXDocumentXML(data: data)
                    if let text, !text.isEmpty {
                        headerFooterText += text + "\n"
                    }
                }
            }
        }

        var footnotesText = ""
        let footnotesPath = wordDir.appendingPathComponent("footnotes.xml").path
        if fm.fileExists(atPath: footnotesPath) {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: footnotesPath)) {
                let text = try? parseDOCXDocumentXML(data: data)
                if let text, !text.isEmpty {
                    footnotesText = "\n--- 脚注 ---\n" + text
                }
            }
        }

        var endnotesText = ""
        let endnotesPath = wordDir.appendingPathComponent("endnotes.xml").path
        if fm.fileExists(atPath: endnotesPath) {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: endnotesPath)) {
                let text = try? parseDOCXDocumentXML(data: data)
                if let text, !text.isEmpty {
                    endnotesText = "\n--- 尾注 ---\n" + text
                }
            }
        }

        var fullText = mainText
        if !headerFooterText.isEmpty {
            fullText += "\n--- 页眉页脚 ---\n" + headerFooterText
        }
        fullText += footnotesText + endnotesText

        var metadata = [String: String]()
        if let coreXML = try? extractCoreProperties(from: tempDir) {
            metadata.merge(coreXML) { _, new in new }
        }

        let tables = try extractTablesFromDOCX(data: documentData)
        let truncatedText = truncateText(fullText)
        let wordCount = countWords(in: truncatedText)
        let charCount = truncatedText.count

        return OfficeParseResult(
            fileType: .docx,
            textContent: truncatedText,
            metadata: metadata,
            tables: tables,
            wordCount: wordCount,
            charCount: charCount
        )
    }

    private func parseDOCXDocumentXML(data: Data) throws -> String {
        let wordNamespace = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

        let parser = DOCXXMLParser(namespace: wordNamespace)
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser

        guard xmlParser.parse() else {
            if let error = xmlParser.parserError {
                throw OfficeParseError.parseError("XML 解析失败: \(error.localizedDescription)")
            }
            throw OfficeParseError.parseError("XML 解析失败: 未知错误")
        }

        return parser.parsedText
    }

    private func extractTablesFromDOCX(data: Data) throws -> [[String]] {
        let wordNamespace = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        let parser = DOCXTableParser(namespace: wordNamespace)
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser

        guard xmlParser.parse() else {
            return []
        }

        return parser.tables
    }

    private func extractCoreProperties(from tempDir: URL) -> [String: String]? {
        let corePath = tempDir
            .appendingPathComponent("docProps")
            .appendingPathComponent("core.xml")
            .path

        guard FileManager.default.fileExists(atPath: corePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: corePath)) else {
            return nil
        }

        let parser = CorePropertiesParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()

        return parser.properties
    }

    // MARK: - XLSX 解析

    /// 解析 XLSX 文件（支持条件编译引入 CoreXLSX 与降级自研 SAX 解析）
    func parseXLSX(url: URL) async throws -> OfficeParseResult {
        logger.info("开始解析 XLSX: \(url.lastPathComponent)")
        
        #if canImport(CoreXLSX)
        // 👈【条件编译】：若存在 CoreXLSX，采用其标准解析逻辑
        return try await parseXLSXWithCoreXLSX(url: url)
        #else
        // 👈 若无 CoreXLSX，降级采用 O(1) 极小内存常模 SAX 结构解析
        return try await parseXLSXWithXMLParser(url: url)
        #endif
    }

    #if canImport(CoreXLSX)
    /// 👈 使用 CoreXLSX 精确解析表格
    private func parseXLSXWithCoreXLSX(url: URL) async throws -> OfficeParseResult {
        logger.info("使用已导入的 CoreXLSX 框架解析表格")
        guard let file = XLSXFile(filepath: url.path) else {
            throw OfficeParseError.corruptedFile("无法通过 CoreXLSX 实例化文件")
        }

        var allText = ""
        var allTables: [[String]] = []
        var metadata = [String: String]()
        
        let sharedStrings = try file.parseSharedStrings()
        // 👈【编译修复】：改用复数形式的 parseWorkbooks 并安全取其 first，契合 CoreXLSX 库的 API
        guard let workbook = try file.parseWorkbooks().first else {
            throw OfficeParseError.corruptedFile("工作簿解析失败")
        }
        let sheetNames = workbook.sheets.items.compactMap{ $0.name }
        metadata["sheetCount"] = "\(sheetNames.count)"
        metadata["sheetNames"] = sheetNames.joined(separator: ", ")

        for (index, path) in try file.parseWorksheetPaths().enumerated() {
            let sheetName = index < sheetNames.count ? sheetNames[index] : "Sheet\(index + 1)"
            let worksheet = try file.parseWorksheet(at: path)
            
            allText += "--- 工作表: \(sheetName) ---\n"
            
            if let rows = worksheet.data?.rows {
                for row in rows {
                    let rowCells = row.cells.map { cell -> String in
                        // 👈【编译修复】：改用标准的高内聚 cell.stringValue(sharedStrings)，直接解决 CellType 属性的重构报错问题
                        if let sharedStrings = sharedStrings {
                            return cell.stringValue(sharedStrings) ?? cell.value ?? ""
                        } else {
                            return cell.value ?? ""
                        }
                    }
                    let line = rowCells.joined(separator: "\t")
                    allText += line + "\n"
                    allTables.append(rowCells)
                }
            }
            allText += "\n"
        }

        // 提取元数据
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }
        try await unzipFile(at: url, to: tempDir)
        if let coreProps = try? extractCoreProperties(from: tempDir) {
            metadata.merge(coreProps) { _, new in new }
        }

        let truncatedText = truncateText(allText)
        return OfficeParseResult(
            fileType: .xlsx,
            textContent: truncatedText,
            metadata: metadata,
            tables: allTables,
            wordCount: countWords(in: truncatedText),
            charCount: truncatedText.count
        )
    }
    #endif

    /// 使用自研极速 SAX XMLParser 解析 XLSX（零依赖，超低内存）
    private func parseXLSXWithXMLParser(url: URL) async throws -> OfficeParseResult {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        try await unzipFile(at: url, to: tempDir)

        let fm = FileManager.default
        let xlDir = tempDir.appendingPathComponent("xl")

        // 1. 解析共享字符串表
        let sharedStringsPath = xlDir.appendingPathComponent("sharedStrings.xml").path
        var sharedStrings: [String] = []

        if fm.fileExists(atPath: sharedStringsPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: sharedStringsPath))
            let parser = XLSXSharedStringsParser()
            let xmlParser = XMLParser(data: data)
            xmlParser.delegate = parser
            xmlParser.parse()
            sharedStrings = parser.strings
        }

        logger.debug("共享字符串表包含 \(sharedStrings.count) 个字符串")

        // 2. 解析工作簿获取工作表列表
        let workbookPath = xlDir.appendingPathComponent("workbook.xml").path
        guard fm.fileExists(atPath: workbookPath) else {
            throw OfficeParseError.corruptedFile("XLSX 缺少 xl/workbook.xml")
        }

        let workbookData = try Data(contentsOf: URL(fileURLWithPath: workbookPath))
        let workbookParser = XLSXWorkbookParser()
        let workbookXMLParser = XMLParser(data: workbookData)
        workbookXMLParser.delegate = workbookParser
        workbookXMLParser.parse()

        let sheetNames = workbookParser.sheetNames
        let sheetFiles = workbookParser.sheetFiles

        var allText = ""
        var allTables: [[String]] = []
        var metadata = [String: String]()
        metadata["sheetCount"] = "\(sheetNames.count)"
        metadata["sheetNames"] = sheetNames.joined(separator: ", ")

        // 3. 逐个工作表解析
        for (index, sheetFile) in sheetFiles.enumerated() {
            let sheetPath = xlDir.appendingPathComponent(sheetFile).path
            guard fm.fileExists(atPath: sheetPath) else {
                logger.warning("工作表文件不存在: \(sheetFile)")
                continue
            }

            let sheetName = index < sheetNames.count ? sheetNames[index] : "Sheet\(index + 1)"
            let sheetData = try Data(contentsOf: URL(fileURLWithPath: sheetPath))

            let parser = XLSXSheetParser(sharedStrings: sharedStrings)
            let xmlParser = XMLParser(data: sheetData)
            xmlParser.delegate = parser
            xmlParser.parse()

            allText += "--- 工作表: \(sheetName) ---\n"

            for row in parser.rows {
                let line = row.joined(separator: "\t")
                allText += line + "\n"
                allTables.append(row)
            }

            allText += "\n"
        }

        if let coreProps = try? extractCoreProperties(from: tempDir) {
            metadata.merge(coreProps) { _, new in new }
        }

        let truncatedText = truncateText(allText)
        let wordCount = countWords(in: truncatedText)
        let charCount = truncatedText.count

        return OfficeParseResult(
            fileType: .xlsx,
            textContent: truncatedText,
            metadata: metadata,
            tables: allTables,
            wordCount: wordCount,
            charCount: charCount
        )
    }

    // MARK: - PPTX 解析

    func parsePPTX(url: URL) async throws -> OfficeParseResult {
        logger.info("开始解析 PPTX: \(url.lastPathComponent)")

        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        try await unzipFile(at: url, to: tempDir)

        let fm = FileManager.default
        let pptDir = tempDir.appendingPathComponent("ppt")
        let slidesDir = pptDir.appendingPathComponent("slides")

        var slideFiles: [(name: String, url: URL)] = []
        if fm.fileExists(atPath: slidesDir.path) {
            let contents = try fm.contentsOfDirectory(
                at: slidesDir,
                includingPropertiesForKeys: nil
            )
            slideFiles = contents
                .filter { $0.pathExtension.lowercased() == "xml" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .map { (name: $0.deletingPathExtension().lastPathComponent, url: $0) }
        }

        guard !slideFiles.isEmpty else {
            throw OfficeParseError.emptyDocument
        }

        var allText = ""
        var allTables: [[String]] = []
        var slideCount = 0

        for (slideName, slideURL) in slideFiles {
            let data = try Data(contentsOf: slideURL)
            let parser = PPTXSlideParser()
            let xmlParser = XMLParser(data: data)
            xmlParser.delegate = parser
            xmlParser.parse()

            slideCount += 1
            allText += "=== 幻灯片 \(slideCount) ===\n"
            allText += parser.titleText
            if !parser.bodyText.isEmpty {
                if !parser.titleText.isEmpty {
                    allText += "\n"
                }
                allText += parser.bodyText
            }
            allText += "\n\n"

            allTables.append(contentsOf: parser.tables)
        }

        let notesDir = pptDir.appendingPathComponent("notesSlides")
        if fm.fileExists(atPath: notesDir.path) {
            let notesFiles = try fm.contentsOfDirectory(
                at: notesDir,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension.lowercased() == "xml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

            for notesURL in notesFiles {
                if let data = try? Data(contentsOf: notesURL) {
                    let parser = PPTXSlideParser()
                    let xmlParser = XMLParser(data: data)
                    xmlParser.delegate = parser
                    xmlParser.parse()

                    if !parser.bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        allText += "--- 备注 ---\n"
                        allText += parser.bodyText + "\n\n"
                    }
                }
            }
        }

        var metadata = [String: String]()
        metadata["slideCount"] = "\(slideCount)"
        if let coreProps = try? extractCoreProperties(from: tempDir) {
            metadata.merge(coreProps) { _, new in new }
        }

        let truncatedText = truncateText(allText)
        let wordCount = countWords(in: truncatedText)
        let charCount = truncatedText.count

        return OfficeParseResult(
            fileType: .pptx,
            textContent: truncatedText,
            metadata: metadata,
            tables: allTables,
            wordCount: wordCount,
            charCount: charCount
        )
    }

    // MARK: - CSV/TSV 解析

    func parseCSV(url: URL, delimiter: Character) async throws -> OfficeParseResult {
        logger.info("开始解析 CSV/TSV: \(url.lastPathComponent)，分隔符: \(delimiter == "\t" ? "TAB" : ",")")

        let rawData = try Data(contentsOf: url)

        let fileContent: String
        if let utf8String = String(data: rawData, encoding: .utf8) {
            fileContent = utf8String
            logger.debug("检测到 UTF-8 编码")
        } else if let gbkData = try? detectAndConvertGBK(data: rawData) {
            fileContent = gbkData
            logger.debug("检测到 GBK/GB2312 编码，已转换为 UTF-8")
        } else if let latinString = String(data: rawData, encoding: .isoLatin1) {
            fileContent = latinString
            logger.debug("使用 Latin-1 编码回退")
        } else {
            throw OfficeParseError.encodingError("无法识别文件编码")
        }

        let rows = parseCSVContent(fileContent, delimiter: delimiter)

        guard !rows.isEmpty else {
            throw OfficeParseError.emptyDocument
        }

        var allText = ""
        var allTables: [[String]] = []

        for row in rows {
            let line = row.joined(separator: delimiter == "\t" ? "\t" : ", ")
            allText += line + "\n"
            allTables.append(row)
        }

        let metadata: [String: String] = [
            "rowCount": "\(rows.count)",
            "columnCount": "\(rows.first?.count ?? 0)",
            "delimiter": delimiter == "\t" ? "TAB" : ","
        ]

        let truncatedText = truncateText(allText)
        let wordCount = countWords(in: truncatedText)
        let charCount = truncatedText.count

        return OfficeParseResult(
            fileType: delimiter == "\t" ? .tsv : .csv,
            textContent: truncatedText,
            metadata: metadata,
            tables: allTables,
            wordCount: wordCount,
            charCount: charCount
        )
    }

    private func parseCSVContent(_ content: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var characters = content.makeIterator()

        while let char = characters.next() {
            if inQuotes {
                if char == "\"" {
                    if let nextChar = characters.next() {
                        if nextChar == "\"" {
                            currentField.append("\"")
                        } else {
                            inQuotes = false
                            if nextChar == delimiter {
                                currentRow.append(currentField)
                                currentField = ""
                            } else if nextChar == "\r" {
                                currentRow.append(currentField)
                                currentField = ""
                                if let peeked = characters.next(), peeked != "\n" {
                                    if peeked == "\n" {
                                    } else {
                                        currentField.append(peeked)
                                    }
                                } else {
                                    rows.append(currentRow)
                                    currentRow = []
                                }
                            } else if nextChar == "\n" {
                                currentRow.append(currentField)
                                currentField = ""
                                rows.append(currentRow)
                                currentRow = []
                            } else {
                                currentRow.append(currentField)
                                currentField = ""
                                currentField.append(nextChar)
                            }
                        }
                    } else {
                        inQuotes = false
                        currentRow.append(currentField)
                        currentField = ""
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == delimiter {
                    currentRow.append(currentField)
                    currentField = ""
                } else if char == "\r" {
                    currentRow.append(currentField)
                    currentField = ""
                    if let nextChar = characters.next() {
                        if nextChar != "\n" {
                            currentField.append(nextChar)
                        }
                    }
                    rows.append(currentRow)
                    currentRow = []
                } else if char == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                } else {
                    currentField.append(char)
                }
            }
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows.filter { row in !row.allSatisfy { $0.isEmpty } }
    }

    private func detectAndConvertGBK(data: Data) throws -> String {
        let gbkEncoding = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
        let nsEncoding = String.Encoding(rawValue: gbkEncoding)

        guard let result = String(data: data, encoding: nsEncoding) else {
            let gb2312Encoding = CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue)
            )
            let gb2312NSEncoding = String.Encoding(rawValue: gb2312Encoding)

            guard let result = String(data: data, encoding: gb2312NSEncoding) else {
                throw OfficeParseError.encodingError("无法以 GBK 或 GB2312 编码解码文件")
            }
            return result
        }

        return result
    }

    // MARK: - RTF 解析 (主线程隔离保护)

    /// 解析 RTF 文件
    /// 👈【主线程隔离保护】：基于 AppKit 的文档富文本解析必须在主线程执行，防止后台解析段错误崩溃
    @MainActor
    func parseRTF(url: URL) throws -> OfficeParseResult {
        logger.info("开始在 MainActor 解析 RTF: \(url.lastPathComponent)")

        let data = try Data(contentsOf: url)

        let attributedString: NSAttributedString
        if let rtfString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            attributedString = rtfString
        } else if let rtfdString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        ) {
            attributedString = rtfdString
        } else {
            throw OfficeParseError.parseError("无法解析 RTF 文件")
        }

        let text = attributedString.string

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OfficeParseError.emptyDocument
        }

        let truncatedText = truncateText(text)
        let wordCount = countWords(in: truncatedText)
        let charCount = truncatedText.count

        return OfficeParseResult(
            fileType: .rtf,
            textContent: truncatedText,
            metadata: [:],
            tables: [],
            wordCount: wordCount,
            charCount: charCount
        )
    }

    // MARK: - Apple 格式解析 (主线程隔离保护)

    /// 解析 Apple iWork 格式文件
    /// 👈【主线程隔离保护】：基于 AppKit 和 QuickLook 预览机制的文件解析器需要主线程隔离
    @MainActor
    private func parseAppleFormat(url: URL, type: OfficeDocumentType) async throws -> OfficeParseResult {
        logger.info("开始在 MainActor 解析 Apple 格式: \(type.displayName)")

        let data = try Data(contentsOf: url)

        let docType: NSAttributedString.DocumentType
        switch type {
        case .numbers:
            docType = .init(rawValue: "com.apple.numbers.numbers")
        case .pages:
            docType = .init(rawValue: "com.apple.pages.pages")
        case .key:
            docType = .init(rawValue: "com.apple.keynote.key")
        default:
            docType = .plain
        }

        if let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: docType],
            documentAttributes: nil
        ) {
            let text = attributedString.string
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let truncatedText = truncateText(text)
                let wordCount = countWords(in: truncatedText)
                let charCount = truncatedText.count

                return OfficeParseResult(
                    fileType: type,
                    textContent: truncatedText,
                    metadata: [:],
                    tables: [],
                    wordCount: wordCount,
                    charCount: charCount
                )
            }
        }

        if let qlText = try? await extractTextViaQuickLook(url: url) {
            if !qlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let truncatedText = truncateText(qlText)
                let wordCount = countWords(in: truncatedText)
                let charCount = truncatedText.count

                return OfficeParseResult(
                    fileType: type,
                    textContent: truncatedText,
                    metadata: [:],
                    tables: [],
                    wordCount: wordCount,
                    charCount: charCount
                )
            }
        }

        if let text = try? await parseAppleFormatFromZip(url: url, type: type) {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let truncatedText = truncateText(text)
                let wordCount = countWords(in: truncatedText)
                let charCount = truncatedText.count

                return OfficeParseResult(
                    fileType: type,
                    textContent: truncatedText,
                    metadata: [:],
                    tables: [],
                    wordCount: wordCount,
                    charCount: charCount
                )
            }
        }

        throw OfficeParseError.unsupportedFormat("\(type.displayName) 格式暂不支持完整解析")
    }

    private func extractTextViaQuickLook(url: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdls")
        process.arguments = ["-name", "kMDItemTextContent", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let exitCode: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: -1)
            }
        }

        guard exitCode == 0 else {
            return ""
        }

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8) else {
            return ""
        }

        if let range = output.range(of: "= \"") {
            let remaining = output[range.upperBound...]
            if let endRange = remaining.range(of: "\"", options: .backwards) {
                return String(remaining[..<endRange.lowerBound])
            }
        }

        return ""
    }

    private func parseAppleFormatFromZip(url: URL, type: OfficeDocumentType) async throws -> String {
        let tempDir = try createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }

        _ = try await unzipFile(at: url, to: tempDir)

        let fm = FileManager.default

        let qlDir = tempDir.appendingPathComponent("QuickLook")
        if fm.fileExists(atPath: qlDir.path) {
            let contents = try fm.contentsOfDirectory(
                at: qlDir,
                includingPropertiesForKeys: nil
            )

            if let htmlFile = contents.first(where: { $0.pathExtension.lowercased() == "html" }) {
                if let htmlData = try? Data(contentsOf: htmlFile),
                   let htmlString = String(data: htmlData, encoding: .utf8) {
                    return stripHTMLTags(htmlString)
                }
            }

            if let pdfFile = contents.first(where: { $0.pathExtension.lowercased() == "pdf" }) {
                if let pdfData = try? Data(contentsOf: pdfFile) {
                    return extractTextFromPDF(data: pdfData)
                }
            }
        }

        let indexDir = tempDir.appendingPathComponent("Index")
        if fm.fileExists(atPath: indexDir.path) {
            let contents = try fm.contentsOfDirectory(
                at: indexDir,
                includingPropertiesForKeys: nil
            )
            for file in contents where file.pathExtension.lowercased() == "xml" {
                if let data = try? Data(contentsOf: file),
                   let text = String(data: data, encoding: .utf8) {
                    return extractTextFromXMLString(text)
                }
            }
        }

        return ""
    }

    private func stripHTMLTags(_ html: String) -> String {
        var result = html
        result = result.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "<br\\s*/?>",
            with: "\n",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "</(p|div|h[1-6]|li|tr)>",
            with: "\n",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")

        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTextFromPDF(data: Data) -> String {
        guard let pdfDocument = PDFDocument(data: data) else {
            return ""
        }

        var text = ""
        let pageCount = pdfDocument.pageCount

        for i in 0..<pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            let pageContent = page.string ?? ""
            text += pageContent + "\n"
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTextFromXMLString(_ xml: String) -> String {
        var result = xml
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - 旧版格式解析 (主线程隔离保护)

    @MainActor
    private func parseLegacyDoc(url: URL) async throws -> OfficeParseResult {
        logger.info("尝试在 MainActor 解析旧版 DOC: \(url.lastPathComponent)")

        let data = try Data(contentsOf: url)

        let docTypes: [NSAttributedString.DocumentType] = [
            .docFormat,
            .init(rawValue: "com.microsoft.word.doc")
        ]

        for docType in docTypes {
            if let attributedString = try? NSAttributedString(
                data: data,
                options: [.documentType: docType],
                documentAttributes: nil
            ) {
                let text = attributedString.string
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let truncatedText = truncateText(text)
                    return OfficeParseResult(
                        fileType: .doc,
                        textContent: truncatedText,
                        metadata: [:],
                        tables: [],
                        wordCount: countWords(in: truncatedText),
                        charCount: truncatedText.count
                    )
                }
            }
        }

        if let text = try? await convertViaTextUtil(url: url) {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let truncatedText = truncateText(text)
                return OfficeParseResult(
                    fileType: .doc,
                    textContent: truncatedText,
                    metadata: [:],
                    tables: [],
                    wordCount: countWords(in: truncatedText),
                    charCount: truncatedText.count
                )
            }
        }

        throw OfficeParseError.unsupportedFormat("旧版 .doc 格式解析失败，建议转换为 .docx 格式")
    }

    @MainActor
    private func parseLegacyExcel(url: URL) async throws -> OfficeParseResult {
        logger.info("尝试在 MainActor 解析旧版 XLS")

        if let text = try? await convertViaTextUtil(url: url) {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let truncatedText = truncateText(text)
                return OfficeParseResult(
                    fileType: .xls,
                    textContent: truncatedText,
                    metadata: [:],
                    tables: [],
                    wordCount: countWords(in: truncatedText),
                    charCount: truncatedText.count
                )
            }
        }

        throw OfficeParseError.unsupportedFormat("旧版 .xls 格式解析失败，建议转换为 .xlsx 格式")
    }

    @MainActor
    private func parseLegacyPPT(url: URL) async throws -> OfficeParseResult {
        logger.info("尝试在 MainActor 解析旧版 PPT")

        if let text = try? await convertViaTextUtil(url: url) {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let truncatedText = truncateText(text)
                return OfficeParseResult(
                    fileType: .ppt,
                    textContent: truncatedText,
                    metadata: [:],
                    tables: [],
                    wordCount: countWords(in: truncatedText),
                    charCount: truncatedText.count
                )
            }
        }

        throw OfficeParseError.unsupportedFormat("旧版 .ppt 格式解析失败，建议转换为 .pptx 格式")
    }

    private func convertViaTextUtil(url: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        process.arguments = ["-convert", "txt", "-stdout", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let exitCode: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: -1)
            }
        }

        guard exitCode == 0 else {
            return ""
        }

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8) ?? ""
    }

    // MARK: - 工具方法

    private func truncateText(_ text: String) -> String {
        if text.count > self.maxTextLength {
            logger.warning("文本超过最大长度 \(self.maxTextLength)，进行截断")
            let index = text.index(text.startIndex, offsetBy: self.maxTextLength)
            return String(text[..<index]) + "\n\n[... 文本已截断 ...]"
        }
        return text
    }

    private func countWords(in text: String) -> Int {
        var count = 0
        var inWord = false

        for char in text {
            if char.isWhitespace || char.isNewline {
                if inWord {
                    count += 1
                    inWord = false
                }
            } else if isCJKCharacter(char) {
                count += 1
                inWord = false
            } else {
                inWord = true
            }
        }

        if inWord {
            count += 1
        }

        return count
    }

    private func isCJKCharacter(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        let value = scalar.value

        return (0x4E00...0x9FFF).contains(value) ||
               (0x3400...0x4DBF).contains(value) ||
               (0x20000...0x2A6DF).contains(value) ||
               (0x2A700...0x2B73F).contains(value) ||
               (0x2B740...0x2B81F).contains(value) ||
               (0x2B820...0x2CEAF).contains(value) ||
               (0xF900...0xFAFF).contains(value) ||
               (0x2F800...0x2FA1F).contains(value) ||
               (0x3000...0x303F).contains(value) ||
               (0xFF00...0xFFEF).contains(value)
    }
}

// MARK: - DOCX XML 解析器

private final class DOCXXMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    let namespace: String
    private(set) var parsedText = ""
    private var currentText = ""
    private var inParagraph = false
    private var inRun = false
    private var inTableCell = false
    private var paragraphBreakNeeded = false
    private var cellTabNeeded = false
    private var inDelete = false

    init(namespace: String) {
        self.namespace = namespace
        super.init()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard namespaceURI == namespace else { return }

        switch elementName {
        case "p":
            inParagraph = true
            if !parsedText.isEmpty && !cellTabNeeded {
                paragraphBreakNeeded = true
            }

        case "r":
            inRun = true

        case "t":
            break

        case "tab":
            currentText += "\t"

        case "br":
            currentText += "\n"

        case "tc":
            inTableCell = true
            cellTabNeeded = true

        case "tr":
            break

        case "tbl":
            break

        case "del":
            inDelete = true

        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard namespaceURI == namespace else { return }

        switch elementName {
        case "p":
            if paragraphBreakNeeded {
                parsedText += "\n"
                paragraphBreakNeeded = false
            }
            if !currentText.isEmpty {
                parsedText += currentText
                parsedText += "\n"
                currentText = ""
            }
            inParagraph = false

        case "r":
            inRun = false

        case "t":
            break

        case "tc":
            inTableCell = false

        case "tr":
            if !currentText.isEmpty {
                parsedText += currentText
                currentText = ""
            }
            parsedText += "\n"
            cellTabNeeded = false

        case "tbl":
            parsedText += "\n"

        case "del":
            inDelete = false

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !inDelete else { return }
        guard inRun else { return }

        if cellTabNeeded {
            currentText += "\t"
            cellTabNeeded = false
        }

        currentText += string
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
    }
}

// MARK: - DOCX 表格解析器

private final class DOCXTableParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    let namespace: String
    private(set) var tables: [[String]] = []
    private var currentTable: [[String]] = []
    private var currentRow: [String] = []
    private var currentCellText = ""
    private var inTable = false
    private var inRow = false
    private var inCell = false
    private var inRun = false
    private var inDelete = false

    init(namespace: String) {
        self.namespace = namespace
        super.init()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard namespaceURI == namespace else { return }

        switch elementName {
        case "tbl":
            inTable = true
            currentTable = []

        case "tr":
            inRow = true
            currentRow = []

        case "tc":
            inCell = true
            currentCellText = ""

        case "r":
            inRun = true

        case "del":
            inDelete = true

        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard namespaceURI == namespace else { return }

        switch elementName {
        case "tbl":
            inTable = false
            if !currentTable.isEmpty {
                tables.append(contentsOf: currentTable)
            }
            currentTable = []

        case "tr":
            inRow = false
            if !currentRow.isEmpty {
                currentTable.append(currentRow)
            }
            currentRow = []

        case "tc":
            inCell = false
            currentRow.append(currentCellText.trimmingCharacters(in: .whitespacesAndNewlines))
            currentCellText = ""

        case "r":
            inRun = false

        case "del":
            inDelete = false

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inRun && inCell && !inDelete else { return }
        currentCellText += string
    }
}

// MARK: - Core Properties 解析器

private final class CorePropertiesParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private(set) var properties: [String: String] = [:]
    private var currentElement = ""
    private var currentText = ""

    private let dcNamespace = "http://purl.org/dc/elements/1.1/"
    private let cpNamespace = "http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
    private let dctermsNamespace = "http://purl.org/dc/terms/"

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        switch elementName {
        case "title":
            properties["title"] = trimmedText
        case "creator":
            properties["author"] = trimmedText
        case "subject":
            properties["subject"] = trimmedText
        case "description":
            properties["description"] = trimmedText
        case "lastModifiedBy":
            properties["lastModifiedBy"] = trimmedText
        case "created", "dcterms:created":
            properties["created"] = trimmedText
        case "modified", "dcterms:modified":
            properties["modified"] = trimmedText
        case "category":
            properties["category"] = trimmedText
        default:
            break
        }

        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
}

// MARK: - XLSX 共享字符串解析器

private final class XLSXSharedStringsParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private(set) var strings: [String] = []
    private var currentText = ""
    private var inStringItem = false
    private var inText = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "si":
            inStringItem = true
            currentText = ""
        case "t":
            inText = true
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "si":
            inStringItem = false
            strings.append(currentText)
            currentText = ""
        case "t":
            inText = false
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inText else { return }
        currentText += string
    }
}

// MARK: - XLSX 工作簿解析器

private final class XLSXWorkbookParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private(set) var sheetNames: [String] = []
    private(set) var sheetFiles: [String] = []
    private var currentName = ""
    private var currentSheetID = ""
    private var currentRId = ""
    private var ridToFileMap: [String: String] = [:]
    private var inRelationships = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "sheet":
            currentName = attributeDict["name"] ?? ""
            currentRId = attributeDict["r:id"]
                ?? attributeDict["r:id1"]
                ?? attributeDict["id"]
                ?? ""

        case "Relationship":
            if let id = attributeDict["Id"],
               let target = attributeDict["Target"] {
                ridToFileMap[id] = target
            }

        case "Relationships":
            inRelationships = true

        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "sheet":
            if !currentName.isEmpty {
                sheetNames.append(currentName)
                if !currentRId.isEmpty, let filePath = ridToFileMap[currentRId] {
                    let normalizedPath = filePath.hasPrefix("/") ? String(filePath.dropFirst(1)) : filePath
                    sheetFiles.append(normalizedPath)
                } else {
                    sheetFiles.append("worksheets/sheet\(sheetNames.count).xml")
                }
            }
            currentName = ""
            currentRId = ""

        case "Relationships":
            inRelationships = false

        default:
            break
        }
    }
}

// MARK: - XLSX 工作表解析器

private final class XLSXSheetParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    let sharedStrings: [String]
    private(set) var rows: [[String]] = []
    private var currentRow: [String] = []
    private var currentRowIndex = -1
    private var lastRowIndex = -1
    private var currentCellRef = ""
    private var currentCellType = ""
    private var currentSharedStringIndex = ""
    private var currentText = ""
    private var inRow = false
    private var inCell = false
    private var inValue = false
    // 👈【内联字符优化】：新增 inline text 的状态跟踪机制，全面解决 Excel 内联字符串漏解析漏洞
    private var inInlineText = false

    private let spreadsheetNS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
        super.init()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "row":
            inRow = true
            currentRow = []
            currentRowIndex = Int(attributeDict["r"] ?? "-1") ?? -1

        case "c":
            inCell = true
            currentCellRef = attributeDict["r"] ?? ""
            currentCellType = attributeDict["t"] ?? ""
            currentSharedStringIndex = ""
            currentText = ""

        case "v":
            inValue = true
            currentText = ""

        case "is":
            break

        case "t":
            // 👈 激活内联字符标记
            inInlineText = true
            break

        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "row":
            inRow = false
            if lastRowIndex >= 0 && currentRowIndex > lastRowIndex + 1 {
                let emptyRows = currentRowIndex - lastRowIndex - 1
                for _ in 0..<min(emptyRows, 100) {
                    rows.append([])
                }
            }
            if !currentRow.isEmpty {
                rows.append(currentRow)
            }
            lastRowIndex = currentRowIndex

        case "c":
            inCell = false
            let cellValue: String
            if currentCellType == "s" {
                if let index = Int(currentText), index < sharedStrings.count {
                    cellValue = sharedStrings[index]
                } else {
                    cellValue = currentText
                }
            } else if currentCellType == "b" {
                cellValue = (currentText == "1") ? "TRUE" : "FALSE"
            } else if currentCellType == "str" || currentCellType == "inlineStr" {
                // 👈 支持内联字符公式结果及纯文本输出
                cellValue = currentText
            } else {
                cellValue = currentText
            }

            if !currentCellRef.isEmpty {
                let column = columnFromCellReference(currentCellRef)
                while currentRow.count < column {
                    currentRow.append("")
                }
                currentRow.append(cellValue)
            } else {
                currentRow.append(cellValue)
            }

        case "v":
            inValue = false

        case "t":
            // 👈 清除内联字符状态，修复 currentText += currentText 的重叠拼接 Bug
            inInlineText = false

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // 👈【内联字符优化】：同时支持共享和内联纯文本的数据抓取与安全累积
        if inValue || inInlineText {
            currentText += string
        }
    }

    private func columnFromCellReference(_ ref: String) -> Int {
        var column = 0
        for char in ref {
            if char.isLetter {
                column = column * 26 + (Int(char.asciiValue ?? 0) - Int(Character("A").asciiValue ?? 0) + 1)
            } else {
                break
            }
        }
        return column - 1
    }
}

// MARK: - PPTX 幻灯片解析器

private final class PPTXSlideParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private(set) var titleText = ""
    private(set) var bodyText = ""
    private(set) var tables: [[String]] = []
    private var currentText = ""
    private var shapeText = ""
    private var isTitlePlaceholder = false
    private var inRun = false
    private var inParagraph = false
    private var inShape = false
    private var currentTable: [[String]] = []
    private var currentRow: [String] = []
    private var currentCellText = ""
    private var inTable = false
    private var inRow = false
    private var inCell = false

    private let presentationNS = "http://schemas.openxmlformats.org/presentationml/2006/main"
    private let drawingNS = "http://schemas.openxmlformats.org/drawingml/2006/main"

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "sp":
            inShape = true
            shapeText = ""
            isTitlePlaceholder = false

        case "ph":
            let type = attributeDict["type"] ?? ""
            let idx = attributeDict["idx"] ?? ""
            isTitlePlaceholder = (type == "title" || type == "ctrTitle" || idx == "0")

        case "p":
            inParagraph = true

        case "r":
            inRun = true

        case "t":
            break

        case "a:tbl":
            inTable = true
            currentTable = []

        case "a:tr":
            inRow = true
            currentRow = []

        case "a:tc":
            inCell = true
            currentCellText = ""

        case "br":
            currentText += "\n"

        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "sp":
            inShape = false
            let trimmedText = shapeText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedText.isEmpty {
                if isTitlePlaceholder {
                    titleText = trimmedText
                } else {
                    if !bodyText.isEmpty {
                        bodyText += "\n"
                    }
                    bodyText += trimmedText
                }
            }

        case "p":
            inParagraph = false
            if inShape {
                if !shapeText.isEmpty && !currentText.isEmpty {
                    shapeText += "\n"
                }
                shapeText += currentText
            }
            currentText = ""

        case "r":
            inRun = false

        case "t":
            break

        case "a:tbl":
            inTable = false
            if !currentTable.isEmpty {
                tables.append(contentsOf: currentTable)
            }
            currentTable = []

        case "a:tr":
            inRow = false
            if !currentRow.isEmpty {
                currentTable.append(currentRow)
            }
            currentRow = []

        case "a:tc":
            inCell = false
            currentRow.append(currentCellText.trimmingCharacters(in: .whitespacesAndNewlines))
            currentCellText = ""

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inRun {
            currentText += string
        } else if inCell {
            currentCellText += string
        }
    }
}
