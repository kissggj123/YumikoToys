//
//  GLMServiceTests.swift
//  YumikoToysTests
//
//  GLM 服务测试
//

import XCTest
@testable import YumikoToys

final class GLMServiceTests: XCTestCase {
    
    var dataStorageService: DataStorageService!
    var glmService: GLMService!
    
    override func setUp() {
        super.setUp()
        dataStorageService = DataStorageService()
        glmService = GLMService(dataStorageService: dataStorageService)
    }
    
    override func tearDown() {
        glmService.clearConversationHistory()
        glmService = nil
        dataStorageService = nil
        super.tearDown()
    }
    
    // MARK: - 对话历史测试
    
    func testAddToHistory() {
        // Given
        let message = ChatMessage(role: "user", content: "Hello")
        
        // When
        glmService.addToHistoryForTest(message)
        
        // Then
        let history = glmService.getConversationHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.content, "Hello")
    }
    
    func testHistoryLimit() {
        // Given - 添加超过最大限制的消息
        let maxCount = 50
        
        // When - 添加60条消息
        for i in 0..<60 {
            let message = ChatMessage(role: "user", content: "Message \(i)")
            glmService.addToHistoryForTest(message)
        }
        
        // Then - 历史记录应该被限制在50条
        let history = glmService.getConversationHistory()
        XCTAssertEqual(history.count, maxCount)
        XCTAssertEqual(history.first?.content, "Message \(60 - maxCount)")
    }
    
    func testClearHistory() {
        // Given
        glmService.addToHistoryForTest(ChatMessage(role: "user", content: "Test"))
        
        // When
        glmService.clearConversationHistory()
        
        // Then
        XCTAssertTrue(glmService.getConversationHistory().isEmpty)
    }
    
    // MARK: - 记忆系统测试
    
    func testGetRelevantMemory() {
        // Given
        let messages = [
            ChatMessage(role: "user", content: "我喜欢吃苹果"),
            ChatMessage(role: "assistant", content: "苹果很健康"),
            ChatMessage(role: "user", content: "今天天气很好"),
            ChatMessage(role: "assistant", content: "适合出去走走")
        ]
        
        for message in messages {
            glmService.addToHistoryForTest(message)
        }
        
        // When - 查询与"苹果"相关的内容
        let relevant = glmService.getRelevantMemory(for: "苹果", limit: 5)
        
        // Then
        XCTAssertTrue(relevant.contains { $0.content.contains("苹果") })
    }
    
    func testBuildMessages() {
        // Given
        let userMessage = "你好"
        let context: [ChatMessage] = []
        
        // When
        let messages = glmService.buildMessagesForTest(userMessage: userMessage, context: context)
        
        // Then
        XCTAssertEqual(messages.first?.role, "system")
        XCTAssertEqual(messages.last?.role, "user")
        XCTAssertEqual(messages.last?.content, "你好")
    }
}

// MARK: - 测试扩展

extension GLMService {
    func addToHistoryForTest(_ message: ChatMessage) {
        addToHistory(message)
    }
    
    func buildMessagesForTest(userMessage: String, context: [ChatMessage]) -> [GLMMessage] {
        buildMessages(userMessage: userMessage, context: context)
    }
}
