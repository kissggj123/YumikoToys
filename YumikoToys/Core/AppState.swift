//
//  AppState.swift
//  YumikoToys
//
//  全局应用状态
//

import Foundation
import Combine

/// 应用状态管理器
final class AppState: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AppState()
    
    // MARK: - Published Properties
    
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isInitialized = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Methods
    
    /// 设置错误
    func setError(_ message: String) {
        errorMessage = message
        showError = true
        LoggerService.shared.error("App error: \(message)")
    }
    
    /// 清除错误
    func clearError() {
        errorMessage = nil
        showError = false
    }
    
    /// 标记初始化完成
    func markInitialized() {
        isLoading = false
        isInitialized = true
        LoggerService.shared.info("App state initialized")
    }
    
    /// 标记加载中
    func markLoading() {
        isLoading = true
    }
}
