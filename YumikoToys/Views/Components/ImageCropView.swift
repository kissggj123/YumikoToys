//
//  ImageCropView.swift
//  YumikoToys
//
//  圆形裁剪视图组件
//

import SwiftUI
import AppKit

struct ImageCropView: View {
    let image: NSImage
    let onCrop: (NSImage) -> Void
    let onCancel: () -> Void

    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0

    private let cropSize: CGFloat = 200

    var body: some View {
        VStack(spacing: 20) {
            Text("调整头像显示区域")
                .font(.headline)

            ZStack {
                // 裁剪遮罩
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropSize, height: cropSize)
                    .shadow(radius: 4)

                // 可拖动/缩放的图片
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cropSize * 3, height: cropSize * 3)
                    .offset(offset)
                    .scaleEffect(scale)
                    .clipShape(Circle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(lastScale * value, 0.5), 3.0)
                            }
                            .onEnded { _ in
                                lastScale = scale
                            }
                    )
            }
            .frame(width: cropSize, height: cropSize)
            .background(
                Circle()
                    .fill(Color.black.opacity(0.3))
            )

            Text("拖动调整位置，双指缩放")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("确认") {
                    let croppedImage = cropCircleImage()
                    onCrop(croppedImage)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func cropCircleImage() -> NSImage {
        let size = NSSize(width: cropSize * 2, height: cropSize * 2)
        let newImage = NSImage(size: size)

        newImage.lockFocus()

        let circlePath = NSBezierPath(ovalIn: NSRect(origin: .zero, size: size))
        circlePath.addClip()

        image.draw(
            in: NSRect(
                x: -offset.width * 2 - size.width / 2,
                y: -offset.height * 2 - size.height / 2,
                width: size.width * 6 / scale,
                height: size.height * 6 / scale
            ),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )

        newImage.unlockFocus()
        return newImage
    }
}
