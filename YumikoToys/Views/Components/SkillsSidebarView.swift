import SwiftUI
import ZIPFoundation

struct SkillsSidebarView: View {
    @ObservedObject var skillService = SkillService.shared
    @State private var showingImporter = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🛠️ 技能库 (Skills)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "E6F4EA"))
                Spacer()
                Button(action: {
                    showingImporter = true
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 10))
                        Text("导入 Skill")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "059669"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(hex: "059669").opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            
            Divider()
                .background(Color(hex: "059669").opacity(0.15))
            
            // Skills List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(skillService.getAllSkills()) { skill in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(skill.name)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(hex: "81C784"))
                                Spacer()
                                Text(skill.scriptType.uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(3)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(skill.description)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.03), lineWidth: 1)
                        )
                    }
                }
                .padding(10)
            }
        }
        .background(Color(hex: "0A0F0D"))
        .sheet(isPresented: $showingImporter) {
            OpenClawSkillImporterView(isPresented: $showingImporter)
        }
    }
}

struct OpenClawSkillImporterView: View {
    @Binding var isPresented: Bool
    @State private var importTab = 0 // 0: 手动粘贴, 1: 在线链接
    @State private var mdContent: String = ""
    @State private var urlString: String = ""
    @State private var isDownloading = false
    @State private var importMessage: String = ""
    @State private var isSuccess = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("导入 OpenClaw SKILL.md 技能")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("关闭") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Picker("", selection: $importTab) {
                Text("手动粘贴").tag(0)
                Text("在线链接").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                if importTab == 0 {
                    Text("粘贴 SKILL.md 文件内容：")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $mdContent)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 200)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 1))
                } else {
                    Text("输入在线 Skill 链接 (支持 .md 或 .zip 压缩包)：")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    TextField("https://example.com/skill.md 或 .zip", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 30)
                }
                
                if !importMessage.isEmpty {
                    Text(importMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(isSuccess ? Color.green : Color.red)
                        .padding(.vertical, 4)
                }
                
                Spacer()
                
                if importTab == 0 {
                    Button(action: {
                        importSkill()
                    }) {
                        Text("解析并导入技能")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "059669"))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(mdContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button(action: {
                        downloadAndImportSkill()
                    }) {
                        HStack {
                            if isDownloading {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            }
                            Text(isDownloading ? "正在下载..." : "下载并解析导入")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "059669"))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDownloading)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 480, height: 420)
    }
    
    private func importSkill() {
        guard let parsed = OpenClawSkillParser.parse(markdownContent: mdContent) else {
            importMessage = "错误：解析失败，请确保格式正确（必须包含 --- 包裹的 yaml 头部）"
            isSuccess = false
            return
        }
        
        let newSkill = LLMSkill(
            name: parsed.name,
            description: parsed.description,
            parametersJSON: parsed.parametersJSON,
            scriptType: "openclaw",
            scriptContent: parsed.instructions
        )
        
        SkillService.shared.addOrUpdateSkill(newSkill)
        isSuccess = true
        importMessage = "成功：已导入技能 [\(parsed.name)]！"
        
        // 延时关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isPresented = false
        }
    }
    
    private func downloadAndImportSkill() {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            importMessage = "错误：无效的 URL 链接"
            isSuccess = false
            return
        }
        
        isDownloading = true
        importMessage = "正在从链接下载..."
        isSuccess = false
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    await MainActor.run {
                        importMessage = "错误：服务器响应失败"
                        isDownloading = false
                    }
                    return
                }
                
                // Check if it's a zip file by magic bytes: 50 4B 03 04
                let isZip = data.count >= 4 && data[0] == 0x50 && data[1] == 0x4b && data[2] == 0x03 && data[3] == 0x04
                
                var importedCount = 0
                
                if isZip {
                    let fm = FileManager.default
                    let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
                    
                    let zipURL = tempDir.appendingPathComponent("archive.zip")
                    try data.write(to: zipURL)
                    
                    let unzipDir = tempDir.appendingPathComponent("unzipped")
                    try fm.unzipItem(at: zipURL, to: unzipDir)
                    
                    let enumerator = fm.enumerator(at: unzipDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
                    while let fileURL = enumerator?.nextObject() as? URL {
                        let pathExt = fileURL.pathExtension.lowercased()
                        if pathExt == "md" {
                            if let mdText = try? String(contentsOf: fileURL, encoding: .utf8),
                               let parsed = OpenClawSkillParser.parse(markdownContent: mdText) {
                                let newSkill = LLMSkill(
                                    name: parsed.name,
                                    description: parsed.description,
                                    parametersJSON: parsed.parametersJSON,
                                    scriptType: "openclaw",
                                    scriptContent: parsed.instructions
                                )
                                SkillService.shared.addOrUpdateSkill(newSkill)
                                importedCount += 1
                            }
                        } else if pathExt == "json" {
                            if let jsonData = try? Data(contentsOf: fileURL) {
                                let skills = parseSkillJSON(data: jsonData)
                                for skill in skills {
                                    SkillService.shared.addOrUpdateSkill(skill)
                                    importedCount += 1
                                }
                            }
                        }
                    }
                    
                    try? fm.removeItem(at: tempDir)
                    
                    await MainActor.run {
                        isDownloading = false
                        if importedCount > 0 {
                            isSuccess = true
                            importMessage = "成功：从 ZIP 中导入了 \(importedCount) 个技能！"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                isPresented = false
                            }
                        } else {
                            importMessage = "错误：ZIP 中未找到符合 OpenClaw 格式的 SKILL.md 或 JSON 技能"
                        }
                    }
                } else {
                    // Try parsing as JSON first
                    let jsonSkills = parseSkillJSON(data: data)
                    if !jsonSkills.isEmpty {
                        for skill in jsonSkills {
                            SkillService.shared.addOrUpdateSkill(skill)
                            importedCount += 1
                        }
                        await MainActor.run {
                            isDownloading = false
                            isSuccess = true
                            importMessage = "成功：已导入 \(importedCount) 个 JSON 技能！"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                isPresented = false
                            }
                        }
                    } else {
                        // Treat as markdown text
                        guard let mdText = String(data: data, encoding: .utf8),
                              let parsed = OpenClawSkillParser.parse(markdownContent: mdText) else {
                            await MainActor.run {
                                isDownloading = false
                                importMessage = "错误：解析技能失败（请提供正确的 SKILL.md 或 JSON 文件）"
                            }
                            return
                        }
                        
                        let newSkill = LLMSkill(
                            name: parsed.name,
                            description: parsed.description,
                            parametersJSON: parsed.parametersJSON,
                            scriptType: "openclaw",
                            scriptContent: parsed.instructions
                        )
                        
                        SkillService.shared.addOrUpdateSkill(newSkill)
                        await MainActor.run {
                            isDownloading = false
                            isSuccess = true
                            importMessage = "成功：已导入技能 [\(parsed.name)]！"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                isPresented = false
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    importMessage = "错误：\(error.localizedDescription)"
                }
            }
        }
    }
    
    private func parseSkillJSON(data: Data) -> [LLMSkill] {
        let decoder = JSONDecoder()
        if let skill = try? decoder.decode(LLMSkill.self, from: data) {
            return [skill]
        }
        if let skills = try? decoder.decode([LLMSkill].self, from: data) {
            return skills
        }
        return []
    }
}



// MARK: - OpenClaw Skill Parser
struct OpenClawSkillParser {
    static func parse(markdownContent: String) -> (name: String, description: String, parametersJSON: String, instructions: String)? {
        let lines = markdownContent.components(separatedBy: .newlines)
        guard lines.count > 2 else { return nil }
        
        var inFrontmatter = false
        var frontmatterLines: [String] = []
        var bodyLines: [String] = []
        
        var frontmatterDashesCount = 0
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine == "---" {
                frontmatterDashesCount += 1
                if frontmatterDashesCount == 1 {
                    inFrontmatter = true
                    continue
                } else if frontmatterDashesCount == 2 {
                    inFrontmatter = false
                    continue
                }
            }
            
            if inFrontmatter {
                frontmatterLines.append(line)
            } else {
                bodyLines.append(line)
            }
        }
        
        // Parse frontmatter
        var name = ""
        var description = ""
        var parametersYAML: [String] = []
        var inParameters = false
        
        for line in frontmatterLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if trimmed.hasPrefix("parameters:") {
                inParameters = true
                continue
            }
            
            if inParameters {
                if !line.hasPrefix(" ") && !line.hasPrefix("\t") && line.contains(":") {
                    inParameters = false
                } else {
                    parametersYAML.append(line)
                    continue
                }
            }
            
            if trimmed.hasPrefix("name:") {
                name = trimmed.replacingOccurrences(of: "name:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            } else if trimmed.hasPrefix("description:") {
                description = trimmed.replacingOccurrences(of: "description:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                description = description.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        
        var parametersJSON = "{}"
        if !parametersYAML.isEmpty {
            parametersJSON = """
            {
                "type": "object",
                "properties": {}
            }
            """
        }
        
        let instructions = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if name.isEmpty {
            name = "imported_skill_" + UUID().uuidString.prefix(6).lowercased()
        }
        
        return (name: name, description: description, parametersJSON: parametersJSON, instructions: instructions)
    }
}
