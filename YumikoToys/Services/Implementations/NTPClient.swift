//
//  NTPClient.swift
//  YumikoToys
//
//  NTP 时间同步客户端
//

import Foundation
import Network

// MARK: - NTP 错误

enum NTPError: Error {
    case invalidServer
    case networkError(Error)
    case timeout
    case invalidResponse
    case noValidServer
}

// MARK: - NTP 数据包

/// NTP 协议数据包 (RFC 4330 - SNTP)
struct NTPPacket {
    // 第一个字节：LI(2) + VN(3) + Mode(3)
    var li_vn_mode: UInt8 = 0x1B  // 00 011 011: LI=0, VN=3, Mode=3 (Client)
    var stratum: UInt8 = 0
    var poll: UInt8 = 0
    var precision: Int8 = 0
    var rootDelay: UInt32 = 0
    var rootDispersion: UInt32 = 0
    var referenceID: UInt32 = 0
    var referenceTimestamp: UInt64 = 0
    var originateTimestamp: UInt64 = 0
    var receiveTimestamp: UInt64 = 0
    var transmitTimestamp: UInt64 = 0
    
    static let size = 48
    
    /// 默认初始化器（创建客户端请求包）
    init() {
        // li_vn_mode = 0x1B = 00 011 011
        // LI = 0 (无闰秒警告)
        // VN = 3 (版本3)
        // Mode = 3 (客户端)
        self.li_vn_mode = 0x1B
    }
    
    /// 转换为网络字节序数据
    func toData() -> Data {
        var data = Data(capacity: Self.size)
        data.append(li_vn_mode)
        data.append(stratum)
        data.append(poll)
        data.append(UInt8(bitPattern: precision))
        data.append(contentsOf: rootDelay.bigEndian.bytes)
        data.append(contentsOf: rootDispersion.bigEndian.bytes)
        data.append(contentsOf: referenceID.bigEndian.bytes)
        data.append(contentsOf: referenceTimestamp.bigEndian.bytes)
        data.append(contentsOf: originateTimestamp.bigEndian.bytes)
        data.append(contentsOf: receiveTimestamp.bigEndian.bytes)
        data.append(contentsOf: transmitTimestamp.bigEndian.bytes)
        return data
    }
    
    /// 从网络字节序数据解析
    init?(data: Data) {
        guard data.count >= Self.size else { return nil }
        
        li_vn_mode = data[0]
        stratum = data[1]
        poll = data[2]
        precision = Int8(bitPattern: data[3])
        rootDelay = UInt32(bigEndian: data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) })
        rootDispersion = UInt32(bigEndian: data.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: UInt32.self) })
        referenceID = UInt32(bigEndian: data.subdata(in: 12..<16).withUnsafeBytes { $0.load(as: UInt32.self) })
        referenceTimestamp = UInt64(bigEndian: data.subdata(in: 16..<24).withUnsafeBytes { $0.load(as: UInt64.self) })
        originateTimestamp = UInt64(bigEndian: data.subdata(in: 24..<32).withUnsafeBytes { $0.load(as: UInt64.self) })
        receiveTimestamp = UInt64(bigEndian: data.subdata(in: 32..<40).withUnsafeBytes { $0.load(as: UInt64.self) })
        transmitTimestamp = UInt64(bigEndian: data.subdata(in: 40..<48).withUnsafeBytes { $0.load(as: UInt64.self) })
    }
    
    /// 获取发送时间戳（秒级，从1900年开始）
    var transmitTime: TimeInterval {
        let seconds = Double(transmitTimestamp >> 32)
        let fraction = Double(transmitTimestamp & 0xFFFFFFFF) / Double(1 << 32)
        return seconds + fraction
    }
    
    /// 获取接收时间戳
    var receiveTime: TimeInterval {
        let seconds = Double(receiveTimestamp >> 32)
        let fraction = Double(receiveTimestamp & 0xFFFFFFFF) / Double(1 << 32)
        return seconds + fraction
    }
}

// MARK: - NTP 客户端

actor NTPClient {
    
    // MARK: - 配置
    
    /// 默认 NTP 服务器池
    static let defaultServers = [
        "time.apple.com",           // Apple
        "time.asia.apple.com",      // Apple Asia
        "cn.pool.ntp.org",          // 中国 NTP 池
        "ntp.aliyun.com",           // 阿里云
        "ntp.tencentcloud.com",     // 腾讯云
    ]
    
    private let servers: [String]
    private let port: UInt16 = 123
    private let timeout: TimeInterval = 5.0
    
    // MARK: - 初始化
    
    init(servers: [String] = defaultServers) {
        self.servers = servers
    }
    
    // MARK: - 公共方法
    
    /// 同步时间，返回时间偏移量（秒）
    /// 正值表示本地时间比 NTP 时间慢，需要加上偏移量
    func sync() async throws -> TimeInterval {
        var lastError: Error?
        
        for server in servers {
            do {
                let offset = try await syncWithServer(server)
                LoggerService.shared.info("NTP sync successful with \(server), offset: \(offset) seconds")
                return offset
            } catch {
                lastError = error
                LoggerService.shared.warning("NTP sync failed for \(server): \(error)")
                continue
            }
        }
        
        throw lastError ?? NTPError.noValidServer
    }
    
    /// 同步时间并返回当前准确时间
    func currentTime() async throws -> Date {
        let offset = try await sync()
        return Date().addingTimeInterval(offset)
    }
    
    // MARK: - 私有方法
    
    private func syncWithServer(_ server: String) async throws -> TimeInterval {
        let host = NWEndpoint.Host(server)
        let endpoint = NWEndpoint.hostPort(host: host, port: .init(integerLiteral: port))
        
        // 创建 UDP 连接
        let connection = NWConnection(to: endpoint, using: .udp)
        
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            let lock = NSLock()
            
            func safeResume<T>(throwing error: T) where T: Error {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(throwing: error)
            }
            
            func safeResume(returning value: TimeInterval) {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: value)
            }
            
            // 超时处理
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(self.timeout * 1_000_000_000))
                connection.cancel()
                safeResume(throwing: NTPError.timeout)
            }
            
            connection.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                
                switch state {
                case .ready:
                    Task { await self.sendRequest(connection: connection) }
                    
                case .failed(let error):
                    timeoutTask.cancel()
                    safeResume(throwing: NTPError.networkError(error))
                    
                case .cancelled:
                    timeoutTask.cancel()
                    
                default:
                    break
                }
            }
            
            connection.receiveMessage { data, context, isComplete, error in
                timeoutTask.cancel()
                
                if let error = error {
                    safeResume(throwing: NTPError.networkError(error))
                    return
                }
                
                guard let data = data,
                      let packet = NTPPacket(data: data) else {
                    safeResume(throwing: NTPError.invalidResponse)
                    return
                }
                
                // 计算时间偏移
                // offset = ((T1 - T0) + (T2 - T3)) / 2
                // T0: 客户端发送时间
                // T1: 服务器接收时间
                // T2: 服务器发送时间
                // T3: 客户端接收时间
                
                let t0 = Date().timeIntervalSince1970 + 2208988800  // 转换为 NTP 时间（从1900年）
                let t1 = packet.receiveTime
                let t2 = packet.transmitTime
                let t3 = Date().timeIntervalSince1970 + 2208988800
                
                let offset = ((t1 - t0) + (t2 - t3)) / 2
                
                // 转换回 Unix 时间偏移（减去 NTP 到 Unix 的偏移）
                let unixOffset = offset
                
                safeResume(returning: unixOffset)
            }
            
            connection.start(queue: .global())
        }
    }
    
    private func sendRequest(connection: NWConnection) async {
        let packet = NTPPacket()
        let data = packet.toData()
        
        return await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    LoggerService.shared.error("NTP send failed: \(error)")
                }
                continuation.resume()
            })
        }
    }
}

// MARK: - 辅助扩展

extension UInt32 {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self.bigEndian, Array.init)
    }
}

extension UInt64 {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self.bigEndian, Array.init)
    }
}
