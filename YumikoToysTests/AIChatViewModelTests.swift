//
//  AIChatViewModelTests.swift
//  YumikoToysTests
//
//  AI 聊天视图模型测试
//

import XCTest
import Combine
@testable import YumikoToys

@MainActor
final class AIChatViewModelTests: XCTestCase {
    
    var viewModel: AIChatViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        viewModel = AIChatViewModel()
    }
    
    override func tearDown() {
        viewModel.clearHistory()
        viewModel = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - 初始状态测试
    
    func testInitialState() {
        // Then
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - 发送消息测试
    
    func testSendMessageUpdatesLoadingState() {
        // Given
        let expectation = expectation(description: "Loading state changes")
        var loadingStates: [Bool] = []
        
        viewModel.$isLoading
            .sink { state in
                loadingStates.append(state)
                if loadingStates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        viewModel.sendMessage("Test message")
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(loadingStates.contains(true))
    }
    
    func testSendMessageAddsUserMessage() {
        // Given
        let messageContent = "Hello AI"
        let expectation = expectation(description: "Message added")
        
        viewModel.$messages
            .dropFirst()
            .sink { messages in
                if messages.contains(where: { $0.content == messageContent && $0.role == "user" }) {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        viewModel.sendMessage(messageContent)
        
        // Then
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - 清空历史测试
    
    func testClearHistory() {
        // Given
        viewModel.sendMessage("Test")
        
        // When
        viewModel.clearHistory()
        
        // Then
        XCTAssertTrue(viewModel.messages.isEmpty)
    }
}
