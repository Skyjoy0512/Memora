import Foundation
import SwiftData

/// The one persistent-store configuration shared by the SwiftUI and React Native hosts.
public enum MemoraSharedStoreFactory {
    public static func makePersistentContainer(at storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: storeURL, allowsSave: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: Schema(versionedSchema: MemoraSchemaV3.self),
            migrationPlan: MemoraMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
