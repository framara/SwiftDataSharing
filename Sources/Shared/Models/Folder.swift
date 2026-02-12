//
//  Folder.swift
//  SwiftDataSharing
//
//  A container for organizing notes. Shared between all targets.
//

import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "folder.fill"
    var colorHex: String = "007AFF"
    var createdAt: Date = Date()
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade)
    var notes: [Note]? = []

    /// Returns notes sorted by creation date (newest first)
    var sortedNotes: [Note] {
        notes?.sorted(by: { $0.createdAt > $1.createdAt }) ?? []
    }

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.fill",
        colorHex: String = "007AFF",
        createdAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}
