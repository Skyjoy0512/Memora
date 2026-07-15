import Foundation

/// Host-only secret lookup for the shared Google Meet persistence model.
extension GoogleMeetSettings {
    var isTokenValid: Bool {
        let accessToken = KeychainService.load(key: .googleMeetAccessToken)
        guard !accessToken.isEmpty,
              let expiresAt = KeychainService.loadDate(key: .googleMeetTokenExpiresAt) else {
            return false
        }
        return expiresAt > Date()
    }

    var shouldRefreshToken: Bool {
        let refreshToken = KeychainService.load(key: .googleMeetRefreshToken)
        guard !refreshToken.isEmpty else { return false }
        guard let expiresAt = KeychainService.loadDate(key: .googleMeetTokenExpiresAt) else { return true }
        return expiresAt.addingTimeInterval(-300) <= Date()
    }
}
