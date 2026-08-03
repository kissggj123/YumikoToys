//
//  YumikoTouchBarManager.swift
//  YumikoToys
//
//  TouchBar 宠物动态交互支持与 TouchBarItem 渲染器
//

import AppKit
import SwiftUI
import Combine

private extension NSTouchBar.CustomizationIdentifier {
    static let yumikoTouchBar = NSTouchBar.CustomizationIdentifier("com.Lite.YumikoToys.touchbar")
}

private extension NSTouchBarItem.Identifier {
    static let petStripItem = NSTouchBarItem.Identifier("com.Lite.YumikoToys.touchbar.petStrip")
    static let petControlsItem = NSTouchBarItem.Identifier("com.Lite.YumikoToys.touchbar.petControls")
}

final class YumikoTouchBarManager: NSObject, NSTouchBarDelegate {
    static let shared = YumikoTouchBarManager()

    override private init() {
        super.init()
    }

    @MainActor
    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.customizationIdentifier = .yumikoTouchBar
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [.petStripItem, .petControlsItem]
        touchBar.customizationAllowedItemIdentifiers = [.petStripItem, .petControlsItem]
        return touchBar
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .petStripItem:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.customizationLabel = "桌宠步行动画"
            let hostView = NSHostingView(rootView: TouchBarPetStripView())
            hostView.frame = NSRect(x: 0, y: 0, width: 450, height: 30)
            item.view = hostView
            return item

        case .petControlsItem:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.customizationLabel = "桌宠控制"
            let hostView = NSHostingView(rootView: TouchBarControlsView())
            hostView.frame = NSRect(x: 0, y: 0, width: 140, height: 30)
            item.view = hostView
            return item

        default:
            return nil
        }
    }
}

// MARK: - TouchBar Views

struct TouchBarPetStripView: View {
    @ObservedObject private var engine = PetPlaygroundEngine.shared

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.black.opacity(0.4)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                ForEach(engine.pets) { pet in
                    let screenWidth = max(NSScreen.main?.frame.width ?? 1400, 100)
                    let normalizedX = max(0, min(1, pet.position.x / screenWidth))
                    let touchBarX = normalizedX * (proxy.size.width - 36)

                    PetPlaygroundSpriteView(pet: pet, size: 24)
                        .position(x: touchBarX + 12, y: proxy.size.height / 2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

struct TouchBarControlsView: View {
    @ObservedObject private var engine = PetPlaygroundEngine.shared

    var body: some View {
        HStack(spacing: 6) {
            Button {
                engine.isPaused.toggle()
            } label: {
                Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
            .tint(engine.isPaused ? .green : .orange)

            Button {
                engine.resetPets()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 4)
    }
}
