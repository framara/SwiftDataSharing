//
//  WidgetDataManager.swift
//  NotesWidget
//
//  READ-ONLY access to the shared SwiftData container for the widget target.
//
//  WHY AN ACTOR?
//  Widgets run on background threads. Using an actor guarantees safe,
//  serialized access to the container without data races.
//
//  WHY NOT SharedDataManager?
//  - Widgets should NEVER write to the database (risk of conflicts with the
//    main app writing at the same time).
//  - SharedDataManager is @MainActor, which doesn't suit widget timelines.
//  - The widget sets `cloudKitDatabase: .none` since only the main app
//    should drive iCloud sync.
//

import Foundation
import SwiftData

actor WidgetDataManager {
    static let shared = WidgetDataManager()
    private var container: ModelContainer?
    private init() {}

    func getContainer() throws -> ModelContainer {
        if let container {
            return container
        }

        let schema = Schema(versionedSchema: SchemaV1.self)

        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        ) else {
            throw WidgetError.noAppGroup
        }

        let storeURL = groupURL.appendingPathComponent(AppConstants.databaseFileName)
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none // Widgets only read, never sync.
        )

        let newContainer = try ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: [config]
        )
        container = newContainer
        return newContainer
    }
}

enum WidgetError: Error {
    case noAppGroup
}
