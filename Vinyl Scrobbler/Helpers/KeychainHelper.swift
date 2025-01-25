import Foundation
import Security

/// Helper enum providing methods to securely store and retrieve Last.fm session keys in the system Keychain
enum KeychainHelper {
    /// Saves the Last.fm session key to the system Keychain
    /// - Parameter key: The session key string to be stored
    /// This method first removes any existing key before saving the new one to prevent duplicates
    static func saveLastFMSessionKey(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "lastfm_session_key",
            kSecValueData as String: key.data(using: .utf8)!
        ]
        
        // First try to delete any existing key
        SecItemDelete(query as CFDictionary)
        
        // Then save the new key
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("Error saving Last.fm session key to keychain: \(status)")
        }
    }
    
    /// Retrieves the stored Last.fm session key from the system Keychain
    /// - Returns: The session key as a String if found, nil otherwise
    static func getLastFMSessionKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "lastfm_session_key",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }
        
        return nil
    }
    
    /// Removes the Last.fm session key from the system Keychain
    /// This method is typically called during logout or when resetting the application state
    static func deleteLastFMSessionKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "lastfm_session_key"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Error deleting Last.fm session key from keychain: \(status)")
        }
    }
} 