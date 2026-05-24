//
//  SemanticDeduplicationService.swift
//  YumikoToys
//
//  语义去重服务 - 基于本地 Embedding 的智能去重（v2.1 - 跨心理学维度语义去重优化版）
//  替换原有的 Levenshtein 编辑距离去重，提升语义理解能力
//

import Foundation

/// 语义去重服务协议
protocol SemanticDeduplicationServiceProtocol: ServiceLifecycle {
    /// 检查新偏好是否与已有偏好语义重复
    func isSemanticDuplicate(_ newPreference: UserPreference, existing: [UserPreference]) async -> Bool
    
    /// 批量去重：从偏好列表中找出所有语义重复项
    func findDuplicates(in preferences: [UserPreference]) async -> [(original: Int, duplicate: Int)]
    
    /// 合并偏好列表（自动去重）
    func mergePreferences(_ newPreferences: [UserPreference], existing: [UserPreference]) async -> [UserPreference]
    
    /// 计算两个偏好的语义相似度
    func similarity(between pref1: UserPreference, and pref2: UserPreference) async -> Float
}

/// 语义去重服务实现
@MainActor
final class SemanticDeduplicationService: SemanticDeduplicationServiceProtocol {
    private let embeddingService: LocalEmbeddingServiceProtocol
    
    /// 语义相似度阈值（超过此值视为重复）
    private let similarityThreshold: Float = 0.82
    
    /// 同 key 时的阈值（同类型偏好要求更严格）
    private let sameKeyThreshold: Float = 0.75
    
    init(embeddingService: LocalEmbeddingServiceProtocol) {
        self.embeddingService = embeddingService
    }

    // MARK: - ServiceLifecycle

    let serviceName: String = "SemanticDeduplicationService"

    func initialize() async {
        // 初始化由 start() 处理
    }

    func start() async {
        LoggerService.shared.info("Starting SemanticDeduplicationService...")
    }
    
    func stop() {
        LoggerService.shared.info("Stopping SemanticDeduplicationService...")
    }
    
    // MARK: - 语义去重核心逻辑
    
    func isSemanticDuplicate(_ newPreference: UserPreference, existing: [UserPreference]) async -> Bool {
        // 如果 Embedding 服务未加载，回退到精确匹配
        guard embeddingService.isModelLoaded else {
            return isExactDuplicate(newPreference, existing: existing)
        }
        
        for existingPref in existing {
            // 1. 精确匹配（快速路径）
            if isExactMatch(newPreference, existingPref) {
                return true
            }
            
            // 2. 同 key 语义相似度检测
            if newPreference.key == existingPref.key {
                let sim = await similarity(between: newPreference, and: existingPref)
                if sim >= sameKeyThreshold {
                    LoggerService.shared.debug("Semantic duplicate found: '\(newPreference.value)' vs '\(existingPref.value)' (similarity: \(sim))")
                    return true
                }
            }
            
            // 3. 跨 key 语义检测（如"喜欢猫咪" vs "宠物：猫"）
            let crossKeySim = await crossKeySimilarity(newPreference, existingPref)
            if crossKeySim >= similarityThreshold {
                LoggerService.shared.debug("Cross-key semantic duplicate: '\(newPreference.key):\(newPreference.value)' vs '\(existingPref.key):\(existingPref.value)' (similarity: \(crossKeySim))")
                return true
            }
        }
        
        return false
    }
    
    func findDuplicates(in preferences: [UserPreference]) async -> [(original: Int, duplicate: Int)] {
        guard embeddingService.isModelLoaded else {
            // 回退到精确匹配去重
            return findExactDuplicates(in: preferences)
        }
        
        var duplicates: [(original: Int, duplicate: Int)] = []
        
        for i in 0..<preferences.count {
            for j in (i+1)..<preferences.count {
                let sim = await similarity(between: preferences[i], and: preferences[j])
                let threshold = preferences[i].key == preferences[j].key ? sameKeyThreshold : similarityThreshold
                
                if sim >= threshold {
                    duplicates.append((original: i, duplicate: j))
                }
            }
        }
        
        return duplicates
    }
    
    func mergePreferences(_ newPreferences: [UserPreference], existing: [UserPreference]) async -> [UserPreference] {
        var result = existing
        
        for newPref in newPreferences {
            let isDup = await isSemanticDuplicate(newPref, existing: result)
            if !isDup {
                result.append(newPref)
                LoggerService.shared.debug("Added preference: [\(newPref.key)] \(newPref.value)")
            } else {
                LoggerService.shared.debug("Skipped semantic duplicate: [\(newPref.key)] \(newPref.value)")
            }
        }
        
        return result
    }
    
    func similarity(between pref1: UserPreference, and pref2: UserPreference) async -> Float {
        // 构建完整的偏好文本（key + value）
        let text1 = "\(pref1.key):\(pref1.value)"
        let text2 = "\(pref2.key):\(pref2.value)"
        
        do {
            return try await embeddingService.similarity(between: text1, and: text2)
        } catch {
            // Embedding 失败时回退到字符串相似度
            return stringSimilarity(text1, text2)
        }
    }
    
    // MARK: - 跨 key 语义检测
    
    private func crossKeySimilarity(_ pref1: UserPreference, _ pref2: UserPreference) async -> Float {
        // 【核心优化：跨心理学维度对齐】定义 key 的语义关联组，加入心理学、情绪、应对方式大类的交叉检测
        let relatedKeyGroups: [[String]] = [
            ["喜欢", "宠物", "动物"],
            ["饮食偏好", "爱吃", "喜欢吃", "饮食禁忌"],
            ["游戏", "角色扮演", "娱乐"],
            ["居住地", "坐标", "城市"],
            ["作息", "习惯", "生活方式", "应对方式"],
            
            // 👈 新增专业心理学大类交叉检测，避免相似心境下的数据冗余 [1]
            ["压力源", "情感", "健康", "焦虑"],
            ["自我评估", "自我介绍", "性格"]
        ]
        
        // 检查两个 key 是否在同一语义组
        let areRelatedKeys = relatedKeyGroups.contains { group in
            group.contains(pref1.key) && group.contains(pref2.key)
        }
        
        // 只有相关 key 才进行跨 key 语义比较
        guard areRelatedKeys else { return 0.0 }
        
        // 比较 value 的语义相似度
        do {
            return try await embeddingService.similarity(between: pref1.value, and: pref2.value)
        } catch {
            return 0.0
        }
    }
    
    // MARK: - 回退方法
    
    private func isExactDuplicate(_ preference: UserPreference, existing: [UserPreference]) -> Bool {
        existing.contains { existingPref in
            existingPref.key == preference.key && existingPref.value == preference.value
        }
    }
    
    private func isExactMatch(_ pref1: UserPreference, _ pref2: UserPreference) -> Bool {
        pref1.key == pref2.key && pref1.value == pref2.value
    }
    
    private func findExactDuplicates(in preferences: [UserPreference]) -> [(original: Int, duplicate: Int)] {
        var duplicates: [(original: Int, duplicate: Int)] = []
        
        for i in 0..<preferences.count {
            for j in (i+1)..<preferences.count {
                if isExactMatch(preferences[i], preferences[j]) {
                    duplicates.append((original: i, duplicate: j))
                }
            }
        }
        
        return duplicates
    }
    
    /// 简单的字符串相似度（Jaccard 系数）作为回退
    private func stringSimilarity(_ s1: String, _ s2: String) -> Float {
        let set1 = Set(s1)
        let set2 = Set(s2)
        
        let intersection = set1.intersection(set2).count
        let union = set1.union(set2).count
        
        guard union > 0 else { return 0.0 }
        return Float(intersection) / Float(union)
    }
}

// MARK: - 偏好文本扩展

extension UserPreference {
    /// 用于语义比较的完整文本表示
    var semanticText: String {
        return "\(key):\(value)"
    }
}
