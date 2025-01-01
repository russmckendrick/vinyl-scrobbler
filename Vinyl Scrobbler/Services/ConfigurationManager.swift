import Foundation
import os

// MARK: - Configuration Manager
// Manages and validates API credentials for Discogs and Last.fm
class ConfigurationManager {
    // Singleton instance
    static let shared = ConfigurationManager()
    
    // Logger for configuration-related events
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "ConfigurationManager")
    
    // MARK: - Properties
    // Convenience accessors for secure configuration
    var discogsToken: String? {
        SecureConfig.discogsToken
    }
    
    var lastFMAPIKey: String? {
        SecureConfig.lastFMAPIKey
    }
    
    var lastFMSecret: String? {
        SecureConfig.lastFMSecret
    }
    
    // MARK: - Initialization
    private init() {
        validateConfiguration()
    }
    
    // MARK: - Private Methods
    // Validate that all required API credentials are present
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
