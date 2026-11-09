import Foundation
import Security

enum KeychainStore {
    private static var service: String {
        #if DEBUG
        // UI 测试使用独立条目，避免覆盖或删除开发者已保存的真实密钥。
        if ProcessInfo.processInfo.arguments.contains("--ui-test-keychain") { return "com.lipc.liuyao.ui-tests.deepseek" }
        #endif
        return "com.lipc.liuyao.deepseek"
    }
    private static let account = "personal-api-key"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    static func load() throws -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data,
              let key = String(data: data, encoding: .utf8) else { throw KeychainError(status: status) }
        return key
    }

    static func save(_ key: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: Data(key.utf8),
                                      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let added = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        } else if status != errSecSuccess { throw KeychainError(status: status) }
    }

    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    #if DEBUG
    // 个人开发安装的一次性配置入口；密钥导入后立即删除中转文件，不打包密钥。
    static func importProvisionedKeyIfPresent() throws {
        guard !ProcessInfo.processInfo.arguments.contains("--ui-test-keychain") else { return }
        var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(".deepseek-once")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        let key = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            guard !key.isEmpty, !key.contains(where: { $0.isWhitespace }) else { throw ImportError.invalid }
            try save(key)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
        try FileManager.default.removeItem(at: url)
    }
    private enum ImportError: LocalizedError {
        case invalid
        var errorDescription: String? { "一次性密钥配置无效，请在设置页重新输入。" }
    }
    #endif
}

private struct KeychainError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? {
        if status == errSecMissingEntitlement { return "安装包缺少钥匙串权限（OSStatus \(status)），请重新签名安装。" }
        return "无法访问 iPhone 钥匙串（OSStatus \(status)），请解锁设备后重试。"
    }
}
