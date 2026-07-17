import Foundation

enum AskAIHostMemoryPrivacyConfiguration {
    static func make(mode: String) -> AskAIMemoryPrivacyConfiguration {
        AskAIMemoryPrivacyConfiguration(
            mode: mode,
            disabledFactIDs: Set(
                (UserDefaults.standard.stringArray(forKey: "disabledMemoryFactIDs") ?? [])
                    .compactMap(UUID.init(uuidString:))
            )
        )
    }
}
