import Foundation
import CoreMotion
import Combine

@MainActor
final class WatchSensorManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private var lastShakeTime = Date.distantPast
    private let shakeThreshold: Double = 2.3 // Shake threshold in G-force
    private let shakeCooldown: TimeInterval = 0.8 // Cooldown in seconds to prevent multiple rapid triggers
    
    @Published var shakeCount = 0
    var onShake: (() -> Void)?
    
    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else {
            return
        }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            let accel = data.acceleration
            let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
            
            if magnitude > self.shakeThreshold {
                let now = Date()
                if now.timeIntervalSince(self.lastShakeTime) > self.shakeCooldown {
                    self.lastShakeTime = now
                    self.shakeCount += 1
                    self.onShake?()
                }
            }
        }
    }
    
    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
    }
    
    deinit {
        motionManager.stopAccelerometerUpdates()
    }
}
