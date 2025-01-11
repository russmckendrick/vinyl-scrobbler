import Foundation
import Security

enum KeychainHelper {
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