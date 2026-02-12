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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Inject the shared container so every view gets the same ModelContext.
        .modelContainer(SharedDataManager.shared.container)
    }
}
