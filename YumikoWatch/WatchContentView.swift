import SwiftUI
import WatchKit

struct WatchContentView: View {
    // Anniversary State
    let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 12))!
    @State private var totalDays: Double = 0.0
    
    // Togemazo Virtual Pet State
    @State private var petState: String = "🐰"
    @State private var petMessage: String = "摸摸鱼，抖一抖~"
    @State private var hunger: Double = 80.0
    @State private var happiness: Double = 70.0
    @State private var energy: Double = 90.0
    @State private var showHeart = false
    @State private var showFood = false
    
    // Sensor Manager
    @StateObject private var sensorManager = WatchSensorManager()
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                HStack(spacing: 4) {
                    Text("🐰 兔可可")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.pink)
                    Spacer()
                    Text("v4.5.1")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 4)
                
                // Days Display
                VStack(spacing: 2) {
                    Text(String(format: "%.5f", totalDays))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    
                    Text("共度相伴时光")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
                
                // Pet Avatar & Interactive Bubble
                ZStack {
                    VStack(spacing: 4) {
                        Text(petState)
                            .font(.system(size: 42))
                            .scaleEffect(showHeart || showFood ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: petState)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showHeart || showFood)
                        
                        Text(petMessage)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.pink.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(height: 28)
                    }
                    
                    // Floating effects
                    if showHeart {
                        Text("🥰❤️")
                            .font(.system(size: 20))
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                            .offset(y: -30)
                    }
                    
                    if showFood {
                        Text("😋🥕")
                            .font(.system(size: 20))
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                            .offset(y: -30)
                    }
                }
                .padding(.vertical, 4)
                
                // Status Bars
                VStack(spacing: 4) {
                    statusBar(label: "饱食度 🥕", value: hunger, color: .orange)
                    statusBar(label: "快乐值 ✨", value: happiness, color: .pink)
                    statusBar(label: "精力值 ⚡️", value: energy, color: .yellow)
                }
                .padding(6)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                
                // Actions
                HStack(spacing: 6) {
                    actionButton(title: "喂胡萝卜", icon: "carrot.fill", color: .orange) {
                        feedPet()
                    }
                    
                    actionButton(title: "逗逗玩", icon: "gamecontroller.fill", color: .pink) {
                        playWithPet()
                    }
                }
                
                Button(action: {
                    restPet()
                }) {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                        Text("碎碎觉")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Text("💡 摇晃手表可自动逗宠哦！")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
        .onReceive(timer) { _ in
            let diff = Date().timeIntervalSince(startDate)
            totalDays = diff / 86400.0
            
            // Decays
            decayStats()
        }
        .onAppear {
            sensorManager.onShake = {
                handleWatchShake()
            }
            sensorManager.startMonitoring()
        }
        .onDisappear {
            sensorManager.stopMonitoring()
        }
    }
    
    // Status Bar component
    private func statusBar(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(value))%")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value / 100.0), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
    
    // Action Button component
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(color.opacity(0.7))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // Feed Pet logic
    private func feedPet() {
        guard energy > 10 else {
            petMessage = "兔可可没精力吃东西了，快让它睡觉 😴"
            triggerHaptic(.directionDown)
            return
        }
        
        hunger = min(100.0, hunger + 15.0)
        energy = max(0.0, energy - 10.0)
        petState = "😋"
        petMessage = "兔可可大口嚼胡萝卜！好吃！"
        triggerHaptic(.success)
        
        withAnimation {
            showFood = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                showFood = false
                resetPetEmoji()
            }
        }
    }
    
    // Play Pet logic
    private func playWithPet() {
        guard energy > 15 else {
            petMessage = "兔可可累趴下了，抱不动啦 😴"
            triggerHaptic(.directionDown)
            return
        }
        
        happiness = min(100.0, happiness + 20.0)
        energy = max(0.0, energy - 15.0)
        petState = "🥰"
        petMessage = "你揉了揉兔可可的垂耳，它超开心！"
        triggerHaptic(.success)
        
        withAnimation {
            showHeart = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                showHeart = false
                resetPetEmoji()
            }
        }
    }
    
    // Rest Pet logic
    private func restPet() {
        energy = min(100.0, energy + 40.0)
        petState = "😴"
        petMessage = "兔可可钻进窝里呼呼大睡... 💤"
        triggerHaptic(.start)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            resetPetEmoji()
        }
    }
    
    // Sensor shake handler
    private func handleWatchShake() {
        // Shaking the watch plays with the pet
        if energy > 15 {
            happiness = min(100.0, happiness + 15.0)
            hunger = max(0.0, hunger - 5.0) // Shaking burns some calories!
            energy = max(0.0, energy - 12.0)
            petState = "🤪"
            petMessage = "嗷呜！摇晃中兔可可飞起来啦！"
            triggerHaptic(.click)
            
            withAnimation {
                showHeart = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation {
                    showHeart = false
                    resetPetEmoji()
                }
            }
        } else {
            petMessage = "兔可可太困了，摇不醒了 😴"
            triggerHaptic(.directionDown)
        }
    }
    
    private func resetPetEmoji() {
        if hunger < 30 || happiness < 30 {
            petState = "😢"
            petMessage = "兔可可有点饿/不开心了..."
        } else if energy < 20 {
            petState = "😩"
            petMessage = "兔可可昏昏欲睡..."
        } else {
            petState = "🐰"
            petMessage = "摸摸鱼，抖一抖~"
        }
    }
    
    // Simulated decays over time
    @State private var lastDecayTime = Date()
    private func decayStats() {
        let now = Date()
        let interval = now.timeIntervalSince(lastDecayTime)
        if interval >= 5.0 { // every 5 seconds
            lastDecayTime = now
            hunger = max(0.0, hunger - 1.0)
            happiness = max(0.0, happiness - 1.5)
            // Energy recovers slowly if not doing actions
            if petState == "😴" {
                energy = min(100.0, energy + 3.0)
            } else {
                energy = max(0.0, energy - 0.5)
            }
        }
    }
    
    private func triggerHaptic(_ type: WKHapticType) {
        #if os(watchOS)
        WKInterfaceDevice.current().play(type)
        #endif
    }
}
