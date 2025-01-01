import Foundation
import os

// MARK: - Configuration Models
struct Configuration: Codable {
    let discogsToken: String
    let lastFMAPIKey: String
    let lastFMSecret: String
    
    private enum CodingKeys: String, CodingKey {
        case discogsToken
        case lastFMAPIKey = "lastFMApiKey"
        case lastFMSecret
    }
}

// MARK: - Configuration Manager
class ConfigurationManager {
    static let shared = ConfigurationManager()
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "ConfigurationManager")
    
    var discogsToken: String? {
        SecureConfig.discogsToken
    }
    
    var lastFMAPIKey: String? {
        SecureConfig.lastFMAPIKey
    }
    
    var lastFMSecret: String? {
        SecureConfig.lastFMSecret
    }
    
    private init() {
        validateConfiguration()
    }
    
    private func validateConfiguration() {
        guard discogsToken != nil,
              lastFMAPIKey != nil,
              lastFMSecret != nil else {
            logger.error("❌ Failed to load secure configuration")
            return
        }
        logger.info("✅ Secure configuration loaded successfully")
    }
}

enum ConfigError: Error {
    case saveFailed
}
