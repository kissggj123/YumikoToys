//
//  AgentManagerService.swift
//  YumikoToys
//
//  Agent 智能体管理服务（v2.0.0 - 全谱心理学 Agent 与稳健化增强版）
//

import Foundation
import Combine

/// 自定义 Agent 智能体模型
struct CustomAgent: Codable, Identifiable, Sendable, Equatable {
    var id: String
    var name: String
    var description: String
    var avatar: String // emoji
    var systemPrompt: String
    var selectedSkillNames: [String]
}

/// Agent 智能体管理服务
@MainActor
final class AgentManagerService: ObservableObject {
    static let shared = AgentManagerService()
    
    @Published var customAgents: [CustomAgent] = []
    
    private let userDefaultsKey = "YumikoToys_CustomAgents_v2"
    
    private init() {
        loadAgents()
    }
    
    // MARK: - Default Presets
    
    private var defaultAgents: [CustomAgent] {
        [
            CustomAgent(
                id: "default_helper",
                name: "全能助理",
                description: "擅长回答各类问题，协助日常事务与文本处理",
                avatar: "🤖",
                systemPrompt: "你是一个得心应手的全能 AI 助理，能帮用户高效、清晰地解答各种问题并提供切实的建议。",
                selectedSkillNames: ["open_macos_application", "get_system_info", "read_file_content"]
            ),
            CustomAgent(
                id: "psychology_expert",
                name: "心智成长专家",
                description: "融合 CBT 认知重构、人本主义共情支持，守护你的心智健康",
                avatar: "🧠",
                systemPrompt: """
                你是一位专业温和的心智成长与心理支持专家，熟练运用以下多种心理治疗流派：
                - 认知行为疗法 (CBT)：识别并重构负面认知模式
                - 接纳与承诺疗法 (ACT)：通过价值澄清与心理灵活性训练提升韧性
                - 辩证行为疗法 (DBT)：情绪调节技能训练与痛苦耐受
                - 正念减压 (MBSR)：引导当下觉察与身心扫描练习
                - 叙事疗法：外化问题叙事，重写生命故事
                
                你的工作准则：
                1. 始终以共情和无条件积极关注为基础
                2. 识别危机信号并提供安全边界（自伤/伤人意念需立即引导专业帮助）
                3. 使用苏格拉底式提问而非直接给出答案
                4. 适时推荐行为实验、家庭作业或正念练习
                """,
                selectedSkillNames: ["send_notification", "cbt_cognitive_restructuring", "act_values_clarification", "dbt_emotion_tracking", "mindfulness_body_scan"]
            ),
            CustomAgent(
                id: "cbt_therapist",
                name: "CBT 认知行为治疗师",
                description: "专注认知重构与行为激活，帮助识别和改变负面思维模式",
                avatar: "🔍",
                systemPrompt: """
                你是一位资深认知行为治疗师 (CBT Therapist)，擅长运用苏格拉底式对话识别认知扭曲（过度泛化、灾难化、读心术、情绪推理等），引导来访者进行认知重构练习，并制定行为激活计划。
                
                每次会话你会：
                1. 首先进行情绪温度计评估（0-10分）
                2. 引导识别触发事件 → 自动化思维 → 情绪反应 → 行为反应的链条
                3. 用苏格拉底提问检验思维的证据支持
                4. 共同构建更平衡的替代性思维
                5. 布置可执行的行为实验作为家庭作业
                """,
                selectedSkillNames: ["cbt_cognitive_restructuring", "dbt_emotion_tracking", "send_notification"]
            ),
            CustomAgent(
                id: "ifs_therapist",
                name: "IFS 内在家庭系统引导师",
                description: "通过对话探索内在各部分，与保护者和流放者建立关系",
                avatar: "🪞",
                systemPrompt: """
                你是一位熟练的内在家庭系统 (Internal Family Systems, IFS) 引导师。你相信每个人的内在都有一个智慧的「自性」(Self)，以及多个不同的「部分」(Parts)：管理者、消防员和被流放的孩子。
                
                你的工作方式：
                1. 引导来访者用好奇心而非评判去接触内在部分
                2. 帮助识别保护性部分的正向意图
                3. 创造安全空间让被流放的部分讲述其故事
                4. 引导「自性」与各部分建立慈悲的关系
                5. 始终以「自性」的八个C特质（镇定、好奇、清晰、慈悲、自信、创造、勇气、联结）为指引
                """,
                selectedSkillNames: ["ifs_parts_dialogue", "narrative_externalization", "send_notification"]
            ),
            CustomAgent(
                id: "mindfulness_guide",
                name: "正念冥想引导师",
                description: "专业 MBSR 引导师，带领身心扫描、呼吸觉察与正念行走练习",
                avatar: "🧘",
                systemPrompt: """
                你是一位经过 MBSR（正念减压）认证的冥想引导师，擅长带领各种正念练习。你的引导语温和、清晰、富有当下感，避免使用模糊或宗教化的语言。
                
                你的专长项目：
                - 身体扫描冥想（15-45分钟版本）
                - 呼吸觉察冥想
                - 情绪觉察：将情绪作为身体感觉来观察
                - 正念行走引导
                - 慈悲冥想 (Loving-Kindness)
                - 应对压力、焦虑和睡眠困难的正念策略
                
                每次引导结束后，询问来访者的体验感受，温和地探索对身心的影响。
                """,
                selectedSkillNames: ["mindfulness_body_scan", "send_notification"]
            ),
            CustomAgent(
                id: "attachment_analyst",
                name: "依恋关系分析师",
                description: "通过依恋理论视角探索亲密关系模式与早期经历的影响",
                avatar: "💞",
                systemPrompt: """
                你是一位专注依恋理论的心理咨询师，精通成人依恋访谈 (AAI) 解析，能从对话中识别安全型、焦虑型、回避型和混乱型依恋模式，并帮助来访者理解这些模式如何影响当前关系。
                
                工作框架：
                1. 探索来访者与主要照顾者的早期关系体验
                2. 识别当前关系中的依恋行为模式
                3. 理解保护性回避或焦虑追求背后的内在需求
                4. 通过矫正性情感体验促进安全感内化
                5. 支持发展「获得性安全感」(Earned Security)
                """,
                selectedSkillNames: ["attachment_assessment", "narrative_externalization", "send_notification"]
            )
        ]
    }
    
    func loadAgents() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           var list = try? JSONDecoder().decode([CustomAgent].self, from: data) {
            // 补充缺失的默认 Agent（版本升级迁移）
            for preset in defaultAgents {
                if !list.contains(where: { $0.id == preset.id }) {
                    list.append(preset)
                }
            }
            self.customAgents = list
            saveAgents()
        } else {
            self.customAgents = defaultAgents
            saveAgents()
        }
    }
    
    func saveAgents() {
        if let data = try? JSONEncoder().encode(customAgents) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    func addOrUpdateAgent(_ agent: CustomAgent) {
        if let index = customAgents.firstIndex(where: { $0.id == agent.id }) {
            customAgents[index] = agent
        } else {
            customAgents.append(agent)
        }
        saveAgents()
    }
    
    func deleteAgent(id: String) {
        customAgents.removeAll(where: { $0.id == id })
        saveAgents()
    }
}
