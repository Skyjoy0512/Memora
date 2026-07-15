import Foundation

/// Host-only secret lookup for the shared Plaud persistence model.
extension PlaudSettings {
    var isTokenValid: Bool {
        guard let expiresAt = KeychainService.loadDate(key: .plaudTokenExpiresAt) else { return false }
        return Date() < expiresAt
    }

    var shouldRefreshToken: Bool {
        guard let expiresAt = KeychainService.loadDate(key: .plaudTokenExpiresAt) else { return false }
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        return expiresAt < thirtyDaysFromNow
    }
}
