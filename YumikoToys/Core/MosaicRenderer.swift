//
//  MosaicRenderer.swift
//  YumikoToys
//
//  基于 CIImage / CIFilter 的像素化和模糊渲染器
//  - 用于截图标注（Pixelate / Blur 两种马赛克模式）
//  - 支持：从 NSImage 读取原始像素、在 CGRect 范围进行像素化或高斯模糊
//  - 输出为 NSImage （与原 image 同 DPI）
//
//  策略：
//  1. 先将源 NSImage 转成 CIImage
//  2. 裁剪（CICrop）得到目标区域，并分别应用 CIPixellate / CIGaussianBlur
//  3. 将结果与原图合成（CISourceOverCompositing）
//  4. 渲染回 NSBitmapImageRep 并返回 NSImage
//

import AppKit
import CoreImage
import CoreGraphics

enum MosaicTool: Sendable {
    case pixelate(blockSize: CGFloat)   // 像素化：blockSize 是像素块（像素）
    case blur(radius: CGFloat)          // 模糊：radius 是高斯半径（像素）
}

@MainActor
final class MosaicRenderer {
    private let context: CIContext

    init() {
        // 使用 Metal 优先；若不可用则回退到 CPU（ColorSync + CPU 渲染）
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .cacheIntermediates: false
        ]
        if let metal = MTLCreateSystemDefaultDevice(), let queue = metal.makeCommandQueue() {
            self.context = CIContext(mtlCommandQueue: queue, options: options)
        } else {
            self.context = CIContext(options: options)
        }
    }

    // MARK: - 单步处理（单个 rect）

    /// 对 image 的指定 rect 做马赛克（像素化），rect 以 image 坐标（左下原点，像素）
    func apply(_ tool: MosaicTool, rect: NSRect, to image: NSImage) -> NSImage {
        guard !NSIsEmptyRect(rect) else { return image }
        guard let cgImage = image.cgImage else { return image }

        let source = CIImage(cgImage: cgImage)

        // 将 macOS 坐标（左下原点，像素）转换成 CIImage 的原点坐标（左上）
        // CIImage.extent 使用图像像素坐标系，原点在左下，但 Y 翻转
        // 这里传入的 rect 已为“像素”坐标（image 坐标系）
        let imageHeight = CGFloat(cgImage.height)
        let ciRect = CGRect(
            x: rect.origin.x,
            y: imageHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        // 裁剪
        guard let crop = CIFilter(name: "CICrop", parameters: [
            kCIInputImageKey: source,
            "inputRectangle": CIVector(cgRect: ciRect)
        ])?.outputImage else { return image }

        let processed: CIImage
        switch tool {
        case .pixelate(let blockSize):
            guard let f = CIFilter(name: "CIPixellate", parameters: [
                kCIInputImageKey: crop,
                kCIInputScaleKey: max(1, Float(blockSize))
            ]) else { return image }
            processed = f.outputImage ?? crop

        case .blur(let radius):
            guard let f = CIFilter(name: "CIGaussianBlur", parameters: [
                kCIInputImageKey: crop,
                kCIInputRadiusKey: max(0.1, Float(radius))
            ]) else { return image }
            processed = f.outputImage ?? crop
        }

        // 将处理后的区域重新放到原图上
        let translate = CGAffineTransform(translationX: ciRect.origin.x, y: ciRect.origin.y)
        let placed = processed.transformed(by: translate)

        guard let composite = CIFilter(name: "CISourceOverCompositing", parameters: [
            kCIInputImageKey: placed,
            kCIInputBackgroundImageKey: source
        ])?.outputImage else { return image }

        // 渲染为 CGImage
        let extent = source.extent
        guard let rendered = context.createCGImage(composite, from: extent) else { return image }

        // 保持 NSImage 的像素尺寸（与 source 一致）
        let finalSize = NSSize(width: cgImage.width, height: cgImage.height)
        let result = NSImage(cgImage: rendered, size: finalSize)
        return result
    }

    // MARK: - 批量应用多个标注（多个矩形）

    struct AnnotationArea {
        let tool: MosaicTool
        let rect: NSRect  // image 坐标系（像素，左下原点）
    }

    func applyAll(_ areas: [AnnotationArea], to image: NSImage) -> NSImage {
        var current = image
        for area in areas {
            current = apply(area.tool, rect: area.rect, to: current)
        }
        return current
    }
}

// MARK: - 便捷扩展（NSImage -> CGImage）

extension NSImage {
    /// 始终返回 CGImage；优先使用 representations，其次 cgImage(forProposedRect)
    var cgImage: CGImage? {
        if let rep = representations.first as? NSBitmapImageRep {
            return rep.cgImage
        }
        var proposedRect = NSRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }
}
