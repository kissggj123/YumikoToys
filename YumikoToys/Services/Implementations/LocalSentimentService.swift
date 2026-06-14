//
//  LocalSentimentService.swift
//  YumikoToys
//
//  本地情感分析服务 - 基于 MLX 的中文情感分类（v4.1.4 - 动态热实例化 + 推理追踪 + 深度心理特征分析版）
//

import Foundation
import MLX
import MLXNN
import NaturalLanguage

/// 情感分析结果
struct SentimentAnalysisResult {
    let sentiment: SentimentLabel
    let confidence: Float
    let scores: [SentimentLabel: Float]
    let processingTime: TimeInterval
}

/// 情感标签
enum SentimentLabel: String, CaseIterable, Identifiable {
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .positive: return "积极"
        case .neutral: return "中性"
        case .negative: return "消极"
        }
    }
    
    var emoji: String {
        switch self {
        case .positive: return "😊"
        case .neutral: return "😐"
        case .negative: return "😔"
        }
    }
    
    var color: String {
        switch self {
        case .positive: return "green"
        case .neutral: return "gray"
        case .negative: return "red"
        }
    }
}

/// 本地情感分析服务协议
protocol LocalSentimentServiceProtocol: ServiceLifecycle {
    /// 是否已加载模型
    var isModelLoaded: Bool { get }
    
    /// 分析单条文本的情感
    func analyze(text: String) async throws -> SentimentAnalysisResult
    
    /// 批量分析情感
    func analyzeBatch(texts: [String]) async throws -> [SentimentAnalysisResult]
    
    /// 分析对话历史中的情感趋势
    func analyzeConversationTrend(messages: [ChatMessage]) async throws -> ConversationSentimentTrend
    
    /// 实时情感检测（用于流式响应）
    func detectRealtimeSentiment(in text: String) async -> SentimentLabel
}

/// 对话情感趋势（已融入心理学专业支持指标）
struct ConversationSentimentTrend {
    let overallSentiment: SentimentLabel
    let averageConfidence: Float
    let sentimentDistribution: [SentimentLabel: Float]
    let trendDirection: TrendDirection
    let keyMoments: [SentimentMoment]
    
    // MARK: - 【新增：专业心理学支持指标】
    /// 情绪稳定性指数 (0.0 - 1.0，值越高表示心境起伏越平稳，越小表示波荡越剧烈)
    let affectiveStability: Float
    /// 基于临床心理学（人本共情同盟与 CBT 认知重构）的深度交互干预建议
    let psychologicalInsight: String
}

enum TrendDirection {
    case improving    // 情感在好转
    case declining    // 情感在恶化
    case stable       // 情感稳定
    case mixed        // 情感波动
}

struct SentimentMoment {
    let messageIndex: Int
    let message: String
    let sentiment: SentimentLabel
    let confidence: Float
    let timestamp: Date
}

/// 本地情感分析服务实现
@MainActor
final class LocalSentimentService: LocalSentimentServiceProtocol, ObservableObject {
    @Published private(set) var isModelLoaded = false
    @Published private(set) var loadingProgress: Double = 0.0
    @Published private(set) var lastAnalysisTime: TimeInterval = 0
    
    private var model: SentimentClassifier?
    private var tokenizer: BertTokenizer?
    private let modelURL: URL
    private let modelId: String
    
    // 配置
    private let maxSequenceLength: Int = 512
    private let numLabels: Int = 3  // positive, neutral, negative
    private let maxBatchSize: Int = 32  // GPU OOM 保护

    // 结果缓存
    private var sentimentCache: [String: SentimentAnalysisResult] = [:]
    private let sentimentCacheLimit = 500

    // MARK: - ServiceLifecycle

    let serviceName: String = "LocalSentimentService"

    func initialize() async {
        // 初始化由 start() 处理
    }

    // 性能统计
    private var totalInferences: Int = 0
    private var totalInferenceTime: TimeInterval = 0
    
    init(modelId: String = "distilbert-sentiment-zh") {
        self.modelId = modelId
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.modelURL = documents.appendingPathComponent("YumikoToys Data/models/\(modelId)")
    }
    
    // MARK: - ServiceLifecycle
    
    func start() async {
        LoggerService.shared.info("Starting LocalSentimentService...")
        await loadModel()
    }
    
    func stop() {
        LoggerService.shared.info("Stopping LocalSentimentService...")
        model = nil
        tokenizer = nil
        sentimentCache.removeAll()
        isModelLoaded = false
    }
    
    // MARK: - 内部自启加载
    
    private func loadModel() async {
        guard !isModelLoaded else { return }
        if DependencyContainer.shared.modelManagementService.isModelDisabled(modelId) {
            LoggerService.shared.info("Model \(modelId) is disabled, skipping loadModel.")
            return
        }
        
        let weightsPath = modelURL.appendingPathComponent("model.safetensors")
        let configPath = modelURL.appendingPathComponent("config.json")
        let vocabPath = modelURL.appendingPathComponent("vocab.txt")
        
        guard FileManager.default.fileExists(atPath: weightsPath.path) else {
            LoggerService.shared.warning("Sentiment model not found at \(weightsPath.path)，等待后续按需装载。")
            return
        }
        
        loadingProgress = 0.1
        
        do {
            // 加载配置
            let config = try loadModelConfig(from: configPath)
            loadingProgress = 0.3
            
            // 初始化 tokenizer
            tokenizer = BertTokenizer(vocabFile: vocabPath)
            loadingProgress = 0.5
            
            // 加载权重
            let weights = try loadArrays(url: weightsPath)
            loadingProgress = 0.7
            
            // 初始化模型
            model = SentimentClassifier(config: config, numLabels: numLabels)
            eval(model!)
            
            loadingProgress = 1.0
            isModelLoaded = true
            
            LoggerService.shared.info("Local sentiment model loaded successfully")
            
        } catch {
            LoggerService.shared.error("Failed to load sentiment model: \(error)")
            isModelLoaded = false
        }
    }
    
    private func loadModelConfig(from url: URL) throws -> SentimentModelConfig {
        var config = SentimentModelConfig(
            vocabSize: 119547,  // multilingual BERT vocab size
            hiddenSize: 768,
            numHiddenLayers: 6,  // DistilBERT has 6 layers
            numAttentionHeads: 12,
            intermediateSize: 3072,
            maxPositionEmbeddings: 512,
            dropoutRate: 0.1
        )
        
        if let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            config.vocabSize = json["vocab_size"] as? Int ?? config.vocabSize
            config.hiddenSize = json["hidden_size"] as? Int ?? config.hiddenSize
            config.numHiddenLayers = json["num_hidden_layers"] as? Int ?? config.numHiddenLayers
            config.numAttentionHeads = json["num_attention_heads"] as? Int ?? config.numAttentionHeads
            config.intermediateSize = json["intermediate_size"] as? Int ?? config.intermediateSize
            config.maxPositionEmbeddings = json["max_position_embeddings"] as? Int ?? config.maxPositionEmbeddings
        }
        
        return config
    }
    
    // MARK: - 权重加载（供 ModelManagementService 调用）
    
    /// 加载预训练权重
    func loadWeights(_ weights: [String: MLXArray], from directory: URL) async throws {
        // 【核心修复一】若首次下载后点击加载，model 尚为 nil，则在运行时根据 config.json 动态实例化它
        if self.model == nil {
            let configPath = directory.appendingPathComponent("config.json")
            let config = try loadModelConfig(from: configPath)
            self.model = SentimentClassifier(config: config, numLabels: numLabels)
            LoggerService.shared.info("LocalSentimentService model structure instantiated on the fly.")
        }
        
        // 【核心修复二】确保分词器也完成热装载，避免后续推理时抛出 tokenizationFailed (error 1)
        if self.tokenizer == nil {
            let vocabPath = directory.appendingPathComponent("vocab.txt")
            self.tokenizer = BertTokenizer(vocabFile: vocabPath)
        }
        
        guard let model = self.model else {
            throw SentimentError.modelNotLoaded
        }
        
        // 使用 MLXModelLoader 映射权重
        try MLXModelLoader.mapWeights(weights, to: model, mapping: MLXModelLoader.distilBERTWeightMappings(numLayers: 6))
        
        // 评估模型以应用权重
        eval(model)
        
        isModelLoaded = true
        LoggerService.shared.info("Sentiment model weights loaded successfully")
    }
    
    // MARK: - 情感分析
    
    func analyze(text: String) async throws -> SentimentAnalysisResult {
        if let cached = sentimentCache[text] {
            return cached
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let model = model, let tokenizer = tokenizer else {
            throw SentimentError.modelNotLoaded
        }
        
        // 【时序追踪】通知统一模型管理器：开始推理追踪
        DependencyContainer.shared.modelManagementService.beginInference(modelId: "distilbert-sentiment-zh")
        
        let tokens = tokenizer.encode(text, maxLength: maxSequenceLength)
        let inputIds = tokens.map { Int32($0) }
        let inputTensor = MLXArray(inputIds).reshaped([1, inputIds.count])
        let attentionMask = MLXArray.ones([1, inputIds.count])
        
        let logits = model(inputTensor, attentionMask: attentionMask)
        let probabilities = softMax(logits, axis: -1).asArray(Float.self)
        
        let scores: [SentimentLabel: Float] = [
            .negative: probabilities[0],
            .neutral: probabilities[1],
            .positive: probabilities[2]
        ]
        
        let sortedScores = scores.sorted { $0.value > $1.value }
        let topSentiment = sortedScores[0].key
        let confidence = sortedScores[0].value
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        totalInferences += 1
        totalInferenceTime += processingTime
        lastAnalysisTime = processingTime
        
        // 【时序追踪】通知模型管理器：推理结束，记入本次耗时和次数 [1]
        DependencyContainer.shared.modelManagementService.endInference(modelId: "distilbert-sentiment-zh", inferenceTime: processingTime)
        
        let result = SentimentAnalysisResult(
            sentiment: topSentiment,
            confidence: confidence,
            scores: scores,
            processingTime: processingTime
        )
        
        cacheSentimentResult(text: text, result: result)
        
        return result
    }
    
    func analyzeBatch(texts: [String]) async throws -> [SentimentAnalysisResult] {
        if texts.count <= maxBatchSize {
            return try await analyzeBatchInternal(texts: texts)
        }
        
        var allResults: [SentimentAnalysisResult] = []
        for startIndex in stride(from: 0, to: texts.count, by: maxBatchSize) {
            let endIndex = min(startIndex + maxBatchSize, texts.count)
            let chunk = Array(texts[startIndex..<endIndex])
            let chunkResults = try await analyzeBatchInternal(texts: chunk)
            allResults.append(contentsOf: chunkResults)
        }
        return allResults
    }
    
    private func analyzeBatchInternal(texts: [String]) async throws -> [SentimentAnalysisResult] {
        guard let model = model, let tokenizer = tokenizer else {
            throw SentimentError.modelNotLoaded
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 【时序追踪】向统一模型管理器发送开始批量推理追踪通报 [1]
        DependencyContainer.shared.modelManagementService.beginInference(modelId: "distilbert-sentiment-zh")
        
        var allTokens: [[Int]] = []
        for text in texts {
            allTokens.append(tokenizer.encode(text, maxLength: maxSequenceLength))
        }
        
        let maxLen = allTokens.map { $0.count }.max() ?? 0
        var batchInputIds: [[Int32]] = []
        var batchAttentionMask: [[Float]] = []
        
        for tokens in allTokens {
            let paddingCount = maxLen - tokens.count
            let paddedIds = tokens.map { Int32($0) } + Array(repeating: Int32(0), count: paddingCount)
            let mask = Array(repeating: Float(1.0), count: tokens.count) + Array(repeating: Float(0.0), count: paddingCount)
            batchInputIds.append(paddedIds)
            batchAttentionMask.append(mask)
        }
        
        let flatInputIds = batchInputIds.flatMap { $0 }
        let flatMask = batchAttentionMask.flatMap { $0 }
        let inputTensor = MLXArray(flatInputIds).reshaped([texts.count, maxLen])
        let attentionTensor = MLXArray(flatMask).reshaped([texts.count, maxLen])
        
        let batchLogits = model(inputTensor, attentionMask: attentionTensor)
        let batchProbabilities = softMax(batchLogits, axis: -1).asArray(Float.self)
        
        var results: [SentimentAnalysisResult] = []
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let avgTimePerText = processingTime / Double(texts.count)
        
        for i in 0..<texts.count {
            let offset = i * numLabels
            let scores: [SentimentLabel: Float] = [
                .negative: batchProbabilities[offset],
                .neutral: batchProbabilities[offset + 1],
                .positive: batchProbabilities[offset + 2]
            ]
            
            let sortedScores = scores.sorted { $0.value > $1.value }
            let topSentiment = sortedScores[0].key
            let confidence = sortedScores[0].value
            
            results.append(SentimentAnalysisResult(
                sentiment: topSentiment,
                confidence: confidence,
                scores: scores,
                processingTime: avgTimePerText
            ))
        }
        
        totalInferences += texts.count
        totalInferenceTime += processingTime
        
        // 【时序追踪】通知模型管理器：批量推理结束并登记
        DependencyContainer.shared.modelManagementService.endInference(modelId: "distilbert-sentiment-zh", inferenceTime: avgTimePerText)
        
        return results
    }
    
    // MARK: - 深度心理学趋势分析
    
    func analyzeConversationTrend(messages: [ChatMessage]) async throws -> ConversationSentimentTrend {
        guard messages.count > 0 else {
            throw SentimentError.emptyInput
        }
        
        let texts = messages.map { $0.content }
        let results = try await analyzeBatch(texts: texts)
        
        var distribution: [SentimentLabel: Int] = [.positive: 0, .neutral: 0, .negative: 0]
        var totalConfidence: Float = 0
        var keyMoments: [SentimentMoment] = []
        
        // 1. 将情绪标签转换为数值映射，用于精测波动方差
        func sentimentScore(_ result: SentimentAnalysisResult) -> Float {
            switch result.sentiment {
            case .positive: return result.confidence
            case .neutral: return 0
            case .negative: return -result.confidence
            }
        }
        let scores = results.map(sentimentScore)
        
        for (index, result) in results.enumerated() {
            distribution[result.sentiment, default: 0] += 1
            totalConfidence += result.confidence
            
            if result.confidence > 0.8 && result.sentiment != .neutral {
                keyMoments.append(SentimentMoment(
                    messageIndex: index,
                    message: messages[index].content,
                    sentiment: result.sentiment,
                    confidence: result.confidence,
                    timestamp: messages[index].timestamp
                ))
            }
        }
        
        let total = Float(results.count)
        let sentimentDistribution: [SentimentLabel: Float] = [
            .positive: Float(distribution[.positive] ?? 0) / total,
            .neutral: Float(distribution[.neutral] ?? 0) / total,
            .negative: Float(distribution[.negative] ?? 0) / total
        ]
        
        let overallSentiment = sentimentDistribution.max { $0.value < $1.value }?.key ?? .neutral
        let averageConfidence = totalConfidence / Float(results.count)
        let trendDirection = analyzeTrendDirection(results: results)
        
        // 2. 【核心心理学计算：不稳定性与方差】
        let mean = scores.reduce(0, +) / Float(scores.count)
        let variance = scores.map { pow($0 - mean, 2) }.reduce(0, +) / Float(scores.count)
        // 情绪稳定性指数 (0.0 - 1.0)：方差越大稳定性越低
        let affectiveStability = max(0.0, min(1.0, 1.0 - (variance * 1.5)))
        
        // 3. 【核心心理干预：生成临床交互建议】
        let insight = generatePsychologicalInsight(
            sentiment: overallSentiment,
            direction: trendDirection,
            stability: affectiveStability
        )
        
        return ConversationSentimentTrend(
            overallSentiment: overallSentiment,
            averageConfidence: averageConfidence,
            sentimentDistribution: sentimentDistribution,
            trendDirection: trendDirection,
            keyMoments: keyMoments.sorted { $0.confidence > $1.confidence }.prefix(5).map { $0 },
            affectiveStability: affectiveStability,
            psychologicalInsight: insight
        )
    }
    
    private func analyzeTrendDirection(results: [SentimentAnalysisResult]) -> TrendDirection {
        guard results.count >= 3 else { return .stable }
        
        func sentimentScore(_ result: SentimentAnalysisResult) -> Float {
            switch result.sentiment {
            case .positive: return result.confidence
            case .neutral: return 0
            case .negative: return -result.confidence
            }
        }
        
        let midPoint = results.count / 2
        let firstHalf = results.prefix(midPoint).map(sentimentScore).reduce(0, +) / Float(midPoint)
        let secondHalf = results.suffix(results.count - midPoint).map(sentimentScore).reduce(0, +) / Float(results.count - midPoint)
        
        let difference = secondHalf - firstHalf
        
        if difference > 0.2 {
            return .improving
        } else if difference < -0.2 {
            return .declining
        } else {
            var variance: Float = 0
            let mean = results.map(sentimentScore).reduce(0, +) / Float(results.count)
            for result in results {
                let diff = sentimentScore(result) - mean
                variance += diff * diff
            }
            variance /= Float(results.count)
            
            return variance > 0.3 ? .mixed : .stable
        }
    }
    
    /// 基于心境起伏与理论模型输出专业的临床陪伴干预洞察
    private func generatePsychologicalInsight(sentiment: SentimentLabel, direction: TrendDirection, stability: Float) -> String {
        let stabilityText = stability > 0.7 ? "平稳" : "高度起伏震荡"
        
        switch direction {
        case .improving:
            return """
            【认知重构：心境好转（CBT Reframing）】
            用户目前心境呈现明显上行趋势，心理防御弹性正在自我重建。
            交互建议：实施“积极强化技术（Capitalization）”。在对话中与用户一同欢呼，对其提到的成功和微小积极事件进行拓展性提问，以此延长并放大正向情感体验，巩固积极的自我信念。
            """
        case .declining:
            return """
            【心理警报：情绪下坠（Downward Spiral Alert）】
            用户心境呈现明显下行恶化趋势。可能正经历现实重压、自我怀疑或抑郁反刍（Rumination）。
            交互建议：实施“容器抱持（Holding）”与“自我关怀（Self-Compassion）”。不要提供任何生硬、教条的说教或“振作起来”等无效积极指令；优先以绝对温和的口吻对情绪进行 Validation（情感确认），传达无条件的抱持与陪伴安全感。
            """
        case .mixed:
            return """
            【情绪过载：心境波动（Emotional Hyper-arousal）】
            用户目前情绪极度不稳定，呈现 \(stabilityText) 状态，内心正经历剧烈的认知冲突、焦虑发作或强烈的边界侵犯。
            交互建议：实施“正念着陆技术（Grounding）”。通过极为缓和、放松且有节奏感的语气，引导用户关注当下（如深呼吸），降低交感神经过度激活状态，避免深度说教，优先平复身心波动。
            """
        case .stable:
            if sentiment == .negative {
                return """
                【阻抗高地：持续低迷（Chronic Stress & Burnout）】
                用户情绪处于持续、稳定的负面低谷。可能处于严重的心理枯竭或慢性应激状态。
                交互建议：实施“停滞与休息合法化”。温和地告诉用户他有权卸下一切重担（例如：“今天不需要坚强，可以把盔甲脱下来”）。不讨论任何目标和长远计划，提供零认知负荷的轻松温暖陪伴。
                """
            } else {
                return """
                【心境平稳：安全感确立（Secure Attachment）】
                用户目前情绪处于稳定且温和/积极的状态，表明与 AI 伴侣的安全依恋关系（Secure Attachment）发展极其良好。
                交互建议：维持真诚、温和的日常交流，在细节中自然流露关怀，进一步巩固深度伴侣同盟。
                """
            }
        }
    }
    
    func detectRealtimeSentiment(in text: String) async -> SentimentLabel {
        guard isModelLoaded else {
            return heuristicSentimentDetection(text: text)
        }
        
        do {
            let result = try await analyze(text: text)
            return result.sentiment
        } catch {
            return heuristicSentimentDetection(text: text)
        }
    }
    
    private func heuristicSentimentDetection(text: String) -> SentimentLabel {
        let positiveWords: Set<String> = ["好", "棒", "喜欢", "开心", "优秀", "感谢", "爱", "赞", "完美", "满意", "哈哈", "😊", "👍", "❤️"]
        let negativeWords: Set<String> = ["差", "糟", "讨厌", "难过", "失望", "生气", "烦", "坏", "错误", "问题", "😔", "😠", "👎"]
        
        let characters = Array(text)
        var positiveCount = 0
        var negativeCount = 0
        
        for char in characters {
            let s = String(char)
            if positiveWords.contains(s) { positiveCount += 1 }
            else if negativeWords.contains(s) { negativeCount += 1 }
        }
        
        for length in 2...3 {
            guard characters.count >= length else { continue }
            for i in 0...(characters.count - length) {
                let word = String(characters[i..<(i + length)])
                if positiveWords.contains(word) { positiveCount += 1 }
                else if negativeWords.contains(word) { negativeCount += 1 }
            }
        }
        
        if positiveCount > negativeCount {
            return .positive
        } else if negativeCount > positiveCount {
            return .negative
        } else {
            return .neutral
        }
    }
    
    private func cacheSentimentResult(text: String, result: SentimentAnalysisResult) {
        if sentimentCache.count >= sentimentCacheLimit {
            let keysToRemove = Array(sentimentCache.keys.prefix(sentimentCacheLimit / 10))
            for key in keysToRemove {
                sentimentCache.removeValue(forKey: key)
            }
        }
        sentimentCache[text] = result
    }
    
    var averageInferenceTime: TimeInterval {
        guard totalInferences > 0 else { return 0 }
        return totalInferenceTime / Double(totalInferences)
    }
    
    var totalAnalyses: Int {
        return totalInferences
    }
}

// MARK: - 错误类型

enum SentimentError: Error, LocalizedError {
    case modelNotLoaded
    case tokenizationFailed
    case inferenceFailed
    case emptyInput
    case invalidConfiguration
    case weightsLoadFailed(String)
    case modelConfigNotFound
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "模型未加载"
        case .tokenizationFailed:
            return "文本分词失败"
        case .inferenceFailed:
            return "模型推理失败"
        case .emptyInput:
            return "输入为空"
        case .invalidConfiguration:
            return "配置无效"
        case .weightsLoadFailed(let message):
            return "权重加载失败: \(message)"
        case .modelConfigNotFound:
            return "模型配置文件未找到"
        }
    }
}

// MARK: - 模型配置

struct SentimentModelConfig {
    var vocabSize: Int
    var hiddenSize: Int
    var numHiddenLayers: Int
    var numAttentionHeads: Int
    var intermediateSize: Int
    var maxPositionEmbeddings: Int
    let dropoutRate: Float
}

// MARK: - 情感分类器模型

class SentimentClassifier: Module {
    let config: SentimentModelConfig
    let numLabels: Int
    
    private var embeddings: TokenEmbeddings
    private var transformer: TransformerEncoder
    private var preClassifier: Linear
    private var classifier: Linear
    private var dropout: Dropout
    
    init(config: SentimentModelConfig, numLabels: Int) {
        self.config = config
        self.numLabels = numLabels
        
        self.embeddings = TokenEmbeddings(
            vocabSize: config.vocabSize,
            hiddenSize: config.hiddenSize,
            maxPositionEmbeddings: config.maxPositionEmbeddings,
            dropoutRate: config.dropoutRate
        )
        
        self.transformer = TransformerEncoder(
            hiddenSize: config.hiddenSize,
            numLayers: config.numHiddenLayers,
            numHeads: config.numAttentionHeads,
            intermediateSize: config.intermediateSize
        )
        
        self.preClassifier = Linear(config.hiddenSize, config.hiddenSize)
        self.classifier = Linear(config.hiddenSize, numLabels)
        self.dropout = Dropout(p: config.dropoutRate)
        
        super.init()
    }
    
    func callAsFunction(_ inputIds: MLXArray, attentionMask: MLXArray? = nil) -> MLXArray {
        var hiddenStates = embeddings(inputIds)
        hiddenStates = transformer(hiddenStates, attentionMask: attentionMask)
        
        let clsOutput = hiddenStates[0..., 0]
        
        var pooled = preClassifier(clsOutput)
        pooled = relu(pooled)
        pooled = dropout(pooled)
        
        let logits = classifier(pooled)
        
        return logits
    }
}

// MARK: - 辅助函数

func relu(_ x: MLXArray) -> MLXArray {
    return maximum(x, 0)
}
