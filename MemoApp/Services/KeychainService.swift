import Foundation
import Security

/// Keychainを使用してAPIキーを安全に保存・取得するサービス
class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    private let service = "com.memoapp.apikeys"
    
    // MARK: - OpenAI API Key
    
    private let openAIKeyAccount = "openai_api_key"
    
    /// OpenAI API キーを保存
    func saveOpenAIKey(_ key: String) -> Bool {
        return save(key: key, account: openAIKeyAccount)
    }
    
    /// OpenAI API キーを取得
    func getOpenAIKey() -> String? {
        return load(account: openAIKeyAccount)
    }
    
    /// OpenAI API キーを削除
    func deleteOpenAIKey() -> Bool {
        return delete(account: openAIKeyAccount)
    }
    
    /// OpenAI API キーが設定されているかチェック
    func hasOpenAIKey() -> Bool {
        return getOpenAIKey() != nil && !getOpenAIKey()!.isEmpty
    }
    
    // MARK: - Generic Keychain Operations
    
    private func save(key: String, account: String) -> Bool {
        let data = key.data(using: .utf8)!
        
        // 既存のキーを削除
        delete(account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        
        return nil
    }
    
    private func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
} 