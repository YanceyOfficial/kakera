import Foundation
import SwiftData

/// All persistent models that compose the Kakera schema. Register new models here.
public let kakeraSchemaModels: [any PersistentModel.Type] = [
    VocabularyEntry.self,
    ReviewLog.self,
    DailyStory.self
]

/// SwiftData container factory.
public enum KakeraModelContainer {
    /// In-memory container for testing (not persisted to disk).
    public static func inMemory() throws -> ModelContainer {
        let schema = Schema(kakeraSchemaModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// A store of its own, in a temporary file, for a test that suspends (awaits) while other
    /// tests make and drop containers: every in-memory container shares one SQLite store
    /// (`/dev/null`), so a container freed on another thread pulls the connection from under a
    /// fetch that was waiting ("No eligible connection available"). Its own file, its own
    /// connections. Synchronous tests can stay on `inMemory()`.
    public static func scratch() throws -> ModelContainer {
        let schema = Schema(kakeraSchemaModels)
        let url = FileManager.default.temporaryDirectory.appending(path: "kakera-scratch-\(UUID().uuidString).sqlite")
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// The iCloud container the app syncs through (its private database: each person's own iCloud).
    public static let cloudKitContainerIdentifier = "iCloud.app.yancey.kakera"

    /// On-disk container for app use. With `cloudKitContainer` the store mirrors to that container's
    /// private database — and keeps working locally while no iCloud account is signed in; without it
    /// the store stays on this device. Either way it is the same store file, so turning sync on later
    /// uploads what is already there.
    public static func onDisk(cloudKitContainer: String? = nil) throws -> ModelContainer {
        let schema = Schema(kakeraSchemaModels)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKitContainer.map { .private($0) } ?? .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
