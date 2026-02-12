//
//  SwiftDataSharingApp.swift
//  SwiftDataSharing
//
//  Main app entry point. Injects the shared container into the view hierarchy.
//

import SwiftUI
import SwiftData

@main
struct SwiftDataSharingApp: App {
    init() {
        seedDataIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Inject the shared container so every view gets the same ModelContext.
        .modelContainer(SharedDataManager.shared.container)
    }

    /// One-time seed data so the demo app isn't empty on first launch.
    private func seedDataIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "hasSeededData") else { return }

        let context = ModelContext(SharedDataManager.shared.container)

        let inbox = Folder(name: "Inbox", icon: "tray.fill", colorHex: "007AFF", sortOrder: 0)
        let travel = Folder(name: "Travel", icon: "airplane", colorHex: "FF9500", sortOrder: 1)

        context.insert(inbox)
        context.insert(travel)

        let note1 = Note(type: .text, text: "Remember to check the SwiftData migration docs")
        note1.folder = inbox

        let note2 = Note(type: .link, url: URL(string: "https://developer.apple.com"), title: "Apple Developer")
        note2.folder = inbox

        let note3 = Note(type: .text, text: "Book flights to Barcelona")
        note3.folder = travel

        context.insert(note1)
        context.insert(note2)
        context.insert(note3)

        try? context.save()
        SharedDataManager.shared.reloadWidgets()
        defaults.set(true, forKey: "hasSeededData")
    }
}
