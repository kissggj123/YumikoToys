import SwiftUI

#if os(macOS)
import AppKit
#endif

@main
struct PetPlaygroundApp: App {
    @StateObject private var engine = PetEngine.shared

    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup("宠物控制台") {
            PetPlaygroundView(overlay: false)
                .environmentObject(engine)
                .frame(minWidth: 620, minHeight: 420)
                .onAppear { engine.start() }
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}

struct PetPlaygroundView: View {
    @EnvironmentObject private var engine: PetEngine
    let overlay: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if overlay {
                    Color.clear
                } else {
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.88), Color.cyan.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 12) {
                        Text("四人爬爬乐")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text("四个角色会以各自的速度和动作节奏，在 Dock 上方独立爬行。")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.9))
                        HStack {
                            Button(engine.isPaused ? "继续玩耍" : "暂停") {
                                engine.isPaused.toggle()
                            }
                            Button("重新集合") {
                                engine.resetPets()
                            }
                            #if os(macOS)
                            Button("退出桌宠", role: .destructive) {
                                NSApplication.shared.terminate(nil)
                            }
                            #endif
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                }

                ForEach(engine.pets) { pet in
                    PetSprite(pet: pet)
                        .position(pet.position)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .onAppear { updateMobileLane(for: proxy.size) }
            .onChange(of: proxy.size) { newSize in updateMobileLane(for: newSize) }
        }
    }

    private func updateMobileLane(for size: CGSize) {
        #if !os(macOS)
        let halfPet: CGFloat = 75
        let margin: CGFloat = 12
        engine.updateMovementLane(
            MovementLane(
                minX: halfPet + margin,
                maxX: max(halfPet + margin, size.width - halfPet - margin),
                y: max(halfPet + margin, size.height - halfPet - margin)
            )
        )
        #endif
    }
}

#if os(macOS)
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    private var overlays: [NSPanel] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        PetEngine.shared.start()
        DispatchQueue.main.async { [weak self] in
            self?.installOverlays()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PetEngine.shared.stop()
        overlays.forEach {
            $0.orderOut(nil)
            $0.close()
        }
        overlays.removeAll()
    }

    private func installOverlays() {
        overlays = NSScreen.screens.map { screen in
            if let mainScreen = NSScreen.main, screen === mainScreen {
                PetEngine.shared.updateMovementLane(Self.movementLane(for: screen))
            }

            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.ignoresMouseEvents = true
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false

            let hostingView = NSHostingView(
                rootView: PetPlaygroundView(overlay: true)
                    .environmentObject(PetEngine.shared)
            )
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
            hostingView.autoresizingMask = [.width, .height]
            panel.contentView = hostingView
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            return panel
        }
    }

    private static func movementLane(for screen: NSScreen) -> MovementLane {
        let frame = screen.frame
        let visible = screen.visibleFrame
        let localVisible = CGRect(
            x: visible.minX - frame.minX,
            y: frame.maxY - visible.maxY,
            width: visible.width,
            height: visible.height
        )
        let halfPet: CGFloat = 75
        let margin: CGFloat = 12
        return MovementLane(
            minX: localVisible.minX + halfPet + margin,
            maxX: max(
                localVisible.minX + halfPet + margin,
                localVisible.maxX - halfPet - margin
            ),
            y: max(halfPet + margin, localVisible.maxY - halfPet - margin)
        )
    }
}
#endif
