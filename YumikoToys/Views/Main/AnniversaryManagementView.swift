//
//  AnniversaryManagementView.swift
//  YumikoToys
//
//  宠物名片管理视图（高精度实时状态栏预览 + 科学体型向导版）
//

import SwiftUI
import Combine

struct AnniversaryManagementView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AnniversaryManagementViewModel()
    @State private var showingAddSheet = false
    @State private var editingAnniversary: Anniversary?
    @State private var selectedCardAnniversary: Anniversary? = nil
    @State private var showCardModal = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("🐾 宠物名片")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: "FF6B9D"))
                }
                .buttonStyle(.premium)
                .premiumHover(scale: 1.1)
                .help("添加宠物")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // 宠物列表
            if viewModel.anniversaries.isEmpty {
                EmptyPetView(showingAddSheet: $showingAddSheet)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.anniversaries) { anniversary in
                            PetProfileRowView(
                                anniversary: anniversary,
                                isActive: viewModel.activeAnniversaryId == anniversary.id,
                                onSetActive: {
                                    viewModel.setActiveAnniversary(id: anniversary.id)
                                },
                                onEdit: {
                                    editingAnniversary = anniversary
                                },
                                onDelete: {
                                    viewModel.deleteAnniversary(id: anniversary.id)
                                },
                                onShowCard: {
                                    selectedCardAnniversary = anniversary
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showCardModal = true
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 540, minHeight: 400)
        .sheet(isPresented: $showingAddSheet) {
            PetProfileEditView(anniversary: nil, onSave: { new in
                viewModel.addAnniversary(new)
            })
        }
        .sheet(item: $editingAnniversary) { anniversary in
            PetProfileEditView(anniversary: anniversary, onSave: { updated in
                viewModel.updateAnniversary(updated)
            })
        }
        .petProfileCard(
            isPresented: Binding(
                get: { showCardModal && selectedCardAnniversary != nil },
                set: { newValue in
                    showCardModal = newValue
                    if !newValue {
                        selectedCardAnniversary = nil
                    }
                }
            ),
            anniversary: selectedCardAnniversary ?? Anniversary(title: "", startDate: Date()),
            calculation: selectedCardAnniversary.map {
                AnniversaryInfo.calculateTime(from: $0.startDate)
            } ?? AnniversaryInfo.calculateTime(from: Date())
        )
        .onAppear {
            viewModel.onAppear()
        }
    }
}

// MARK: - 空状态视图

private struct EmptyPetView: View {
    @Binding var showingAddSheet: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("🐾")
                .font(.system(size: 60))
            
            Text("还没有宠物名片")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("添加你的第一只宠物，记录每一个陪伴的日子")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Button(action: { showingAddSheet = true }) {
                Label("添加宠物", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.premium)
            .premiumHover()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 宠物名片行视图

private struct PetProfileRowView: View {
    let anniversary: Anniversary
    let isActive: Bool
    let onSetActive: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onShowCard: () -> Void

    @State private var isHovered = false
    
    private var formattedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: anniversary.startDate)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 活跃指示器
            Circle()
                .fill(isActive ? Color(hex: "FF6B9D") : Color.clear)
                .overlay(
                    Circle().stroke(
                        isActive ? Color(hex: "FF6B9D") : Color.secondary.opacity(0.3),
                        lineWidth: 2
                    )
                )
                .frame(width: 20, height: 20)
            
            // 头像（像素风格）
            PixelAvatarView(emoji: anniversary.displayAvatar, size: 50)
                .onTapGesture {
                    onShowCard()
                }
                .onHover { _ in }
                .help("查看名片")
            
            // 宠物信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(anniversary.displayPetName)
                        .font(.headline)
                    
                    if let gender = anniversary.petGender {
                        if gender.isRainbow {
                            Text(gender.emoji)
                                .font(.caption)
                                .foregroundStyle(PetGender.rainbowGradient)
                        } else {
                            Text(gender.emoji)
                                .font(.caption)
                                .foregroundStyle(gender.color)
                        }
                    }
                    
                    Text(anniversary.type.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(hex: anniversary.type == .countUp ? "FF6B9D" : "00B4D8").opacity(0.15))
                        )
                        .foregroundStyle(Color(hex: anniversary.type == .countUp ? "FF6B9D" : "00B4D8"))
                }
                
                HStack(spacing: 8) {
                    if let species = anniversary.species {
                        Text(species)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(formattedDateString)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.premium)
                .premiumHover()
                .help("编辑")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .frame(width: 30, height: 30)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.premium)
                .premiumHover()
                .help("删除")
            }
            .opacity(isHovered ? 1 : 0.3)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isActive ? Color(hex: "FF6B9D").opacity(0.4) : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onSetActive()
        }
        .help(isActive ? "当前活跃宠物" : "点击设为活跃宠物")
    }
}

// MARK: - 宠物名片编辑视图

struct PetProfileEditView: View {
    @Environment(\.dismiss) var dismiss
    let anniversary: Anniversary?
    let onSave: (Anniversary) -> Void
    
    @State private var petName: String = ""
    @State private var startDate = Date()
    @State private var type: AnniversaryType = .countUp
    @State private var gender: PetGender = .unknown
    @State private var species: String = ""
    @State private var selectedEmoji: String = "🐾"
    @State private var statusBarLine1: String = ""
    
    // 【新增绑定状态】犬类体型
    @State private var dogSize: CanineSize? = nil
    
    private let emojiToSpecies: [String: String] = [
        "🐰": "兔子",
        "🐱": "猫咪",
        "🐶": "狗狗",
        "🐹": "仓鼠",
        "🐻": "熊",
        "🐼": "熊猫",
        "🦊": "狐狸",
        "🐸": "青蛙",
        "🐧": "企鹅",
        "🦜": "鹦鹉",
        "🐢": "乌龟",
        "🐟": "鱼",
        "🦎": "蜥蜴",
        "🐾": "宠物"
    ]
    
    private let petEmojis: [String] = [
        "🐰", "🐱", "🐶", "🐹", "🐻", "🐼", "🦊",
        "🐸", "🐧", "🦜", "🐢", "🐟", "🦎", "🐾"
    ]
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    
    var isEditing: Bool { anniversary != nil }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.premium)
                    .premiumHover()
                
                Spacer()
                
                Text(isEditing ? "编辑宠物名片" : "添加宠物")
                    .font(.headline)
                
                Spacer()
                
                Button(isEditing ? "保存" : "添加") {
                    save()
                }
                .disabled(petName.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.premium)
                .premiumHover()
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // 头像选择区域
                    VStack(spacing: 12) {
                        PixelAvatarView(emoji: selectedEmoji, size: 80)
                            .shadow(color: Color(hex: "FF6B9D").opacity(0.3), radius: 8)
                        
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(petEmojis, id: \.self) { emoji in
                                VStack(spacing: 4) {
                                    PixelAvatarMiniPreview(emoji: emoji, isSelected: selectedEmoji == emoji)
                                    Text(emojiToSpecies[emoji] ?? "宠物")
                                        .font(.system(size: 10))
                                        .foregroundStyle(selectedEmoji == emoji ? Color(hex: "FF6B9D") : .secondary)
                                }
                                .onTapGesture {
                                    selectedEmoji = emoji
                                    if species.isEmpty || emojiToSpecies.values.contains(species) {
                                        species = emojiToSpecies[emoji] ?? ""
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // 表单区域
                    VStack(spacing: 16) {
                        // 宠物名字
                        HStack(spacing: 12) {
                            Text("名字")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            TextField("宠物名字", text: $petName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // 性别选择器
                        GenderSelectorView(gender: $gender)
                            .padding(.vertical, 8)
                        
                        // 物种/品种
                        HStack(spacing: 12) {
                            Text("品种")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            TextField("如：荷兰垂耳兔", text: $species)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
                        //  【新增核心交互区】犬类体型选择及辅助文本渲染
                        // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
                        if selectedEmoji == "🐶" {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 12) {
                                    Text("体型")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .leading)
                                    
                                    Picker("", selection: Binding(
                                        get: { dogSize ?? .medium },
                                        set: { dogSize = $0 }
                                    )) {
                                        ForEach(CanineSize.allCases) { size in
                                            Text(size.displayName).tag(size)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.segmented)
                                }
                                
                                // 科学选型辅助向导文本（秒级自适应解析渲染）
                                Text((dogSize ?? .medium).selectionHint)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: "8B7355"))
                                    .padding(.leading, 72) // 像素级对齐输入框
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // 状态栏显示文字
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("状态栏显示文字")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                TextField("{name}已到来", text: $statusBarLine1)
                                    .textFieldStyle(.roundedBorder)
                                
                                HStack(spacing: 6) {
                                    VariableTagView(variable: "{name}", desc: "名字") {
                                        statusBarLine1 += "{name}"
                                    }
                                    VariableTagView(variable: "{days}", desc: "天数") {
                                        statusBarLine1 += "{days}"
                                    }
                                    VariableTagView(variable: "{emoji}", desc: "头像") {
                                        statusBarLine1 += "{emoji}"
                                    }
                                    VariableTagView(variable: "{species}", desc: "品种") {
                                        statusBarLine1 += "{species}"
                                    }
                                }
                                
                                // 预览提示
                                if !statusBarLine1.isEmpty {
                                    let preview = statusBarLine1
                                        .replacingOccurrences(of: "{name}", with: petName.isEmpty ? "宠物" : petName)
                                        .replacingOccurrences(of: "{days}", with: "365")
                                        .replacingOccurrences(of: "{emoji}", with: selectedEmoji)
                                        .replacingOccurrences(of: "{species}", with: species.isEmpty ? "宠物" : species)
                                    
                                    Text("预览: \(preview)")
                                        .font(.caption)
                                        .foregroundStyle(Color(hex: "FF6B9D"))
                                        .padding(.top, 4)
                                }
                            }
                        }
                        
                        // 生日
                        HStack(spacing: 12) {
                            Text("生日")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                            
                            Spacer()
                        }
                        
                        // 计时类型
                        HStack(spacing: 12) {
                            Text("计时")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            Picker("", selection: $type) {
                                ForEach(AnniversaryType.allCases) { t in
                                    Text(t.icon + " " + t.displayName).tag(t)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(.horizontal, 20)
                    .animation(.easeInOut(duration: 0.25), value: selectedEmoji) // 切换头像时动画平滑折叠/展开体型栏
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // 状态栏预览 (已接入高精度实时轮询器)
                    VStack(spacing: 8) {
                        Text("状态栏预览")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        StatusBarPreview(
                            petName: petName.isEmpty ? "宠物名字" : petName,
                            species: species,
                            selectedEmoji: selectedEmoji,
                            type: type,
                            startDate: startDate,
                            statusBarLine1: statusBarLine1
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(width: 480, height: 520)
        .onAppear {
            if let anniversary = anniversary {
                petName = anniversary.petName ?? anniversary.title
                startDate = anniversary.startDate
                type = anniversary.type
                gender = anniversary.petGender ?? .unknown
                species = anniversary.species ?? ""
                selectedEmoji = anniversary.avatarEmoji ?? anniversary.emoji ?? "🐾"
                statusBarLine1 = anniversary.customStatusBarLine1 ?? ""
                
                // 【核心修复】初始化体型状态
                dogSize = anniversary.dogSize ?? .medium
            }
        }
    }
    
    private func save() {
        let trimmedName = petName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        let trimmedSpecies = species.trimmingCharacters(in: .whitespaces)
        
        // 【核心修复】如果更换头像为非狗，则重置体型状态
        let finalDogSize = (selectedEmoji == "🐶") ? (dogSize ?? .medium) : nil
        
        var newAnniversary: Anniversary
        if let existing = anniversary {
            newAnniversary = existing
            newAnniversary.title = trimmedName
            newAnniversary.petName = trimmedName
            newAnniversary.startDate = startDate
            newAnniversary.type = type
            newAnniversary.petGender = gender
            newAnniversary.species = trimmedSpecies.isEmpty ? nil : trimmedSpecies
            newAnniversary.avatarEmoji = selectedEmoji
            newAnniversary.emoji = selectedEmoji
            newAnniversary.dogSize = finalDogSize // 保存体型数据
        } else {
            newAnniversary = Anniversary(
                title: trimmedName,
                startDate: startDate,
                type: type,
                emoji: selectedEmoji,
                petName: trimmedName,
                petGender: gender,
                species: trimmedSpecies.isEmpty ? nil : trimmedSpecies,
                avatarEmoji: selectedEmoji,
                dogSize: finalDogSize // 保存体型数据
            )
        }
        
        let trimmedStatusBarLine1 = statusBarLine1.trimmingCharacters(in: .whitespaces)
        newAnniversary.customStatusBarLine1 = trimmedStatusBarLine1.isEmpty ? nil : trimmedStatusBarLine1
        
        onSave(newAnniversary)
        dismiss()
    }
}

// MARK: - 交互式变量快速填充标签

private struct VariableTagView: View {
    let variable: String
    let desc: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text(variable)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "007AFF"))
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "007AFF").opacity(isHovered ? 0.18 : 0.08))
            )
        }
        .buttonStyle(.premium)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help("点击在光标处或末尾追加 \"\(variable)\"")
    }
}

// MARK: - 状态栏预览 (高精度实时更新版)

private struct StatusBarPreview: View {
    let petName: String
    let species: String
    let selectedEmoji: String
    let type: AnniversaryType
    let startDate: Date
    let statusBarLine1: String
    
    // 【核心修复】引入 0.1s 极高频率的发布订阅，使毫秒级天数能高精度的平滑跳动
    @State private var currentNow = Date()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    /// 基础天数的小数计算
    private var daysDouble: Double {
        let interval = currentNow.timeIntervalSince(startDate)
        return type == .countUp ? interval / 86400.0 : max(0, -interval / 86400.0)
    }
    
    /// 第二行标准时间格式
    private var formattedDays: String {
        return String(format: "%.3f天", daysDouble)
    }
    
    /// 状态栏第一行文字解析（支持在自定义模板中动态替换所有已知变量）
    private var line1: String {
        if statusBarLine1.isEmpty {
            switch type {
            case .countUp: return "\(petName)已到来"
            case .countDown: return "距\(petName)还有"
            }
        } else {
            let daysStr = String(format: "%.3f", daysDouble)
            return statusBarLine1
                .replacingOccurrences(of: "{name}", with: petName)
                .replacingOccurrences(of: "{days}", with: daysStr)
                .replacingOccurrences(of: "{emoji}", with: selectedEmoji)
                .replacingOccurrences(of: "{species}", with: species.isEmpty ? "宠物" : species)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 模拟状态栏图标 - 实时跟随您选择的 Emoji 头像
            Text(selectedEmoji)
                .font(.system(size: 16))
            
            // 模拟状态栏双行文字面板
            VStack(alignment: .leading, spacing: 1) {
                Text(line1)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                
                // 【核心优化】如果您的自定义文字已经手工填充了 `{days}` 变量，第二行则自动隐藏，防止数据重复冗余显示
                if statusBarLine1.isEmpty || !statusBarLine1.contains("{days}") {
                    Text(formattedDays)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        // 挂载轮询侦听器以保持高频更新
        .onReceive(timer) { input in
            currentNow = input
        }
    }
}

// MARK: - 视图模型

@MainActor
final class AnniversaryManagementViewModel: ObservableObject {
    @Published var anniversaries: [Anniversary] = []
    @Published var activeAnniversaryId: UUID?
    
    private let container = DependencyContainer.shared
    private var cancellables = Set<AnyCancellable>()
    
    func onAppear() {
        anniversaries = container.anniversaryService.anniversaries
        activeAnniversaryId = container.anniversaryService.activeAnniversary?.id
        
        container.anniversaryService.anniversariesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$anniversaries)
    }
    
    func addAnniversary(_ anniversary: Anniversary) {
        container.anniversaryService.addAnniversary(anniversary)
    }
    
    func updateAnniversary(_ anniversary: Anniversary) {
        container.anniversaryService.updateAnniversary(anniversary)
    }
    
    func deleteAnniversary(id: UUID) {
        container.anniversaryService.deleteAnniversary(id: id)
        activeAnniversaryId = container.anniversaryService.activeAnniversary?.id
    }
    
    func toggleActiveAnniversary(id: UUID) {
        if activeAnniversaryId == id {
            // 如果点击的是当前活动宠物，可由设计决定是否支持反选
        } else {
            setActiveAnniversary(id: id)
        }
    }
    
    func setActiveAnniversary(id: UUID) {
        container.anniversaryService.setActiveAnniversary(id: id)
        activeAnniversaryId = id
    }
}

#Preview {
    AnniversaryManagementView()
}
