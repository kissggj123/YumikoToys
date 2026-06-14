//
//  LocalEmbeddingService.swift
//  YumikoToys
//
//  本地 Embedding 服务 - 基于 MLX 的语义向量化（v4.1.4 - 动态自适应热实例化、推理追踪与心理学语义测算版）
//

import Foundation
import MLX
import MLXNN
import NaturalLanguage

/// 本地 Embedding 服务协议
protocol LocalEmbeddingServiceProtocol: ServiceLifecycle {
    /// 是否已加载模型
    var isModelLoaded: Bool { get }
    
    /// 获取文本的 Embedding 向量
    func embed(text: String) async throws -> [Float]
    
    /// 计算两个文本的语义相似度 (0.0 - 1.0)
    func similarity(between text1: String, and text2: String) async throws -> Float
    
    /// 批量计算相似度
    func batchSimilarity(query: String, candidates: [String]) async throws -> [(index: Int, similarity: Float)]
    
    /// 查找最相似的文本
    func findMostSimilar(to query: String, in candidates: [String], threshold: Float) async throws -> (index: Int?, similarity: Float)
    
    // MARK: - 【新增：专业心理学支持接口】
    /// 计算用户文本与特定心理学临床大类的语义共鸣度 (0.0 - 1.0)
    func calculatePsychologicalResonance(text: String, categories: [String]) async throws -> [(category: String, similarity: Float)]
    
    /// 基于 CBT 认知行为疗法，诊断用户当前叙述中的主导“认知偏误/失调”特征
    func diagnoseCognitiveDistortion(text: String, threshold: Float) async throws -> (distortion: String?, similarity: Float)
}

/// 本地 Embedding 服务实现
@MainActor
final class LocalEmbeddingService: LocalEmbeddingServiceProtocol, ObservableObject {
    @Published private(set) var isModelLoaded = false
    @Published private(set) var loadingProgress: Double = 0.0
    
    private var model: MLXEmbeddingModel?
    private var tokenizer: BertTokenizer?
    private let modelURL: URL
    private let modelId: String
    
    // 缓存
    private var embeddingCache: [String: [Float]] = [:]
    private var embeddingCacheOrder: [String] = []  // LRU 访问顺序追踪
    private let cacheLimit = 1000
    
    // 模型配置
    private let hiddenSize: Int = 768  // BERT-base 默认维度
    private let maxSequenceLength: Int = 512

    // MARK: - ServiceLifecycle

    let serviceName: String = "LocalEmbeddingService"

    func initialize() async {
        // 初始化由 start() 处理
    }

    init(modelId: String = "bge-m3-mlx") {
        self.modelId = modelId
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.modelURL = documents.appendingPathComponent("YumikoToys Data/models/\(modelId)")
    }
    
    // MARK: - ServiceLifecycle
    
    func start() async {
        LoggerService.shared.info("Starting LocalEmbeddingService...")
        await loadModel()
    }
    
    func stop() {
        LoggerService.shared.info("Stopping LocalEmbeddingService...")
        model = nil
        tokenizer = nil
        embeddingCache.removeAll()
        embeddingCacheOrder.removeAll()
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
            LoggerService.shared.warning("Embedding model not found at \(weightsPath.path)，等待后续按需装载。")
            return
        }
        
        loadingProgress = 0.1
        
        do {
            let config = try loadModelConfig(from: configPath)
            loadingProgress = 0.3
            
            // 复制分词文件安全防御
            borrowVocabIfNeeded(at: vocabPath, parentDir: modelURL.deletingLastPathComponent())
            
            tokenizer = BertTokenizer(vocabFile: vocabPath)
            loadingProgress = 0.5
            
            let weights = try loadArrays(url: weightsPath)
            loadingProgress = 0.7
            
            model = MLXEmbeddingModel(config: config)
            eval(model!)
            
            loadingProgress = 1.0
            isModelLoaded = true
            
            LoggerService.shared.info("Local embedding model loaded successfully")
            
        } catch {
            LoggerService.shared.error("Failed to load embedding model: \(error)")
            isModelLoaded = false
        }
    }
    
    private func loadModelConfig(from url: URL) throws -> ModelConfig {
        var config = ModelConfig(
            vocabSize: 30522,
            hiddenSize: 768,
            numHiddenLayers: 12,
            numAttentionHeads: 12,
            intermediateSize: 3072,
            maxPositionEmbeddings: 512
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
        // 【核心修复一】如果 model 尚未实例化（通常是首次下载后点击加载），在加载权重时动态实例化模型结构
        if self.model == nil {
            let configPath = directory.appendingPathComponent("config.json")
            let config = try loadModelConfig(from: configPath)
            self.model = MLXEmbeddingModel(config: config)
            LoggerService.shared.info("Embedding model structure instantiated on the fly.")
        }
        
        // 【核心修复二】确保分词器也安全完成实例化，避免后续推理时抛出 tokenizationFailed (error 1)
        if self.tokenizer == nil {
            let vocabPath = directory.appendingPathComponent("vocab.txt")
            borrowVocabIfNeeded(at: vocabPath, parentDir: directory.deletingLastPathComponent())
            self.tokenizer = BertTokenizer(vocabFile: vocabPath)
        }
        
        guard let model = self.model else {
            throw EmbeddingError.modelNotLoaded
        }
        
        // 使用 MLXModelLoader 映射权重
        try MLXModelLoader.mapWeights(weights, to: model, mapping: MLXModelLoader.bgeM3WeightMappings(numLayers: 12))
        
        // 评估模型以应用权重
        eval(model)
        
        isModelLoaded = true
        LoggerService.shared.info("Embedding model weights loaded successfully")
    }
    
    /// 防御性多语言分词词表兜底：借用通用中文情感模型的分词表
    private func borrowVocabIfNeeded(at vocabPath: URL, parentDir: URL) {
        if !FileManager.default.fileExists(atPath: vocabPath.path) {
            let sharedVocabURL = parentDir.appendingPathComponent("distilbert-sentiment-zh/vocab.txt")
            if FileManager.default.fileExists(atPath: sharedVocabURL.path) {
                try? FileManager.default.copyItem(at: sharedVocabURL, to: vocabPath)
                LoggerService.shared.info("[LocalEmbeddingService] Successfully borrowed vocab.txt from distilbert-sentiment-zh")
            } else {
                LoggerService.shared.warning("[LocalEmbeddingService] Warning: No vocab.txt found for tokenization fallback")
            }
        }
    }
    
    // MARK: - Embedding 计算
    
    func embed(text: String) async throws -> [Float] {
        if let cached = getCachedEmbedding(for: text) {
            return cached
        }
        
        guard let model = model else {
            throw EmbeddingError.modelNotLoaded
        }
        
        guard let tokenizer = tokenizer else {
            throw EmbeddingError.tokenizationFailed
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        // 👈 【核心整合修复：打通性能仪表盘】向统一模型管理器发送开始推理追踪通报 [1]
        DependencyContainer.shared.modelManagementService.beginInference(modelId: "bge-m3-mlx")
        
        let tokens = tokenizer.encode(text, maxLength: maxSequenceLength, padToMaxLength: false)
        let inputIds = tokens.map { Int32($0) }
        let inputTensor = MLXArray(inputIds).reshaped([1, inputIds.count])
        let attentionMask = MLXArray.ones([1, inputIds.count])
        
        let embedding = model(inputTensor, attentionMask: attentionMask)
        let embeddingArray = embedding.asArray(Float.self)
        let normalized = l2Normalize(embeddingArray)
        
        cacheEmbedding(for: text, embedding: normalized)
        
        // 👈 【核心整合修复：打通性能仪表盘】通知模型管理器：推理结束，记入本次耗时和次数 [1]
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        DependencyContainer.shared.modelManagementService.endInference(modelId: "bge-m3-mlx", inferenceTime: duration)
        
        return normalized
    }
    
    /// 批量 embedding（更高效）
    func embedBatch(texts: [String]) async throws -> [[Float]] {
        guard let model = model, let tokenizer = tokenizer else {
            throw EmbeddingError.modelNotLoaded
        }
        
        var results: [[Float]?] = Array(repeating: nil, count: texts.count)
        var uncachedIndices: [Int] = []
        var uncachedTokens: [[Int]] = []
        
        for (index, text) in texts.enumerated() {
            if let cached = getCachedEmbedding(for: text) {
                results[index] = cached
            } else {
                uncachedIndices.append(index)
                uncachedTokens.append(tokenizer.encode(text, maxLength: maxSequenceLength))
            }
        }
        
        if !uncachedTokens.isEmpty {
            let startTime = CFAbsoluteTimeGetCurrent()
            // 👈 【核心整合修复：打通性能仪表盘】向统一模型管理器发送开始批量推理追踪通报 [1]
            DependencyContainer.shared.modelManagementService.beginInference(modelId: "bge-m3-mlx")
            
            let maxLen = uncachedTokens.map { $0.count }.max() ?? 0
            var batchInputIds: [[Int32]] = []
            var batchAttentionMask: [[Float]] = []
            
            for tokens in uncachedTokens {
                let paddingCount = maxLen - tokens.count
                let paddedIds = tokens.map { Int32($0) } + Array(repeating: Int32(0), count: paddingCount)
                let mask = Array(repeating: Float(1.0), count: tokens.count) + Array(repeating: Float(0.0), count: paddingCount)
                batchInputIds.append(paddedIds)
                batchAttentionMask.append(mask)
            }
            
            let flatInputIds = batchInputIds.flatMap { $0 }
            let flatMask = batchAttentionMask.flatMap { $0 }
            let inputTensor = MLXArray(flatInputIds).reshaped([uncachedTokens.count, maxLen])
            let attentionTensor = MLXArray(flatMask).reshaped([uncachedTokens.count, maxLen])
            
            let batchEmbeddings = model(inputTensor, attentionMask: attentionTensor)
            let embeddingArrays = batchEmbeddings.asArray(Float.self)
            let embeddingSize = hiddenSize
            
            for (batchIndex, originalIndex) in uncachedIndices.enumerated() {
                let start = batchIndex * embeddingSize
                let end = start + embeddingSize
                let embedding = Array(embeddingArrays[start..<end])
                let normalized = l2Normalize(embedding)
                
                results[originalIndex] = normalized
                cacheEmbedding(for: texts[originalIndex], embedding: normalized)
            }
            
            // 👈 【核心整合修复：打通性能仪表盘】通知模型管理器：批量推理结束，计算均摊时间作为标准单次指标 [1]
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            DependencyContainer.shared.modelManagementService.endInference(modelId: "bge-m3-mlx", inferenceTime: duration / Double(uncachedTokens.count))
        }
        
        return results.compactMap { $0 }
    }
    
    // MARK: - 相似度计算
    
    func similarity(between text1: String, and text2: String) async throws -> Float {
        async let emb1 = embed(text: text1)
        async let emb2 = embed(text: text2)
        let (e1, e2) = try await (emb1, emb2)
        return cosineSimilarity(e1, e2)
    }
    
    func batchSimilarity(query: String, candidates: [String]) async throws -> [(index: Int, similarity: Float)] {
        let queryEmbedding = try await embed(text: query)
        let candidateEmbeddings = try await embedBatch(texts: candidates)
        
        var results: [(index: Int, similarity: Float)] = []
        
        for (index, candidateEmbedding) in candidateEmbeddings.enumerated() {
            let sim = cosineSimilarity(queryEmbedding, candidateEmbedding)
            results.append((index: index, similarity: sim))
        }
        
        return results.sorted { $0.similarity > $1.similarity }
    }
    
    func findMostSimilar(to query: String, in candidates: [String], threshold: Float = 0.85) async throws -> (index: Int?, similarity: Float) {
        let results = try await batchSimilarity(query: query, candidates: candidates)
        
        guard let best = results.first else {
            return (nil, 0.0)
        }
        
        if best.similarity >= threshold {
            return (best.index, best.similarity)
        } else {
            return (nil, best.similarity)
        }
    }
    
    // MARK: - 【核心新增：学术级物理心理学语义测算引擎】
    
    /// 计算用户陈述与多个特定临床心理学大类维度（如认知偏误、防御机制等）的语义共鸣关联度 [1]
    func calculatePsychologicalResonance(text: String, categories: [String]) async throws -> [(category: String, similarity: Float)] {
        // 利用本地 BGE-M3 的超强跨语言对齐表示，测量输入句同多个学术心理学锚点的余弦空间距离 [1]
        let results = try await batchSimilarity(query: text, candidates: categories)
        return results.map { (category: categories[$0.index], similarity: $0.similarity) }
    }
    
    /// 基于贝克认知行为疗法（CBT）模型，诊断并锁定用户陈述中最高频、最匹配的“自动化负面认知失调/偏误”特征 [1]
    func diagnoseCognitiveDistortion(text: String, threshold: Float = 0.62) async throws -> (distortion: String?, similarity: Float) {
        // 临床上五大最经典的自动化认知功能失调锚点定义 [1]
        let clinicalDistortions = [
            "灾难化思维 (Catastrophizing) —— 习惯把微小的负面反馈无限放大，对未来建立失控的末日宿命感",
            "非黑即白信念 (All-or-Nothing) —— 完美主义作祟下的极端化两极评判，认为不完美即代表彻底失败",
            "自我归因过载 (Personalization) —— 盲目进行过度内部归因，将外界与己无关的所有坏事自责包揽到自己身上",
            "情绪化推理 (Emotional Reasoning) —— 沉沉沉溺在当下的瞬时心境中，并坚信情绪感觉即代表客观事实本身",
            "习得性无助 (Learned Helplessness) —— 失去自主与胜任感心理动机，深陷于改变命运无望的顺从深渊"
        ]
        
        let resonance = try await calculatePsychologicalResonance(text: text, categories: clinicalDistortions)
        
        guard let bestMatch = resonance.first else {
            return (nil, 0.0)
        }
        
        // 若匹配度越过置信门槛，则返回锁定的认知偏误描述，指导 AI 伴侣进行针对性重构
        if bestMatch.similarity >= threshold {
            return (bestMatch.category, bestMatch.similarity)
        } else {
            return (nil, bestMatch.similarity)
        }
    }
    
    // MARK: - 辅助方法
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }
        
        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        
        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0.0 }
        
        return dotProduct / denominator
    }
    
    private func l2Normalize(_ vector: [Float]) -> [Float] {
        let squaredSum = vector.map { $0 * $0 }.reduce(0, +)
        let norm = sqrt(squaredSum)
        guard norm > 1e-8 else { return vector }
        return vector.map { $0 / norm }
    }
    
    private func getCachedEmbedding(for text: String) -> [Float]? {
        if let cached = embeddingCache[text] {
            embeddingCacheOrder.removeAll { $0 == text }
            embeddingCacheOrder.append(text)
            return cached
        }
        return nil
    }
    
    private func cacheEmbedding(for text: String, embedding: [Float]) {
        if embeddingCache[text] != nil {
            embeddingCacheOrder.removeAll { $0 == text }
        }
        
        while embeddingCache.count >= cacheLimit, let oldestKey = embeddingCacheOrder.first {
            embeddingCache.removeValue(forKey: oldestKey)
            embeddingCacheOrder.removeFirst()
        }
        
        embeddingCache[text] = embedding
        embeddingCacheOrder.append(text)
    }
}

// MARK: - 错误类型

enum EmbeddingError: Error, LocalizedError {
    case modelNotLoaded
    case tokenizationFailed
    case inferenceFailed
    case modelNotFound
    case invalidInput
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
        case .modelNotFound:
            return "模型文件未找到"
        case .invalidInput:
            return "输入无效"
        case .weightsLoadFailed(let message):
            return "权重加载失败: \(message)"
        case .modelConfigNotFound:
            return "模型配置文件未找到"
        }
    }
}

// MARK: - 模型配置

struct ModelConfig {
    var vocabSize: Int
    var hiddenSize: Int
    var numHiddenLayers: Int
    var numAttentionHeads: Int
    var intermediateSize: Int
    var maxPositionEmbeddings: Int
}

// MARK: - MLX Embedding 模型

class MLXEmbeddingModel: Module {
    let config: ModelConfig
    
    private var embeddings: TokenEmbeddings
    private var encoder: TransformerEncoder
    private var pooler: Linear?
    
    init(config: ModelConfig) {
        self.config = config
        self.embeddings = TokenEmbeddings(
            vocabSize: config.vocabSize,
            hiddenSize: config.hiddenSize,
            maxPositionEmbeddings: config.maxPositionEmbeddings
        )
        self.encoder = TransformerEncoder(
            hiddenSize: config.hiddenSize,
            numLayers: config.numHiddenLayers,
            numHeads: config.numAttentionHeads,
            intermediateSize: config.intermediateSize
        )
        self.pooler = Linear(config.hiddenSize, config.hiddenSize)
        super.init()
    }
    
    func callAsFunction(_ inputIds: MLXArray, attentionMask: MLXArray? = nil) -> MLXArray {
        var hiddenStates = embeddings(inputIds)
        hiddenStates = encoder(hiddenStates, attentionMask: attentionMask)
        
        let mask = attentionMask ?? MLXArray.ones(hiddenStates.shape)
        let maskShape = mask.shape
        let expandedMask = mask.reshaped([maskShape[0], maskShape[1], 1])
        let sumHidden = (hiddenStates * expandedMask).sum(axis: 1)
        let sumMask = mask.sum(axis: 1).reshaped([maskShape[0], 1])
        var pooledOutput = sumHidden / sumMask
        
        if let pooler = pooler {
            pooledOutput = tanh(pooler(pooledOutput))
        }
        
        return pooledOutput
    }
}

// MARK: - Token Embeddings

class TokenEmbeddings: Module {
    let wordEmbeddings: Embedding
    let positionEmbeddings: Embedding
    let layerNorm: LayerNorm
    let dropout: Dropout
    
    init(vocabSize: Int, hiddenSize: Int, maxPositionEmbeddings: Int, dropoutRate: Float = 0.1) {
        self.wordEmbeddings = Embedding(embeddingCount: vocabSize, dimensions: hiddenSize)
        self.positionEmbeddings = Embedding(embeddingCount: maxPositionEmbeddings, dimensions: hiddenSize)
        self.layerNorm = LayerNorm(dimensions: hiddenSize)
        self.dropout = Dropout(p: dropoutRate)
        super.init()
    }
    
    func callAsFunction(_ inputIds: MLXArray) -> MLXArray {
        let seqLength = inputIds.shape[1]
        var embeddings = wordEmbeddings(inputIds)
        let positionIds = MLXArray(0..<seqLength).reshaped([1, seqLength])
        let positionEmbeds = positionEmbeddings(positionIds)
        
        embeddings = embeddings + positionEmbeds
        embeddings = layerNorm(embeddings)
        embeddings = dropout(embeddings)
        
        return embeddings
    }
}

// MARK: - Transformer Encoder

class TransformerEncoder: Module {
    let layers: [TransformerLayer]
    
    init(hiddenSize: Int, numLayers: Int, numHeads: Int, intermediateSize: Int) {
        self.layers = (0..<numLayers).map { _ in
            TransformerLayer(
                hiddenSize: hiddenSize,
                numHeads: numHeads,
                intermediateSize: intermediateSize
            )
        }
        super.init()
    }
    
    func callAsFunction(_ hiddenStates: MLXArray, attentionMask: MLXArray? = nil) -> MLXArray {
        var output = hiddenStates
        for layer in layers {
            output = layer(output, attentionMask: attentionMask)
        }
        return output
    }
}

// MARK: - Transformer Layer

class TransformerLayer: Module {
    let attention: MultiHeadAttention
    let feedForward: FeedForward
    let attentionLayerNorm: LayerNorm
    let ffnLayerNorm: LayerNorm
    
    init(hiddenSize: Int, numHeads: Int, intermediateSize: Int) {
        self.attention = MultiHeadAttention(hiddenSize: hiddenSize, numHeads: numHeads)
        self.feedForward = FeedForward(hiddenSize: hiddenSize, intermediateSize: intermediateSize)
        self.attentionLayerNorm = LayerNorm(dimensions: hiddenSize)
        self.ffnLayerNorm = LayerNorm(dimensions: hiddenSize)
        super.init()
    }
    
    func callAsFunction(_ hiddenStates: MLXArray, attentionMask: MLXArray? = nil) -> MLXArray {
        let attentionOutput = attention(hiddenStates, attentionMask: attentionMask)
        var output = attentionLayerNorm(hiddenStates + attentionOutput)
        let ffnOutput = feedForward(output)
        output = ffnLayerNorm(output + ffnOutput)
        return output
    }
}

// MARK: - Multi-Head Attention

class MultiHeadAttention: Module {
    let numHeads: Int
    let headDim: Int
    let hiddenSize: Int
    
    let queryProjection: Linear
    let keyProjection: Linear
    let valueProjection: Linear
    let outputProjection: Linear
    
    init(hiddenSize: Int, numHeads: Int) {
        self.hiddenSize = hiddenSize
        self.numHeads = numHeads
        self.headDim = hiddenSize / numHeads
        
        self.queryProjection = Linear(hiddenSize, hiddenSize)
        self.keyProjection = Linear(hiddenSize, hiddenSize)
        self.valueProjection = Linear(hiddenSize, hiddenSize)
        self.outputProjection = Linear(hiddenSize, hiddenSize)
        
        super.init()
    }
    
    func callAsFunction(_ hiddenStates: MLXArray, attentionMask: MLXArray? = nil) -> MLXArray {
        let batchSize = hiddenStates.shape[0]
        let seqLength = hiddenStates.shape[1]
        
        let query = queryProjection(hiddenStates)
        let key = keyProjection(hiddenStates)
        let value = valueProjection(hiddenStates)
        
        let queryReshaped = query.reshaped([batchSize, seqLength, numHeads, headDim]).transposed(axes: [0, 2, 1, 3])
        let keyReshaped = key.reshaped([batchSize, seqLength, numHeads, headDim]).transposed(axes: [0, 2, 1, 3])
        let valueReshaped = value.reshaped([batchSize, seqLength, numHeads, headDim]).transposed(axes: [0, 2, 1, 3])
        
        var attentionScores = matmul(queryReshaped, keyReshaped.transposed(axes: [0, 1, 3, 2]))
        attentionScores = attentionScores / sqrt(Float(headDim))
        
        if let mask = attentionMask {
            let maskShape = mask.shape
            let expandedMask = mask.reshaped([maskShape[0], 1, 1, maskShape[1]])
            attentionScores = attentionScores + (1 - expandedMask) * Float(-1e9)
        }
        
        let attentionProbs = softMax(attentionScores, axis: -1)
        var context = matmul(attentionProbs, valueReshaped)
        
        context = context.transposed(axes: [0, 2, 1, 3]).reshaped([batchSize, seqLength, hiddenSize])
        return outputProjection(context)
    }
}

// MARK: - Feed Forward Network

class FeedForward: Module {
    let dense1: Linear
    let dense2: Linear
    let activation: (MLXArray) -> MLXArray
    
    init(hiddenSize: Int, intermediateSize: Int) {
        self.dense1 = Linear(hiddenSize, intermediateSize)
        self.dense2 = Linear(intermediateSize, hiddenSize)
        self.activation = gelu
        super.init()
    }
    
    func callAsFunction(_ x: MLXArray) -> MLXArray {
        return dense2(activation(dense1(x)))
    }
}

// MARK: - GELU Activation

func gelu(_ x: MLXArray) -> MLXArray {
    let sqrt2OverPi = sqrt(2.0 / .pi)
    let cdf = 0.5 * (1.0 + tanh(sqrt2OverPi * (x + 0.044715 * x * x * x)))
    return x * cdf
}

// MARK: - BERT Tokenizer

class BertTokenizer {
    private var vocab: [String: Int] = [:]
    private var idToToken: [Int: String] = [:]
    
    private let clsTokenId: Int
    private let sepTokenId: Int
    private let padTokenId: Int
    private let unkTokenId: Int
    
    init?(vocabFile: URL) {
        guard let content = try? String(contentsOf: vocabFile, encoding: .utf8) else {
            self.clsTokenId = 101
            self.sepTokenId = 102
            self.padTokenId = 0
            self.unkTokenId = 100
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let token = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                vocab[token] = index
                idToToken[index] = token
            }
        }
        
        self.clsTokenId = vocab["[CLS]"] ?? 101
        self.sepTokenId = vocab["[SEP]"] ?? 102
        self.padTokenId = vocab["[PAD]"] ?? 0
        self.unkTokenId = vocab["[UNK]"] ?? 100
    }
    
    func encode(_ text: String, maxLength: Int = 512, padToMaxLength: Bool = true) -> [Int] {
        let cleanedText = text.lowercased()
            .replacingOccurrences(of: "[^\\w\\s]", with: " ", options: .regularExpression)
        
        let words = cleanedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var tokens: [Int] = [clsTokenId]
        
        for word in words {
            if let tokenId = vocab[word] {
                tokens.append(tokenId)
            } else {
                let subwordTokens = subwordTokenize(word)
                tokens.append(contentsOf: subwordTokens)
            }
            
            if tokens.count >= maxLength - 1 {
                break
            }
        }
        
        tokens.append(sepTokenId)
        
        if tokens.count > maxLength {
            tokens = Array(tokens.prefix(maxLength))
            tokens[maxLength - 1] = sepTokenId
        }
        
        if padToMaxLength && tokens.count < maxLength {
            tokens.append(contentsOf: Array(repeating: padTokenId, count: maxLength - tokens.count))
        }
        
        return tokens
    }
    
    private func subwordTokenize(_ word: String) -> [Int] {
        var tokens: [Int] = []
        var remaining = word
        
        while !remaining.isEmpty {
            var longestMatch: (token: String, id: Int)? = nil
            
            for length in (1...remaining.count).reversed() {
                let prefix = String(remaining.prefix(length))
                let subwordPrefix = "##" + prefix
                
                if let id = vocab[prefix], longestMatch == nil {
                    longestMatch = (prefix, id)
                }
                if let id = vocab[subwordPrefix] {
                    longestMatch = (subwordPrefix, id)
                    break
                }
            }
            
            if let match = longestMatch {
                tokens.append(match.id)
                remaining = String(remaining.dropFirst(match.token.hasPrefix("##") ? match.token.count - 2 : match.token.count))
            } else {
                tokens.append(unkTokenId)
                break
            }
        }
        
        return tokens.isEmpty ? [unkTokenId] : tokens
    }
    
    func decode(_ tokenIds: [Int]) -> String {
        var tokens: [String] = []
        
        for id in tokenIds {
            guard id != padTokenId && id != clsTokenId && id != sepTokenId else { continue }
            
            if let token = idToToken[id] {
                let cleanedToken = token.hasPrefix("##") ? String(token.dropFirst(2)) : token
                tokens.append(cleanedToken)
            }
        }
        
        return tokens.joined(separator: " ")
    }
}
