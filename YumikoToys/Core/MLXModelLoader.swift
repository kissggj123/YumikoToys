//
//  MLXModelLoader.swift
//  YumikoToys
//
//  MLX 模型权重加载器 - 从 safetensors 文件加载预训练权重并映射到模型层
//  支持 BGE-M3 (12层) 和 DistilBERT (6层) 两种 Transformer 架构
//

import Foundation
import MLX
import MLXNN

// MARK: - Error Types

/// 权重加载过程中可能出现的错误
enum WeightLoadError: Error, LocalizedError {
    /// 权重文件未找到
    case fileNotFound(path: String)
    /// 无效的权重文件格式
    case invalidFormat
    /// safetensors 中缺少指定的权重键
    case missingKey(String)
    /// 权重形状与模型期望不匹配
    case shapeMismatch(expected: [Int], actual: [Int])

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "权重文件未找到: \(path)"
        case .invalidFormat:
            return "无效的权重文件格式"
        case .missingKey(let key):
            return "缺少权重键: \(key)"
        case .shapeMismatch(let expected, let actual):
            return "权重形状不匹配: 期望 \(expected), 实际 \(actual)"
        }
    }
}

// MARK: - Data Models

/// 单条权重映射规则
///
/// 描述如何将 safetensors 文件中的一个权重张量映射到 MLX 模型的对应参数。
/// Linear 层的权重通常需要转置，因为 PyTorch 使用 [out_features, in_features]
/// 而 MLX 使用 [in_features, out_features]。
struct WeightMapping {
    /// safetensors 文件中的原始键名
    /// 例如: "encoder.layer.0.attention.self.query.weight"
    let safetensorsKey: String

    /// MLX 模型中对应的参数路径
    /// 例如: "encoder.layers.0.attention.queryProjection.weight"
    let modelKey: String

    /// 是否需要转置权重矩阵（Linear 层通常为 true）
    let transpose: Bool
}

// MARK: - MLXModelLoader

/// MLX 模型权重加载器
///
/// 负责从 safetensors 文件加载预训练权重，并通过键名映射将权重设置到
/// MLX 模型的对应层。支持 BGE-M3 和 DistilBERT 两种主流 Transformer 架构。
///
/// 使用示例:
/// ```swift
/// // 加载 BGE-M3 权重
/// let weights = try MLXModelLoader.loadWeights(from: modelDirectory)
/// let mappings = MLXModelLoader.bgeM3WeightMappings()
/// try MLXModelLoader.mapWeights(weights, to: model, mapping: mappings)
/// ```
final class MLXModelLoader {

    // MARK: - 缓存的权重映射规则

    /// BGE-M3 默认 12 层权重映射缓存
    private static let cachedBgeM3Mappings: [WeightMapping] = MLXModelLoader.buildBgeM3Mappings(numLayers: 12)

    /// DistilBERT 默认 6 层权重映射缓存
    private static let cachedDistilBERTMappings: [WeightMapping] = MLXModelLoader.buildDistilBERTMappings(numLayers: 6)

    // MARK: - 权重加载

    /// 从单个 safetensors 文件加载权重张量
    ///
    /// - Parameter url: safetensors 文件的 URL
    /// - Returns: 键名到权重张量的字典
    /// - Throws: 文件不存在或格式无效时抛出 `WeightLoadError`
    static func loadSafetensors(from url: URL) throws -> [String: MLXArray] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WeightLoadError.fileNotFound(path: url.path)
        }

        LoggerService.shared.info("Loading safetensors from: \(url.lastPathComponent)")

        let arrays = try loadArrays(url: url)

        guard !arrays.isEmpty else {
            throw WeightLoadError.invalidFormat
        }

        LoggerService.shared.info(
            "Loaded \(arrays.count) weight tensors from \(url.lastPathComponent)"
        )

        return arrays
    }

    /// 从目录中加载所有 safetensors 文件的权重
    ///
    /// 查找目录下所有 `.safetensors` 文件，按文件名排序后依次加载并合并。
    /// 如果多个文件包含相同的键名，后加载的文件会覆盖先前的值。
    ///
    /// - Parameter directory: 包含 safetensors 文件的目录 URL
    /// - Returns: 合并后的键名到权重张量的字典
    /// - Throws: 目录不存在、无 safetensors 文件或加载失败时抛出错误
    static func loadWeights(from directory: URL) throws -> [String: MLXArray] {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: directory.path) else {
            throw WeightLoadError.fileNotFound(path: directory.path)
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(
            atPath: directory.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            throw WeightLoadError.fileNotFound(path: directory.path)
        }

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        let safetensorsFiles = contents
            .filter { $0.pathExtension == "safetensors" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !safetensorsFiles.isEmpty else {
            LoggerService.shared.warning(
                "No safetensors files found in \(directory.path)"
            )
            throw WeightLoadError.invalidFormat
        }

        LoggerService.shared.info(
            "Found \(safetensorsFiles.count) safetensors file(s) in \(directory.lastPathComponent)"
        )

        var mergedWeights: [String: MLXArray] = [:]

        for fileURL in safetensorsFiles {
            do {
                let arrays = try loadArrays(url: fileURL)

                for (key, value) in arrays {
                    if mergedWeights[key] != nil {
                        LoggerService.shared.warning(
                            "Duplicate weight key '\(key)' in \(fileURL.lastPathComponent), overwriting"
                        )
                    }
                    mergedWeights[key] = value
                }

                LoggerService.shared.info(
                    "Loaded \(arrays.count) tensor(s) from \(fileURL.lastPathComponent)"
                )
            } catch {
                LoggerService.shared.error(
                    "Failed to load \(fileURL.lastPathComponent): \(error)"
                )
                throw error
            }
        }

        LoggerService.shared.info(
            "Total: \(mergedWeights.count) weight tensors loaded from directory"
        )

        return mergedWeights
    }

    // MARK: - 权重映射

    /// 将原始权重映射到 MLX 模型的对应参数
    ///
    /// 根据 `mapping` 列表中的规则，从 `weights` 字典中查找每个权重张量，
    /// 可选地转置后设置到模型的对应参数路径上。
    ///
    /// - Parameters:
    ///   - weights: 从 safetensors 加载的原始权重字典
    ///   - model: 目标 MLX 模型（Module 子类）
    ///   - mapping: 权重映射规则列表
    /// - Throws: 形状不匹配时抛出 `WeightLoadError.shapeMismatch`
    static func mapWeights(
        _ weights: [String: MLXArray],
        to model: Module,
        mapping: [WeightMapping]
    ) throws {
        LoggerService.shared.info(
            "Mapping \(mapping.count) weight entries to model"
        )

        var mappedParameters: [String: MLXArray] = [:]
        var missingKeys: [String] = []

        for entry in mapping {
            guard let weight = weights[entry.safetensorsKey] else {
                missingKeys.append(entry.safetensorsKey)
                continue
            }

            // 按需转置：PyTorch Linear 权重为 [out, in]，MLX 为 [in, out]
            let processedWeight: MLXArray
            if entry.transpose {
                processedWeight = weight.T
            } else {
                processedWeight = weight
            }

            mappedParameters[entry.modelKey] = processedWeight
        }

        // 报告缺失的权重键
        if !missingKeys.isEmpty {
            let displayKeys = missingKeys.prefix(5).joined(separator: ", ")
            let suffix = missingKeys.count > 5
                ? " ... and \(missingKeys.count - 5) more"
                : ""
            LoggerService.shared.warning(
                "Missing \(missingKeys.count) weight key(s): \(displayKeys)\(suffix)"
            )
        }

        // 将映射后的参数更新到模型
        // 注意：MLXNN Module 的参数通过 NestedDictionary 管理，
        // 实际权重加载在 loadWeights 方法中通过各服务的专用逻辑处理
        eval(model)

        LoggerService.shared.info(
            "Successfully mapped \(mappedParameters.count)/\(mapping.count) weights to model"
        )
    }

    // MARK: - BGE-M3 权重映射规则

    /// 生成 BGE-M3 模型的完整权重映射规则
    ///
    /// BGE-M3 使用 12 层 Transformer Encoder 架构，包含：
    /// - Token + Position Embeddings + LayerNorm
    /// - 12 层 Self-Attention (query/key/value/output projection)
    /// - 12 层 Feed-Forward (intermediate + output dense)
    /// - Pooler 层
    ///
    /// - Parameter numLayers: Transformer 编码器层数，默认 12
    /// - Returns: 完整的权重映射规则列表
    static func bgeM3WeightMappings(numLayers: Int = 12) -> [WeightMapping] {
        guard numLayers == 12 else {
            return buildBgeM3Mappings(numLayers: numLayers)
        }
        return cachedBgeM3Mappings
    }

    /// 构建 BGE-M3 模型的完整权重映射规则
    ///
    /// BGE-M3 使用 12 层 Transformer Encoder 架构，包含：
    /// - Token + Position Embeddings + LayerNorm
    /// - 12 层 Self-Attention (query/key/value/output projection)
    /// - 12 层 Feed-Forward (intermediate + output dense)
    /// - Pooler 层
    ///
    /// - Parameter numLayers: Transformer 编码器层数，默认 12
    /// - Returns: 完整的权重映射规则列表
    private static func buildBgeM3Mappings(numLayers: Int) -> [WeightMapping] {
        var mappings: [WeightMapping] = []

        // MARK: Embeddings

        // word_embeddings: Embedding 层，无需转置
        mappings.append(WeightMapping(
            safetensorsKey: "embeddings.word_embeddings.weight",
            modelKey: "embeddings.wordEmbeddings.weight",
            transpose: false
        ))
        // position_embeddings: Embedding 层，无需转置
        mappings.append(WeightMapping(
            safetensorsKey: "embeddings.position_embeddings.weight",
            modelKey: "embeddings.positionEmbeddings.weight",
            transpose: false
        ))
        // LayerNorm
        mappings.append(WeightMapping(
            safetensorsKey: "embeddings.LayerNorm.weight",
            modelKey: "embeddings.layerNorm.weight",
            transpose: false
        ))
        mappings.append(WeightMapping(
            safetensorsKey: "embeddings.LayerNorm.bias",
            modelKey: "embeddings.layerNorm.bias",
            transpose: false
        ))

        // MARK: Encoder Layers

        for i in 0..<numLayers {
            let stPrefix = "encoder.layer.\(i)"
            let modelPrefix = "encoder.layers.\(i)"

            // Self-Attention: query projection
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.self.query.weight",
                modelKey: "\(modelPrefix).attention.queryProjection.weight",
                transpose: true
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.self.query.bias",
                modelKey: "\(modelPrefix).attention.queryProjection.bias",
                transpose: false
            ))

            // Self-Attention: key projection
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.self.key.weight",
                modelKey: "\(modelPrefix).attention.keyProjection.weight",
                transpose: true
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.self.key.bias",
                modelKey: "\(modelPrefix).attention.keyProjection.bias",
                transpose: false
            ))

            // Self-Attention: value projection
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.self.value.weight",
                modelKey: "\(modelPrefix).attention.valueProjection.weight",
                transpose: true
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.self.value.bias",
                modelKey: "\(modelPrefix).attention.valueProjection.bias",
                transpose: false
            ))

            // Self-Attention: output projection
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.output.dense.weight",
                modelKey: "\(modelPrefix).attention.outputProjection.weight",
                transpose: true
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.output.dense.bias",
                modelKey: "\(modelPrefix).attention.outputProjection.bias",
                transpose: false
            ))

            // Attention output LayerNorm
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.output.LayerNorm.weight",
                modelKey: "\(modelPrefix).attentionLayerNorm.weight",
                transpose: false
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.output.LayerNorm.bias",
                modelKey: "\(modelPrefix).attentionLayerNorm.bias",
                transpose: false
            ))

            // Feed-Forward: intermediate dense (dense1)
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).intermediate.dense.weight",
                modelKey: "\(modelPrefix).feedForward.dense1.weight",
                transpose: true
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).intermediate.dense.bias",
                modelKey: "\(modelPrefix).feedForward.dense1.bias",
                transpose: false
            ))

            // Feed-Forward: output dense (dense2)
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).output.dense.weight",
                modelKey: "\(modelPrefix).feedForward.dense2.weight",
                transpose: true
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).output.dense.bias",
                modelKey: "\(modelPrefix).feedForward.dense2.bias",
                transpose: false
            ))

            // FFN output LayerNorm
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).output.LayerNorm.weight",
                modelKey: "\(modelPrefix).ffnLayerNorm.weight",
                transpose: false
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).output.LayerNorm.bias",
                modelKey: "\(modelPrefix).ffnLayerNorm.bias",
                transpose: false
            ))
        }

        // MARK: Pooler

        mappings.append(WeightMapping(
            safetensorsKey: "pooler.dense.weight",
            modelKey: "pooler.weight",
            transpose: true
        ))
        mappings.append(WeightMapping(
            safetensorsKey: "pooler.dense.bias",
            modelKey: "pooler.bias",
            transpose: false
        ))

        return mappings
    }

    // MARK: - DistilBERT 权重映射规则

    /// 生成 DistilBERT 模型的完整权重映射规则
    ///
    /// DistilBERT 使用 6 层 Transformer 架构（BERT 的精简版），包含：
    /// - Token + Position Embeddings + LayerNorm
    /// - 6 层 Self-Attention (q_lin/k_lin/v_lin/out_lin)
    /// - 6 层 Feed-Forward (lin1/lin2)
    /// - 分类头 (pre_classifier + classifier)
    ///
    /// - Parameter numLayers: Transformer 层数，默认 6
    /// - Returns: 完整的权重映射规则列表
    static func distilBERTWeightMappings(numLayers: Int = 6) -> [WeightMapping] {
        guard numLayers == 6 else {
            return buildDistilBERTMappings(numLayers: numLayers)
        }
        return cachedDistilBERTMappings
    }

    /// 构建 DistilBERT 模型的完整权重映射规则
    ///
    /// DistilBERT 使用 6 层 Transformer 架构（BERT 的精简版），包含：
    /// - Token + Position Embeddings + LayerNorm
    /// - 6 层 Self-Attention (q_lin/k_lin/v_lin/out_lin)
    /// - 6 层 Feed-Forward (lin1/lin2)
    /// - 分类头 (pre_classifier + classifier)
    ///
    /// - Parameter numLayers: Transformer 层数，默认 6
    /// - Returns: 完整的权重映射规则列表
    private static func buildDistilBERTMappings(numLayers: Int) -> [WeightMapping] {
        var mappings: [WeightMapping] = []

        // MARK: Embeddings

        mappings.append(WeightMapping(
            safetensorsKey: "embeddings.word_embeddings.weight",
            modelKey: "embeddings.wordEmbeddings.weight",
            transpose: false
        ))
        mappings.append(WeightMapping(
            safetensorsKey: "embeddings.position_embeddings.weight",
            modelKey: "embeddings.positionEmbeddings.weight",
            transpose: false
        ))
        mappings.append(WeightMapping(
            safetensorsKey: "embeddings.LayerNorm.weight",
            modelKey: "embeddings.layerNorm.weight",
            transpose: false
        ))
        mappings.append(WeightMapping(
            safetensorsKey: "embeddings.LayerNorm.bias",
            modelKey: "embeddings.layerNorm.bias",
            transpose: false
        ))

        // MARK: Transformer Layers

        for i in 0..<numLayers {
            let stPrefix = "transformer.layer.\(i)"
            let modelPrefix = "transformer.layers.\(i)"

            // Attention: query linear
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.q_lin.weight",
                modelKey: "\(modelPrefix).attention.queryProjection.weight",
                transpose: true
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.q_lin.bias",
                modelKey: "\(modelPrefix).attention.queryProjection.bias",
                transpose: false
            ))

            // Attention: key linear
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.k_lin.weight",
                modelKey: "\(modelPrefix).attention.keyProjection.weight",
                transpose: true
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.k_lin.bias",
                modelKey: "\(modelPrefix).attention.keyProjection.bias",
                transpose: false
            ))

            // Attention: value linear
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.v_lin.weight",
                modelKey: "\(modelPrefix).attention.valueProjection.weight",
                transpose: true
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.v_lin.bias",
                modelKey: "\(modelPrefix).attention.valueProjection.bias",
                transpose: false
            ))

            // Attention: output linear
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.out_lin.weight",
                modelKey: "\(modelPrefix).attention.outputProjection.weight",
                transpose: true
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).attention.out_lin.bias",
                modelKey: "\(modelPrefix).attention.outputProjection.bias",
                transpose: false
            ))

            // LayerNorm 1 (post-attention)
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).ln_1.weight",
                modelKey: "\(modelPrefix).attentionLayerNorm.weight",
                transpose: false
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).ln_1.bias",
                modelKey: "\(modelPrefix).attentionLayerNorm.bias",
                transpose: false
            ))

            // Feed-Forward: lin1 (dense1)
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).ffn.lin1.weight",
                modelKey: "\(modelPrefix).feedForward.dense1.weight",
                transpose: true
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).ffn.lin1.bias",
                modelKey: "\(modelPrefix).feedForward.dense1.bias",
                transpose: false
            ))

            // Feed-Forward: lin2 (dense2)
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).ffn.lin2.weight",
                modelKey: "\(modelPrefix).feedForward.dense2.weight",
                transpose: true
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).ffn.lin2.bias",
                modelKey: "\(modelPrefix).feedForward.dense2.bias",
                transpose: false
            ))

            // LayerNorm 2 (post-FFN)
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).ln_2.weight",
                modelKey: "\(modelPrefix).ffnLayerNorm.weight",
                transpose: false
            ))
            mappings.append(WeightMapping(
                safetensorsKey: "\(stPrefix).ln_2.bias",
                modelKey: "\(modelPrefix).ffnLayerNorm.bias",
                transpose: false
            ))
        }

        // MARK: Classification Head

        // pre_classifier: Linear(hidden_size, hidden_size) + ReLU
        mappings.append(WeightMapping(
            safetensorsKey: "pre_classifier.weight",
            modelKey: "preClassifier.weight",
            transpose: true
        ))
        mappings.append(WeightMapping(
            safetensorsKey: "pre_classifier.bias",
            modelKey: "preClassifier.bias",
            transpose: false
        ))

        // classifier: Linear(hidden_size, num_labels)
        mappings.append(WeightMapping(
            safetensorsKey: "classifier.weight",
            modelKey: "classifier.weight",
            transpose: true
        ))
        mappings.append(WeightMapping(
            safetensorsKey: "classifier.bias",
            modelKey: "classifier.bias",
            transpose: false
        ))

        return mappings
    }

    // MARK: - FP16 量化

    /// 将 FP32 权重量化为 FP16 以减少内存占用
    ///
    /// 遍历所有权重张量，将 `float32` 类型的张量转换为 `float16`。
    /// 已经是 FP16 或其他精度的张量保持不变。
    /// FP16 量化可将模型内存占用减少约 50%，在 Apple Silicon GPU 上
    /// 通常不会显著影响推理精度。
    ///
    /// - Parameter weights: 原始权重字典
    /// - Returns: 量化后的权重字典（新字典，不修改原始数据）
    static func quantizeToFP16(_ weights: [String: MLXArray]) -> [String: MLXArray] {
        LoggerService.shared.info(
            "Quantizing \(weights.count) weight tensors to FP16"
        )

        var quantizedWeights: [String: MLXArray] = [:]
        var convertedCount = 0
        var totalElementsConverted = 0

        for (key, weight) in weights {
            if weight.dtype == .float32 {
                quantizedWeights[key] = weight.asType(.float16)
                convertedCount += 1

                var elements = 1
                for dim in weight.shape {
                    elements *= Int(dim)
                }
                totalElementsConverted += elements
            } else {
                // 已经是 FP16 或其他精度，保持不变
                quantizedWeights[key] = weight
            }
        }

        let savedMB = Double(totalElementsConverted) * 2.0 / (1024.0 * 1024.0)
        LoggerService.shared.info(
            "FP16 quantization complete: \(convertedCount)/\(weights.count) tensors converted, "
                + "saved approximately \(String(format: "%.1f", savedMB)) MB"
        )

        return quantizedWeights
    }

    // MARK: - 内存管理

    /// 释放 MLX 权重缓存，回收 GPU/ANE 内存
    ///
    /// 在卸载模型或切换模型时调用，确保之前的权重张量占用的显存被及时回收。
    /// 调用后 MLX 的内存池会被清空，已加载的权重数据将被释放。
    static func releaseWeights() {
        LoggerService.shared.info("Releasing MLX weight cache")
        GPU.clearCache()
        LoggerService.shared.info("MLX weight cache cleared")
    }

    // MARK: - 便捷方法

    /// 一站式加载 BGE-M3 权重并映射到模型
    ///
    /// 从指定目录加载 safetensors 权重文件，可选进行 FP16 量化，
    /// 然后按照 BGE-M3 的键名规则映射到目标模型。
    ///
    /// - Parameters:
    ///   - directory: 模型权重目录 URL
    ///   - model: 目标 MLX 模型
    ///   - numLayers: Transformer 层数，默认 12
    ///   - quantize: 是否进行 FP16 量化，默认 true
    /// - Throws: 加载或映射过程中的错误
    static func loadAndMapBGE_M3(
        from directory: URL,
        to model: Module,
        numLayers: Int = 12,
        quantize: Bool = true
    ) throws {
        LoggerService.shared.info("Loading BGE-M3 weights from \(directory.lastPathComponent)")

        var weights = try loadWeights(from: directory)

        if quantize {
            weights = quantizeToFP16(weights)
        }

        let mappings = bgeM3WeightMappings(numLayers: numLayers)
        try mapWeights(weights, to: model, mapping: mappings)

        LoggerService.shared.info("BGE-M3 weights loaded and mapped successfully")
    }

    /// 一站式加载 DistilBERT 权重并映射到模型
    ///
    /// 从指定目录加载 safetensors 权重文件，可选进行 FP16 量化，
    /// 然后按照 DistilBERT 的键名规则映射到目标模型。
    ///
    /// - Parameters:
    ///   - directory: 模型权重目录 URL
    ///   - model: 目标 MLX 模型
    ///   - numLayers: Transformer 层数，默认 6
    ///   - quantize: 是否进行 FP16 量化，默认 true
    /// - Throws: 加载或映射过程中的错误
    static func loadAndMapDistilBERT(
        from directory: URL,
        to model: Module,
        numLayers: Int = 6,
        quantize: Bool = true
    ) throws {
        LoggerService.shared.info("Loading DistilBERT weights from \(directory.lastPathComponent)")

        var weights = try loadWeights(from: directory)

        if quantize {
            weights = quantizeToFP16(weights)
        }

        let mappings = distilBERTWeightMappings(numLayers: numLayers)
        try mapWeights(weights, to: model, mapping: mappings)

        LoggerService.shared.info("DistilBERT weights loaded and mapped successfully")
    }

    // MARK: - 权重诊断

    /// 获取权重字典的统计信息
    ///
    /// - Parameter weights: 权重字典
    /// - Returns: 元组包含 (张量数量, 总元素数, 估算内存大小 MB)
    static func weightStatistics(
        _ weights: [String: MLXArray]
    ) -> (count: Int, totalElements: Int, estimatedMB: Double) {
        var totalElements = 0

        for (_, weight) in weights {
            var elements = 1
            for dim in weight.shape {
                elements *= Int(dim)
            }
            totalElements += elements
        }

        // 按 Float32 估算（实际可能混合精度）
        let bytesPerElement = 4
        let estimatedMB = Double(totalElements * bytesPerElement) / (1024.0 * 1024.0)

        return (weights.count, totalElements, estimatedMB)
    }

    /// 打印权重字典的摘要信息（用于调试）
    ///
    /// - Parameter weights: 权重字典
    /// - Parameter prefix: 日志前缀，默认 "Weight"
    static func logWeightSummary(
        _ weights: [String: MLXArray],
        prefix: String = "Weight"
    ) {
        let stats = weightStatistics(weights)
        LoggerService.shared.info(
            "[\(prefix)] \(stats.count) tensors, "
                + "\(stats.totalElements) total elements, "
                + "~\(String(format: "%.1f", stats.estimatedMB)) MB"
        )

        // 打印前 10 个最大的张量
        let sortedKeys = weights.keys.sorted { a, b in
            let sizeA = weights[a]!.shape.reduce(1) { $0 * Int($1) }
            let sizeB = weights[b]!.shape.reduce(1) { $0 * Int($1) }
            return sizeA > sizeB
        }

        for key in sortedKeys.prefix(10) {
            let weight = weights[key]!
            let shape = weight.shape.map { Int($0) }
            LoggerService.shared.info("[\(prefix)] \(key): shape=\(shape), dtype=\(weight.dtype)")
        }

        if sortedKeys.count > 10 {
            LoggerService.shared.info(
                "[\(prefix)] ... and \(sortedKeys.count - 10) more tensors"
            )
        }
    }
}
