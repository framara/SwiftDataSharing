//
//  NoteType.swift
//  SwiftDataSharing
//
//  Shared between all targets (App, Share Extension, Widget).
//

import Foundation

enum NoteType: String, Codable {
    case text
    case link
    case image
}
