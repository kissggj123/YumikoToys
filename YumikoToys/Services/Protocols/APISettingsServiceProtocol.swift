//
//  APISettingsServiceProtocol.swift
//  YumikoToys
//

import Foundation

protocol APISettingsServiceProtocol {
    var serviceName: String { get }
    func initialize() async
    func getSettings() -> APISettings
    func updateSettings(_ settings: APISettings)
    func estimateTokens(sent: String, received: String) -> (sent: Int, received: Int)
}
