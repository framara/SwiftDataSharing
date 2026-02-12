//
//  SharedDataManager.swift
//  SwiftDataSharing
//
//  Central entry point for the shared SwiftData container.
//
//  WHY THIS EXISTS
//  ---------------
//  Three targets (App, Share Extension, Widget) need to read/write the same
//  SQLite database. We achieve this by:
//
//  1. Storing the database inside the App Group container so every target
//     can access it.
//  2. Using `ModelConfiguration(url:)` to point all targets at the same file.
//  3. Using `ToMeMigrationPlan` everywhere so schema versions stay in sync.
//
//  USAGE
//  -----
//  Main App & Share Extension (read/write):
//      let context = ModelContext(SharedDataManager.shared.container)
//      // ... mutations ...
//      try context.save()
//      SharedDataManager.shared.reloadWidgets()
//
//  Widget (read-only):
//      Use `WidgetDataManager` (actor) instead — see Widget/WidgetDataManager.swift.
//

import Foundation
import SwiftData
import WidgetKit

/// Shared constants accessible from any isolation domain.
enum AppConstants {
    /// Replace with your own App Group identifier.
    static let appGroupID = "group.com.example.swiftdatasharing"
    static let databaseFileName = "AppData.sqlite"
}

@MainActor
final class SharedDataManager {
    static let shared = SharedDataManager()

    let container: ModelContainer

    private init() {
        container = Self.createContainer()
    }

    // MARK: - Container Creation

    private static func createContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)

        // Strategy 1: App Group shared container (preferred)
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        ) {
            let storeURL = groupURL.appendingPathComponent("AppData.sqlite")

            let config = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none // Set to .automatic for iCloud sync
            )

            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: AppMigrationPlan.self,
                    configurations: [config]
                )
            } catch {
                print("[SharedDataManager] App Group container failed: \(error)")
            }
        }

        // Strategy 2: Fallback to Documents directory (no sharing)
        print("[SharedDataManager] Falling back to local Documents directory.")
        let localURL = URL.documentsDirectory.appendingPathComponent("AppData.sqlite")

        let config = ModelConfiguration(
            schema: schema,
            url: localURL,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            fatalError("[SharedDataManager] Could not create any container: \(error)")
        }
    }

    // MARK: - Widget Reload

    /// Call after every save to keep widgets up to date.
    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
