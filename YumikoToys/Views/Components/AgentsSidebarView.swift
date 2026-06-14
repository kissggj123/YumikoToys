//
//  AgentsSidebarView.swift
//  YumikoToys
//

import SwiftUI

struct AgentsSidebarView: View {
    @ObservedObject var agentManager = AgentManagerService.shared
    @ObservedObject var conversationService: ConversationService
    @ObservedObject var viewModel: AIChatViewModel
    
    @State private var showingEditor = false
    @State private var selectedAgent: CustomAgent? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🤖 智能体 (Agents)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "E6F4EA"))
                Spacer()
                Button(action: {
                    selectedAgent = CustomAgent(
                        id: "agent_\(UUID().uuidString.prefix(6).lowercased())",
                        name: "自定义智能体",
                        description: "新自定义助手说明",
                        avatar: "🧠",
                        systemPrompt: "你是一个专业的智能助手，协助用户处理事务。",
                        selectedSkillNames: []
                    )
                    showingEditor = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "059669"))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            
            Divider()
                .background(Color(hex: "059669").opacity(0.15))
            
            // Agents List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(agentManager.customAgents) { agent in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(agent.avatar)
                                    .font(.system(size: 20))
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(6)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(agent.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(agent.description)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                            }
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    let newConv = conversationService.createConversation(
                                        title: "\(agent.name) 对话",
                                        chatMode: .aiAssistant,
                                        agentId: agent.id
                                    )
                                    viewModel.startNewConversation(id: newConv.id)
                                    // Change selected tab in parent sidebar if possible (or conversation switching handles it)
                                }) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "bubble.left.and.bubble.right.fill")
                                            .font(.system(size: 9))
                                        Text("对话")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundStyle(Color(hex: "059669"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "059669").opacity(0.1))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    selectedAgent = agent
                                    showingEditor = true
                                }) {
                                    Text("编辑")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                Button(action: {
                                    agentManager.deleteAgent(id: agent.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        )
                    }
                }
                .padding(10)
            }
        }
        .background(Color(hex: "0A0F0D"))
        .sheet(item: $selectedAgent) { agent in
            AgentEditorView(agent: agent, selectedAgent: $selectedAgent)
        }
    }
}

struct AgentEditorView: View {
    @State var agent: CustomAgent
    @Binding var selectedAgent: CustomAgent?
    @ObservedObject var agentManager = AgentManagerService.shared
    @ObservedObject var skillService = SkillService.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("配置智能体 (Agent)")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("关闭") {
                    selectedAgent = nil
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("头像 Emoji")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextField("🧠", text: $agent.avatar)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("智能体名称")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextField("全能助手", text: $agent.name)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("简单描述")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("简要说明智能体的职责", text: $agent.description)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("系统提示词 (System Prompt)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $agent.systemPrompt)
                            .font(.system(size: 11))
                            .frame(height: 120)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("绑定的 Skill 技能与工具")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(skillService.getAllSkills()) { skill in
                                Toggle(isOn: Binding(
                                    get: { agent.selectedSkillNames.contains(skill.name) },
                                    set: { newValue in
                                        if newValue {
                                            if !agent.selectedSkillNames.contains(skill.name) {
                                                agent.selectedSkillNames.append(skill.name)
                                            }
                                        } else {
                                            agent.selectedSkillNames.removeAll { $0 == skill.name }
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(skill.name)
                                            .font(.system(size: 11, weight: .medium))
                                        Text(skill.description)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(CheckboxToggleStyle())
                            }
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.02))
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        agentManager.addOrUpdateAgent(agent)
                        selectedAgent = nil
                    }) {
                        Text("保存智能体")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "059669"))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal)
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            if let sel = selectedAgent {
                self.agent = sel
            }
        }
        .onChange(of: selectedAgent) { newAgent in
            if let newAgent = newAgent {
                self.agent = newAgent
            }
        }
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12))
                    .foregroundStyle(configuration.isOn ? Color(hex: "059669") : .secondary)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}
