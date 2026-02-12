//
//  SchemaVersions.swift
//  SwiftDataSharing
//
//  Schema versioning for SwiftData migrations.
//  Shared between all targets so the migration chain stays consistent.
//
//  STRATEGY:
//  - Folder.swift and Note.swift always contain the CURRENT model definitions.
//  - Each schema version references the live models.
//  - When making a breaking change post-release:
//    1. Copy the OLD model definitions into a frozen "Legacy" schema.
//    2. Update the live models with the new structure.
//    3. Create a new SchemaVN pointing to the updated models.
//    4. Add a MigrationStage.custom from the legacy version.
//
//  IMPORTANT: SwiftData requires ALL schema versions in the chain.
//  Omitting an old version causes the migrator to fail for users still
//  on that version, potentially recreating the database empty (DATA LOSS).
//

import Foundation
import SwiftData

// MARK: - Schema V1 (Initial Release)

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Folder.self, Note.self]
    }
}

// MARK: - Schema V2 (Example: adding a field)
//
// If you later add `var subtitle: String? = nil` to Note, create V2:
//
// enum SchemaV2: VersionedSchema {
//     static let versionIdentifier = Schema.Version(1, 1, 0)
//     static var models: [any PersistentModel.Type] { [Folder.self, Note.self] }
// }
//
// Then update the migration plan below to include SchemaV2.

// MARK: - Migration Plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        // Include ALL versions so SwiftData can migrate from any.
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No explicit stages needed for additive optional fields.
        // SwiftData handles these as automatic lightweight migrations.
        []
    }
}
