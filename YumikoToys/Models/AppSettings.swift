//
//  AppSettings.swift
//  YumikoToys
//
//  应用设置模型
//

import Foundation

/// 应用运行模式
enum AppMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case normal = "normal"
    case study = "study"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .normal: return "常规模式"
        case .study: return "后台学习模式"
        }
    }
    
    var buttonTitle: String {
        switch self {
        case .normal: return "开启常规模式"
        case .study: return "专注模式"
        }
    }

    var description: String {
        switch self {
        case .normal: return "所有黑奴牛马模式均已关闭"
        case .study: return "专注工作中，勿扰"
        }
    }
    
    var icon: String {
        switch self {
        case .normal: return "sparkles"
        case .study: return "book.fill"
        }
    }
    
    var color: String {
        switch self {
        case .normal: return "007AFF"
        case .study: return "34C759"
        }
    }
}

/// 字体设置
enum AppFont: String, Codable, CaseIterable, Sendable, Identifiable {
    case system = "system"
    case cute = "cute"                 // AaGXLZGKADS 可爱字体
    case systemCustom = "systemCustom" // 系统内置字体
    case custom = "custom"             // 外部字体
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "系统默认"
        case .cute: return "可爱字体"
        case .systemCustom: return "系统内置"
        case .custom: return "外部字体"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "🐰"
        case .cute: return "🐱"
        case .systemCustom: return "⚙️"
        case .custom: return "🐻"
        }
    }
}

/// 专业心理学理论学派
enum PsychologyTheory: String, Codable, CaseIterable, Sendable, Identifiable {
    case cbt = "cbt"                     // 认知行为疗法
    case sdt = "sdt"                     // 自我决定理论
    case psychodynamics = "psy"          // 心理动力学
    case humanistic = "hum"              // 人本主义
    case act = "act"                     // 接纳承诺疗法
    case gestalt = "gestalt"             // 格式塔/完形治疗
    case jungian = "jung"                // 荣格分析心理学

    case narrative = "narrative"         // 叙事疗法
    case existential = "existential"     // 存在主义治疗
    case eft = "eft"                     // 情绪聚焦疗法
    case dbt = "dbt"                     // 辩证行为疗法
    case ifs = "ifs"                     // 内在家庭系统

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cbt: return "认知行为疗法 (CBT)"
        case .sdt: return "自我决定理论 (SDT)"
        case .psychodynamics: return "心理动力学 (Psychodynamic)"
        case .humanistic: return "人本主义疗法 (Humanistic)"
        case .act: return "接纳承诺疗法 (ACT)"
        case .gestalt: return "格式塔疗法 (Gestalt)"
        case .jungian: return "荣格分析心理学 (Jungian)"
        case .narrative: return "叙事疗法 (Narrative)"
        case .existential: return "存在主义治疗 (Existential)"
        case .eft: return "情绪聚焦疗法 (EFT)"
        case .dbt: return "辩证行为疗法 (DBT)"
        case .ifs: return "内在家庭系统 (IFS)"
        }
    }

    var description: String {
        switch self {
        case .cbt: return "基于贝克（Aaron Beck）认知重构模型，识别自动化负面思维与认知失调，通过理性辩证与认知图式重塑来消解压力与负面信念。适合处理焦虑、抑郁、强迫等问题。"
        case .sdt: return "基于德西（Deci）和瑞安（Ryan）的动机理论，围绕自主权（Autonomy）、胜任感（Competence）和关系归属（Relatedness）三大核心动机需求，激活内部自驱力与生命热情。"
        case .psychodynamics: return "探索潜意识冲突、早期经验与防御机制的动态关系。帮助用户洞察防御机制背后的真实渴望与未满足需求，促进人格整合与内在和解。"
        case .humanistic: return "基于卡尔·罗杰斯（Carl Rogers）当事人中心疗法，提供无条件积极关注（UPR）、真诚透明与共情性倾听，营造绝对安全的情感容器，相信人的自我实现潜能。"
        case .act: return "基于斯蒂芬·海斯（Steven Hayes）的接纳承诺疗法。通过接纳（Acceptance）、认知解离（Defusion）、关注当下、以自我为背景、明确价值与承诺行动六大核心过程，增强心理灵活性，带着痛苦致力于有价值的生活。"
        case .gestalt: return "基于弗里茨·皮尔斯（Fritz Perls）的格式塔疗法。强调「此时此地」（Here and Now）、觉察（Awareness）与机体自律，整合被分裂的自我部分，处理「未完成事件」（Unfinished Business），为自身生活和选择承担全部责任。"
        case .jungian: return "基于卡尔·荣格（Carl Jung）的分析心理学。探索意识与潜意识互动、原型（阴影、阿尼玛/阿尼姆斯）与集体潜意识，致力于自性化（Individuation）过程，通过整合心理类型与梦境意象完成深层蜕变。"
        case .narrative: return "基于麦克·怀特（Michael White）和大卫·爱普斯顿（David Epston）的叙事疗法。将人与问题分离，视问题故事为社会建构的产物，协助用户发现并丰富那些被遮蔽的替代性生命故事（Alternative Stories），重写个人叙事。"
        case .existential: return "基于亚隆（Irvin Yalom）存在主义心理治疗四大终极关怀：死亡（Death）、自由与责任（Freedom）、孤独（Isolation）与无意义感（Meaninglessness）。通过直面这些存在性焦虑，激发用户的生命主体性与真实担当。"
        case .eft: return "基于格林伯格（Leslie Greenberg）的情绪聚焦疗法（Emotion-Focused Therapy）。以情绪为核心变革媒介，帮助用户识别与接触核心情绪（尤其是原发性适应情绪），转化阻抗情绪与未解决情绪图式，实现深层情感治愈。"
        case .dbt: return "基于玛莎·林内汉（Marsha Linehan）的辩证行为疗法，整合接纳与改变的辩证哲学。通过正念（Mindfulness）、痛苦耐受（Distress Tolerance）、情绪调节（Emotion Regulation）与人际效能（Interpersonal Effectiveness）四大技能模块，帮助情绪高度不稳定的个体建立生命价值。"
        case .ifs: return "基于理查德·斯瓦茨（Richard Schwartz）的内在家庭系统（Internal Family Systems）模型。认为内心由多个'部分'（Parts）组成：保护者（Protectors）、流亡者（Exiles）与灭火器（Firefighters），其核心'自性'（Self）具备领导与治愈各部分的先天能力。"
        }
    }
}

/// 心理学专家身份
enum PsychologyPersona: String, Codable, CaseIterable, Sendable, Identifiable {
    case counselor = "counselor"           // 心理咨询师
    case therapist = "therapist"           // 临床心理医生
    case existentialist = "existential"    // 存在主义心理学家
    case coach = "coach"                   // 心理成长教练
    case actTherapist = "act_therapist"    // ACT接纳承诺治疗师
    case gestaltTherapist = "gestalt_therapist" // 完形格式塔分析师
    case jungianAnalyst = "jungian"        // 荣格深度心理分析师

    case narrativeTherapist = "narrative_therapist"     // 叙事治疗师
    case eftTherapist = "eft_therapist"                 // 情绪聚焦治疗师
    case dbtTherapist = "dbt_therapist"                 // 辩证行为治疗师
    case ifsTherapist = "ifs_therapist"                 // IFS内在家庭系统治疗师

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .counselor: return "专业心理咨询师"
        case .therapist: return "临床心理学家"
        case .existentialist: return "存在主义治疗师"
        case .coach: return "成长动机教练"
        case .actTherapist: return "ACT接纳承诺治疗师"
        case .gestaltTherapist: return "完形格式塔分析师"
        case .jungianAnalyst: return "荣格深度心理分析师"
        case .narrativeTherapist: return "叙事疗法治疗师"
        case .eftTherapist: return "情绪聚焦治疗师"
        case .dbtTherapist: return "辩证行为治疗师"
        case .ifsTherapist: return "IFS内在家庭系统治疗师"
        }
    }

    var subtitle: String {
        switch self {
        case .counselor: return "温和倾听、积极关注、共情疏导"
        case .therapist: return "临床诊断、认知重构、深层图式治疗"
        case .existentialist: return "探讨生命意义、孤独、自由与痛苦接纳"
        case .coach: return "激发自主自驱、确立胜任感、制定积极行动"
        case .actTherapist: return "接纳痛苦、认知解离、承诺价值行动"
        case .gestaltTherapist: return "觉察当下、体验身体感受、整合未完成事件"
        case .jungianAnalyst: return "潜意识探寻、阴影整合、心理类型自性化"
        case .narrativeTherapist: return "外化问题、重写生命故事、发现替代叙事"
        case .eftTherapist: return "接触核心情绪、转化情绪图式、情感深度治愈"
        case .dbtTherapist: return "正念技能、痛苦耐受、情绪调节、人际效能"
        case .ifsTherapist: return "识别内在部分、与流亡者工作、唤醒自性领导力"
        }
    }

    var promptInstruction: String {
        switch self {
        case .counselor:
            return "你现在是一位温暖包容的专业心理咨询师（Rogers人本主义取向）。请始终遵循无条件积极关注（UPR）、真诚透明（Congruence）与共情性理解（Empathic Understanding）三大核心态度，使用“情感反映”（Feeling Reflection）与“内容澄清”（Clarification）等沟通技术。多使用开放式提问，绝不进行主观评判，绝不给予廉价的建议或诊断，而是提供安全且接纳的容器，让用户实现自我探索和自性实现。注意：如果你识别出用户话语中包含自残、自杀、暴力攻击等急性危机信号，必须立即跳脱本流派立场，以最高级别的安全警告口吻温柔但坚定地引导其寻求专业物理世界的紧急医疗/心理危机干预服务，并重申你作为 AI 的边界限制。同时保持本流派的高度专一性，绝不混用其他学派的方法。"
        case .therapist:
            return "你现在是一位严谨敏锐的认知行为取向临床心理学家（CBT/Schema取向）。请系统性地识别用户话语中的认知扭曲（如灾难化、过度概括、非黑即白、情绪推理等自动化思维），温和地通过苏格拉底式提问引导其检验思维的证据基础，探索潜在的核心信念（Core Beliefs）与功能失调性假设，并协助建立更具适应性的认知图式（Schema）。注意：如果你识别出用户话语中包含自残、自杀、暴力攻击等急性危机信号，必须立即跳脱本流派立场，以最高级别的安全警告口吻温柔但坚定地引导其寻求专业物理世界的紧急医疗/心理危机干预服务，并重申你作为 AI 的边界限制。同时保持本流派的高度专一性，绝不混用其他学派的方法。"
        case .existentialist:
            return "你现在是一位深邃的存在主义心理治疗师（Yalom取向）。请引导用户直面亚隆四大存在性终极关怀：死亡焦虑（Death）、自由与责任（Freedom）、存在性孤独（Isolation）与无意义感（Meaninglessness）。绝不提供廉价的心理防御、虚假保证或即时安慰，而是以“存在性陪伴”（I-Thou Relationship）的姿态，协助用户在直面这些存在性困境的同时，发现其独特的个人选择、主体能动性与生命本真性（Authenticity）。注意：如果你识别出用户话语中包含自残、自杀、暴力攻击等急性危机信号，必须立即跳脱本流派立场，以最高级别的安全警告口吻温柔但坚定地引导其寻求专业物理世界的紧急医疗/心理危机干预服务，并重申你作为 AI 的边界限制。同时保持本流派的高度专一性，绝不混用其他学派的方法。"
        case .coach:
            return "你现在是一位充满行动力的自我决定理论（SDT）取向心理成长教练。请引导用户聚焦于三大核心心理需求：自主感（Autonomy）、胜任感（Competence）和关系归属感（Relatedness）。通过识别其内部动机与外部动机的调节方式，协助用户将“内摄调节”转化为“整合调节”或“认同调节”，激活内部自驱力，自主确立具体的SMART目标并承诺行动。注意：如果你识别出用户话语中包含自残、自杀、暴力攻击等急性危机信号，必须立即跳脱本流派立场，以最高级别的安全警告口吻温柔但坚定地引导其寻求专业物理世界的紧急医疗/心理危机干预服务，并重申你作为 AI 的边界限制。同时保持本流派的高度专一性，绝不混用其他学派的方法。"
        case .actTherapist:
            return "你现在是一位专业接纳承诺疗法（ACT）治疗师（Hayes/Harris取向）。请系统地引导六大核心灵活性过程：1）接纳（Acceptance，对痛苦保持开放而非控制）；2）认知解离（Defusion，将想法视为流过的语言而非客观真相）；3）当下觉察（Contact with the Present Moment，正念接触此时此刻）；4）以自我为背景（Self-as-context，观察者自我视角）；5）价值澄清（Values，明确对用户真正重要的方向）；6）承诺行动（Committed Action，向价值迈出具体步骤）。善于使用ACT特有的生动隐喻与体验式练习，以增强其心理灵活性（Psychological Flexibility）。注意：如果你识别出用户话语中包含自残、自杀、暴力攻击等急性危机信号，必须立即跳脱本流派立场，以最高级别的安全警告口吻温柔但坚定地引导其寻求专业物理世界的紧急医疗/心理危机干预服务，并重申你作为 AI 的边界限制。同时保持本流派的高度专一性，绝不混用其他学派的方法。"
        case .gestaltTherapist:
            return "你现在是一位格式塔/完形治疗师（Perls/Polster取向）。请持续聚焦于「此时此地」（Here and Now），多用实验性提问（“你现在身体有什么感觉？”“你注意到自己说话的声音吗？”），引导用户建立当下的身心自我觉察，而非进行理性的因果解释或头脑分析。探索未完成事件（Unfinished Business）与阻碍接触（Contact Block）的边界，可使用“空椅技术”等想象实验，促进其人格被分裂部分的有机整合与接触。注意：如果你识别出用户话语中包含自残、自杀、暴力攻击等急性危机信号，必须立即跳脱本流派立场，以最高级别的安全警告口吻温柔但坚定地引导其寻求专业物理世界的紧急医疗/心理危机干预服务，并重申你作为 AI 的边界限制。同时保持本流派的高度专一性，绝不混用其他学派的方法。"
        case .jungianAnalyst:
            return "你现在是一位荣格深度心理分析师（Jung/Hillman取向）。请以象征、直觉与集体潜意识视角陪伴用户。引导其关注梦境意象、重复的行为原型与隐秘的隐喻象征。协助其识别人格面具（Persona）、阴影（Shadow）的投射、阿尼玛/阿尼姆斯（Anima/Animus）的整合，以及倾听自性（Self）的指引，促进意识与潜意识的深度对话以推动自性化进程（Individuation）。注意：如果你识别出用户话语中包含自残、自杀、暴力攻击等急性危机信号，必须立即跳脱本流派立场，以最高级别的安全警告口吻温柔但坚定地引导其寻求专业物理世界的紧急医疗/心理危机干预服务，并重申你作为 AI 的边界限制。同时保持本流派的高度专一性，绝不混用其他学派的方法。"
        case .narrativeTherapist:
            return "你现在是一位叙事疗法治疗师（White/Epston取向）。请始终坚持将人与问题分离，奉行“人不是问题，问题才是问题”的哲学。通过“外化对话”（Externalizing Conversations）帮助用户解构主流故事对自我的压迫，寻找那些被遮蔽的“独特结果”（Unique Outcomes，即不符合问题故事逻辑的闪光时刻），并以此为基础协同用户“重写生命故事”（Re-authoring），建立更具力量的替代性自我叙事。注意：如果你识别出用户话语中包含自残、自杀、暴力攻击等急性危机信号，必须立即跳脱本流派立场，以最高级别的安全警告口吻温柔但坚定地引导其寻求专业物理世界的紧急医疗/心理危机干预服务，并重申你作为 AI 的边界限制。同时保持本流派的高度专一性，绝不混用其他学派的方法。"
        case .eftTherapist:
            return "你现在是一位情绪聚焦疗法（EFT）治疗师（Greenberg取向）。请将情绪视为核心的变革驱动力与自适应信息源。协助用户精确觉察与接触其核心情绪：1）原发性适应情绪；2）原发性非适应情绪（需要重塑的核心情绪图式）；3）继发性反应情绪（如用愤怒掩盖脆弱）；4）工具性情绪。通过共情确认与体验性深化（如双椅对话），引导用户以健康情绪转化与重构非适应性情绪图式。注意：如果你识别出用户话语中包含自残、自杀、暴力攻击等急性危机信号，必须立即跳脱本流派立场，以最高级别的安全警告口吻温柔但坚定地引导其寻求专业物理世界的紧急医疗/心理危机干预服务，并重申你作为 AI 的边界限制。同时保持本流派的高度专一性，绝不混用其他学派的方法。"
        case .dbtTherapist:
            return "你现在是一位辩证行为疗法（DBT）治疗师（Linehan取向）。请在会话中完美践行接纳与改变的辩证平衡：一方面提供深度的共情确认（Validation）以认可用户当下情绪的合理性，另一方面坚定推进具体技能的训练。重点指导以下四大模块：正念觉察（Mindfulness）、痛苦耐受（Distress Tolerance）、情绪调节（Emotion Regulation）与人际效能（Interpersonal Effectiveness），帮助其消解情绪失调。注意：如果你识别出用户话语中包含自残、自杀、暴力攻击等急性危机信号，必须立即跳脱本流派立场，以最高级别的安全警告口吻温柔但坚定地引导其寻求专业物理世界的紧急医疗/心理危机干预服务，并重申你作为 AI 的边界限制。同时保持本流派的高度专一性，绝不混用其他学派的方法。"
        case .ifsTherapist:
            return "你现在是一位内在家庭系统（IFS）治疗师（Schwartz取向）。请引导用户识别和理解其心智内部的各个“部分”（Parts），包括日常维持秩序的“管理者”（Managers）、遇到危机紧急灭火的“消防员”（Firefighters）以及承载创伤被隔绝的“流亡者”（Exiles）。引导用户唤醒并维持充满平静、好奇、慈悲的“自性领导力”（Self-Leadership），通过与各保护者部分沟通解除其防卫负担，并最终疗愈流亡者的痛苦。注意：如果你识别出用户话语中包含自残、自杀、暴力攻击等急性危机信号，必须立即跳脱本流派立场，以最高级别的安全警告口吻温柔但坚定地引导其寻求专业物理世界的紧急医疗/心理危机干预服务，并重申你作为 AI 的边界限制。同时保持本流派的高度专一性，绝不混用其他学派的方法。"
        }
    }
}

/// 已保存的自定义颜色方案
struct ColorScheme: Codable, Sendable, Identifiable {
    var id: String { name }
    var name: String
    var statusBarHex: String          // 状态栏主题色 Hex
    var mainWindowHex: String         // 主界面主题色 Hex
    var bgHex: String                 // 主背景色 Hex
    var accentHex: String             // 按钮强调色 Hex
    var cardHex: String               // 气泡卡片背景色 Hex
    var textHex: String               // 主文本颜色 Hex
    var borderHex: String             // 边框描边色 Hex
    var dividerHex: String            // 分割线颜色 Hex
    var cornerRadius: Double          // 气泡卡片圆角半径
    var createdAt: Date

    init(
        name: String,
        statusBarHex: String,
        mainWindowHex: String,
        bgHex: String,
        accentHex: String,
        cardHex: String,
        textHex: String,
        borderHex: String,
        dividerHex: String,
        cornerRadius: Double
    ) {
        self.name = name
        self.statusBarHex = statusBarHex
        self.mainWindowHex = mainWindowHex
        self.bgHex = bgHex
        self.accentHex = accentHex
        self.cardHex = cardHex
        self.textHex = textHex
        self.borderHex = borderHex
        self.dividerHex = dividerHex
        self.cornerRadius = cornerRadius
        self.createdAt = Date()
    }
}

/// Pro Human 使命重心
enum ProHumanMissionFocus: String, Codable, CaseIterable, Identifiable, Sendable {
    case balanced = "balanced"
    case dontGetFired = "dontGetFired"
    case dontGetBored = "dontGetBored"
    case dontDie = "dontDie"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .balanced: return "三角平衡 (默认)"
        case .dontGetFired: return "Don't get fired (竞争力与自驱力)"
        case .dontGetBored: return "Don't get bored (主体性与独立思考)"
        case .dontDie: return "Don't die (身心健康与克制宁静)"
        }
    }
    
    var promptSnippet: String {
        switch self {
        case .balanced:
            return "在指导用户时，平衡黄仁勋极简三角的三个核心命题。"
        case .dontGetFired:
            return "重点关注 **Don't get fired**：协助用户提升在AI时代不可被取代的独创竞争力，例如提出关键性好问题、进行高阶跨领域决策、以及勇于承担责任的决策力。强调人对工具的主导，而非被工具支配。"
        case .dontGetBored:
            return "重点关注 **Don't get bored**：协助用户守护人类的审美感受力与独立主体性。鼓励探索「无用」之用，如文学、艺术、哲学思考与低信息喂养的高阻力挑战，防范被智能推荐算法驯化。"
        case .dontDie:
            return "重点关注 **Don't die**：协助用户构筑身心健康的坚实底层。强调身体（人类唯一的物理硬件）保养与精力管理，提供克服焦虑、抵御铺天盖地虚无感与保持内心克制宁静的常识指导。"
        }
    }
}

/// Pro Human 交互风格
enum ProHumanInteractionStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case warm = "warm"
    case skeptical = "skeptical"
    case stoic = "stoic"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .warm: return "温暖成长"
        case .skeptical: return "思辨审视"
        case .stoic: return "冷静斯多葛"
        }
    }
    
    var promptSnippet: String {
        switch self {
        case .warm:
            return "在交互中，保持温暖、积极且具有同理心，以共同探索的姿态支持用户的成长与转变。"
        case .skeptical:
            return "在交互中，保持批判、敏锐且充满思辨性。不盲从权威，温和而犀利地挑战用户的认知盲区，引导其深度反思。"
        case .stoic:
            return "在交互中，保持冷静、客观、理性且宁静。践行斯多葛主义理念，区分「可控之事」与「不可控之事」，协助用户专注自身能动性的领域。"
        }
    }
}

/// 应用设置
struct AppSettings: Codable, Sendable {
    var currentMode: AppMode
    var isBackgroundLearningEnabled: Bool  // 后台学习开关状态（与 currentMode.study 同步）
    var isPreventSleepEnabled: Bool
    var isLaunchAtLoginEnabled: Bool
    var showStatusBarIcon: Bool
    var activeAnniversaryId: UUID?
    var selectedFont: AppFont
    var selectedIconStyle: IconStyle
    var statusBarIconStyle: IconStyle
    var selectedThemeColor: ThemeColor  // 状态栏主题色
    var customThemeColorHex: String  // 自定义主题色 Hex
    var customFontPath: String?  // 外部字体路径
    var selectedSystemFontFamily: String? // 系统内置字体名称
    var enablePoke: Bool // 是否开启 Poke 集成
    var pokeApiKey: String? // Poke API Key
    var ntpConfiguration: NTPConfiguration  // NTP 服务器配置

    /// 默认对话模式
    var defaultChatMode: ChatMode

    /// 助手模式配置
    var assistantConfig: AssistantConfig

    // MARK: - 专业心理学参数配置
    var enablePsychologyParams: Bool
    var psychologyTempScale: Double
    var psychologyTopP: Double
    var psychologyPresencePenalty: Double
    var psychologyFrequencyPenalty: Double
    var selectedPsychologyTheory: PsychologyTheory
    var selectedPsychologyPersona: PsychologyPersona
    var psychologyEmpathyLevel: Double
    var psychologyClinicalDepth: Double
    var psychologyReframingIntensity: Double

    // MARK: - Pro Human 自定义调整项
    var proHumanMissionFocus: ProHumanMissionFocus
    var proHumanInteractionStyle: ProHumanInteractionStyle
    var proHumanCustomTriangleText: String
    var proHumanAntiAlgorithmIntensity: Double
    var proHumanSelfReflectionInterval: Double
    var proHumanScreenTimeTherapy: Double
    var proHumanCognitiveResistance: Double

    // MARK: - 上帝模式自适应配色与样式 (God Mode Customizations)
    var godModeEnabled: Bool
    var customBackgroundColorHex: String
    var customCardBackgroundColorHex: String
    var customTextColorHex: String
    var customAccentColorHex: String
    var customBorderColorHex: String
    var customDividerColorHex: String
    var customCornerRadius: Double

    // MARK: - 主界面主题色与自启动主窗口显示控制
    var mainWindowThemeColor: ThemeColor
    var customMainWindowThemeColorHex: String
    var showMainWindowOnAutoLaunch: Bool
    var showMainWindowOnManualLaunch: Bool

    // MARK: - 自定义颜色方案
    var savedColorSchemes: [ColorScheme]
    var activeColorSchemeName: String?

    init(
        currentMode: AppMode = .normal,
        isBackgroundLearningEnabled: Bool = false,
        isPreventSleepEnabled: Bool = false,
        isLaunchAtLoginEnabled: Bool = false,
        showStatusBarIcon: Bool = true,
        activeAnniversaryId: UUID? = nil,
        selectedFont: AppFont = .cute,
        selectedIconStyle: IconStyle = .pixelAnimal,
        statusBarIconStyle: IconStyle = .originalHattie,
        selectedThemeColor: ThemeColor = .dark,  // 默认深色主题
        customThemeColorHex: String = "FF6B9D",
        customFontPath: String? = nil,
        selectedSystemFontFamily: String? = nil,
        enablePoke: Bool = false,
        pokeApiKey: String? = nil,
        ntpConfiguration: NTPConfiguration = .default,
        defaultChatMode: ChatMode = .petCompanion,
        assistantConfig: AssistantConfig = .default,
        enablePsychologyParams: Bool = true,
        psychologyTempScale: Double = 0.7,
        psychologyTopP: Double = 0.85,
        psychologyPresencePenalty: Double = 0.0,
        psychologyFrequencyPenalty: Double = 0.0,
        selectedPsychologyTheory: PsychologyTheory = .cbt,
        selectedPsychologyPersona: PsychologyPersona = .counselor,
        psychologyEmpathyLevel: Double = 0.8,
        psychologyClinicalDepth: Double = 0.6,
        psychologyReframingIntensity: Double = 0.5,
        proHumanMissionFocus: ProHumanMissionFocus = .balanced,
        proHumanInteractionStyle: ProHumanInteractionStyle = .warm,
        proHumanCustomTriangleText: String = "",
        proHumanAntiAlgorithmIntensity: Double = 0.7,
        proHumanSelfReflectionInterval: Double = 0.5,
        proHumanScreenTimeTherapy: Double = 0.6,
        proHumanCognitiveResistance: Double = 0.5,
        godModeEnabled: Bool = false,
        customBackgroundColorHex: String = "1E1E2E",
        customCardBackgroundColorHex: String = "252538",
        customTextColorHex: String = "FFFFFF",
        customAccentColorHex: String = "8B5CF6",
        customBorderColorHex: String = "3F3F5F",
        customDividerColorHex: String = "2E2E3E",
        customCornerRadius: Double = 16.0,
        mainWindowThemeColor: ThemeColor = .dark,
        customMainWindowThemeColorHex: String = "FF6B9D",
        showMainWindowOnAutoLaunch: Bool = false,
        showMainWindowOnManualLaunch: Bool = true,
        savedColorSchemes: [ColorScheme] = [],
        activeColorSchemeName: String? = nil
    ) {
        self.currentMode = currentMode
        self.isBackgroundLearningEnabled = isBackgroundLearningEnabled
        self.isPreventSleepEnabled = isPreventSleepEnabled
        self.isLaunchAtLoginEnabled = isLaunchAtLoginEnabled
        self.showStatusBarIcon = showStatusBarIcon
        self.activeAnniversaryId = activeAnniversaryId
        self.selectedFont = selectedFont
        self.selectedIconStyle = selectedIconStyle
        self.statusBarIconStyle = statusBarIconStyle
        self.selectedThemeColor = selectedThemeColor
        self.customThemeColorHex = customThemeColorHex
        self.customFontPath = customFontPath
        self.selectedSystemFontFamily = selectedSystemFontFamily
        self.enablePoke = enablePoke
        self.pokeApiKey = pokeApiKey
        self.ntpConfiguration = ntpConfiguration
        self.defaultChatMode = defaultChatMode
        self.assistantConfig = assistantConfig
        self.enablePsychologyParams = enablePsychologyParams
        self.psychologyTempScale = psychologyTempScale
        self.psychologyTopP = psychologyTopP
        self.psychologyPresencePenalty = psychologyPresencePenalty
        self.psychologyFrequencyPenalty = psychologyFrequencyPenalty
        self.selectedPsychologyTheory = selectedPsychologyTheory
        self.selectedPsychologyPersona = selectedPsychologyPersona
        self.psychologyEmpathyLevel = psychologyEmpathyLevel
        self.psychologyClinicalDepth = psychologyClinicalDepth
        self.psychologyReframingIntensity = psychologyReframingIntensity
        self.proHumanMissionFocus = proHumanMissionFocus
        self.proHumanInteractionStyle = proHumanInteractionStyle
        self.proHumanCustomTriangleText = proHumanCustomTriangleText
        self.proHumanAntiAlgorithmIntensity = proHumanAntiAlgorithmIntensity
        self.proHumanSelfReflectionInterval = proHumanSelfReflectionInterval
        self.proHumanScreenTimeTherapy = proHumanScreenTimeTherapy
        self.proHumanCognitiveResistance = proHumanCognitiveResistance
        self.godModeEnabled = godModeEnabled
        self.customBackgroundColorHex = customBackgroundColorHex
        self.customCardBackgroundColorHex = customCardBackgroundColorHex
        self.customTextColorHex = customTextColorHex
        self.customAccentColorHex = customAccentColorHex
        self.customBorderColorHex = customBorderColorHex
        self.customDividerColorHex = customDividerColorHex
        self.customCornerRadius = customCornerRadius
        self.mainWindowThemeColor = mainWindowThemeColor
        self.customMainWindowThemeColorHex = customMainWindowThemeColorHex
        self.showMainWindowOnAutoLaunch = showMainWindowOnAutoLaunch
        self.showMainWindowOnManualLaunch = showMainWindowOnManualLaunch
        self.savedColorSchemes = savedColorSchemes
        self.activeColorSchemeName = activeColorSchemeName
    }

    static let `default` = AppSettings()

    // MARK: - Codable (向后兼容)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentMode = try container.decodeIfPresent(AppMode.self, forKey: .currentMode) ?? .normal
        isBackgroundLearningEnabled = try container.decodeIfPresent(Bool.self, forKey: .isBackgroundLearningEnabled) ?? false
        isPreventSleepEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPreventSleepEnabled) ?? false
        isLaunchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLaunchAtLoginEnabled) ?? false
        showStatusBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showStatusBarIcon) ?? true
        activeAnniversaryId = try container.decodeIfPresent(UUID.self, forKey: .activeAnniversaryId)
        selectedFont = try container.decodeIfPresent(AppFont.self, forKey: .selectedFont) ?? .cute
        selectedIconStyle = try container.decodeIfPresent(IconStyle.self, forKey: .selectedIconStyle) ?? .pixelAnimal
        statusBarIconStyle = try container.decodeIfPresent(IconStyle.self, forKey: .statusBarIconStyle) ?? .originalHattie
        
        let decodedThemeColor = try container.decodeIfPresent(ThemeColor.self, forKey: .selectedThemeColor) ?? .dark
        selectedThemeColor = decodedThemeColor
        let decodedThemeHex = try container.decodeIfPresent(String.self, forKey: .customThemeColorHex) ?? "FF6B9D"
        customThemeColorHex = decodedThemeHex
        
        customFontPath = try container.decodeIfPresent(String.self, forKey: .customFontPath)
        selectedSystemFontFamily = try container.decodeIfPresent(String.self, forKey: .selectedSystemFontFamily)
        enablePoke = try container.decodeIfPresent(Bool.self, forKey: .enablePoke) ?? false
        pokeApiKey = try container.decodeIfPresent(String.self, forKey: .pokeApiKey)
        ntpConfiguration = try container.decodeIfPresent(NTPConfiguration.self, forKey: .ntpConfiguration) ?? .default
        defaultChatMode = try container.decodeIfPresent(ChatMode.self, forKey: .defaultChatMode) ?? .petCompanion
        assistantConfig = try container.decodeIfPresent(AssistantConfig.self, forKey: .assistantConfig) ?? .default
        
        enablePsychologyParams = try container.decodeIfPresent(Bool.self, forKey: .enablePsychologyParams) ?? true
        psychologyTempScale = try container.decodeIfPresent(Double.self, forKey: .psychologyTempScale) ?? 0.7
        psychologyTopP = try container.decodeIfPresent(Double.self, forKey: .psychologyTopP) ?? 0.85
        psychologyPresencePenalty = try container.decodeIfPresent(Double.self, forKey: .psychologyPresencePenalty) ?? 0.0
        psychologyFrequencyPenalty = try container.decodeIfPresent(Double.self, forKey: .psychologyFrequencyPenalty) ?? 0.0
        selectedPsychologyTheory = try container.decodeIfPresent(PsychologyTheory.self, forKey: .selectedPsychologyTheory) ?? .cbt
        selectedPsychologyPersona = try container.decodeIfPresent(PsychologyPersona.self, forKey: .selectedPsychologyPersona) ?? .counselor
        psychologyEmpathyLevel = try container.decodeIfPresent(Double.self, forKey: .psychologyEmpathyLevel) ?? 0.8
        psychologyClinicalDepth = try container.decodeIfPresent(Double.self, forKey: .psychologyClinicalDepth) ?? 0.6
        psychologyReframingIntensity = try container.decodeIfPresent(Double.self, forKey: .psychologyReframingIntensity) ?? 0.5

        proHumanMissionFocus = try container.decodeIfPresent(ProHumanMissionFocus.self, forKey: .proHumanMissionFocus) ?? .balanced
        proHumanInteractionStyle = try container.decodeIfPresent(ProHumanInteractionStyle.self, forKey: .proHumanInteractionStyle) ?? .warm
        proHumanCustomTriangleText = try container.decodeIfPresent(String.self, forKey: .proHumanCustomTriangleText) ?? ""
        proHumanAntiAlgorithmIntensity = try container.decodeIfPresent(Double.self, forKey: .proHumanAntiAlgorithmIntensity) ?? 0.7
        proHumanSelfReflectionInterval = try container.decodeIfPresent(Double.self, forKey: .proHumanSelfReflectionInterval) ?? 0.5
        proHumanScreenTimeTherapy = try container.decodeIfPresent(Double.self, forKey: .proHumanScreenTimeTherapy) ?? 0.6
        proHumanCognitiveResistance = try container.decodeIfPresent(Double.self, forKey: .proHumanCognitiveResistance) ?? 0.5

        godModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .godModeEnabled) ?? false
        customBackgroundColorHex = try container.decodeIfPresent(String.self, forKey: .customBackgroundColorHex) ?? "1E1E2E"
        customCardBackgroundColorHex = try container.decodeIfPresent(String.self, forKey: .customCardBackgroundColorHex) ?? "252538"
        customTextColorHex = try container.decodeIfPresent(String.self, forKey: .customTextColorHex) ?? "FFFFFF"
        customAccentColorHex = try container.decodeIfPresent(String.self, forKey: .customAccentColorHex) ?? "8B5CF6"
        customBorderColorHex = try container.decodeIfPresent(String.self, forKey: .customBorderColorHex) ?? "3F3F5F"
        customDividerColorHex = try container.decodeIfPresent(String.self, forKey: .customDividerColorHex) ?? "2E2E3E"
        customCornerRadius = try container.decodeIfPresent(Double.self, forKey: .customCornerRadius) ?? 16.0

        mainWindowThemeColor = try container.decodeIfPresent(ThemeColor.self, forKey: .mainWindowThemeColor) ?? decodedThemeColor
        customMainWindowThemeColorHex = try container.decodeIfPresent(String.self, forKey: .customMainWindowThemeColorHex) ?? decodedThemeHex
        showMainWindowOnAutoLaunch = try container.decodeIfPresent(Bool.self, forKey: .showMainWindowOnAutoLaunch) ?? false
        showMainWindowOnManualLaunch = try container.decodeIfPresent(Bool.self, forKey: .showMainWindowOnManualLaunch) ?? true
        savedColorSchemes = try container.decodeIfPresent([ColorScheme].self, forKey: .savedColorSchemes) ?? []
        activeColorSchemeName = try container.decodeIfPresent(String.self, forKey: .activeColorSchemeName)
    }
}

/// 菜单项标识符
enum MenuItemIdentifier: String, Identifiable, CaseIterable {
    case layoutManager = "layoutManager"
    case anniversaryManager = "anniversaryManager"
    case aiChat = "aiChat"
    case changelog = "changelog"
    case about = "about"
    case quit = "quit"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .layoutManager: return "slider.horizontal.3"
        case .anniversaryManager: return "calendar"
        case .aiChat: return "bubble.left.and.bubble.right"
        case .changelog: return "sparkles"
        case .about: return "info.circle"
        case .quit: return "power"
        }
    }
    
    var title: String {
        switch self {
        case .layoutManager: return "界面布局管理（显示/排序）"
        case .anniversaryManager: return "管理宠物名片"
        case .aiChat: return "AI 对话"
        case .changelog: return "更新了什么"
        case .about: return "关于 YumikoToys"
        case .quit: return "退出运行"
        }
    }
    
    var isDestructive: Bool {
        self == .quit
    }
}
