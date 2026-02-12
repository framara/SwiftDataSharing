//
//  Note.swift
//  SwiftDataSharing
//
//  A piece of saved content. Shared between all targets.
//

import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var type: NoteType = NoteType.text

    // Content
    var text: String? = nil
    var url: URL? = nil
    var title: String? = nil

    // Parent
    var folder: Folder? = nil

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        type: NoteType,
        text: String? = nil,
        url: URL? = nil,
        title: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.type = type
        self.text = text
        self.url = url
        self.title = title
    }

    /// Best display text for this note
    var displayText: String {
        switch type {
        case .text:
            return text ?? "Note"
        case .link:
            return title ?? url?.absoluteString ?? "Link"
        case .image:
            return title ?? "Image"
        }
    }
}
