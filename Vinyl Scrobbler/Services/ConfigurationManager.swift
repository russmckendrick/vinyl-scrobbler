import Foundation
import os

/// A singleton service responsible for managing and validating API credentials
/// for both Discogs and Last.fm services. This manager ensures that all required
/// authentication tokens and keys are available before the application attempts
/// to communicate with external services.
class ConfigurationManager {
    /// The shared singleton instance of the ConfigurationManager
    /// This ensures only one instance manages the configuration throughout the app's lifecycle
    static let shared = ConfigurationManager()
    
    /// Logger instance for tracking configuration-related events and errors
    /// Uses the unified logging system with a specific subsystem and category
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "ConfigurationManager")
    
    // MARK: - Properties
    
    /// The authentication token for accessing the Discogs API
    /// Retrieved securely from the SecureConfig storage
    /// Required for searching vinyl records and retrieving album metadata
    var discogsToken: String? {
        SecureConfig.discogsToken
    }
    
    /// The API key for accessing the Last.fm API
    /// Retrieved securely from the SecureConfig storage
    /// Required for scrobbling tracks and updating listening history
    var lastFMAPIKey: String? {
        SecureConfig.lastFMAPIKey
    }
    
    /// The shared secret for Last.fm API authentication
    /// Retrieved securely from the SecureConfig storage
    /// Used for signing API requests to Last.fm
    var lastFMSecret: String? {
        SecureConfig.lastFMSecret
    }
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    /// Validates the configuration immediately upon initialization
    private init() {
        validateConfiguration()
    }
    
    // MARK: - Private Methods
    
    /// Validates that all required API credentials are present and accessible
    /// Logs the validation result using the unified logging system
    /// - Important: This check is crucial for ensuring the app can communicate with external services
    /// - Note: Logs an error if any credential is missing, and success if all are present
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

/// Represents possible errors that can occur during configuration operations
/// Currently includes errors related to saving configuration data
enum ConfigError: Error {
    /// Indicates that an attempt to save configuration data has failed
    case saveFailed
}
