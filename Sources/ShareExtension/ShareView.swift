//
//  ShareView.swift
//  ShareExtension
//
//  Lets the user pick a folder and save shared content as a note.
//
//  KEY PATTERN: The share extension writes to the SAME SwiftData container
//  as the main app via `SharedDataManager.shared.container`. After saving,
//  it calls `reloadWidgets()` so widgets reflect the new data immediately.
//

import SwiftUI
import SwiftData

struct ShareView: View {
    let extensionContext: NSExtensionContext?
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]

    @State private var isProcessing = false
    @State private var isSaved = false

    var body: some View {
        NavigationStack {
            Group {
                if folders.isEmpty {
                    ContentUnavailableView(
                        "No Folders",
                        systemImage: "folder",
                        description: Text("Open the app to create a folder first.")
                    )
                } else {
                    List(folders) { folder in
                        Button {
                            saveToFolder(folder)
                        } label: {
                            Label(folder.name, systemImage: folder.icon)
                        }
                        .disabled(isProcessing)
                    }
                }
            }
            .navigationTitle("Save to...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onComplete() }
                }
            }
            .overlay {
                if isSaved {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("Saved!")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }

    private func saveToFolder(_ folder: Folder) {
        isProcessing = true

        // Extract shared content from the extension context.
        Task {
            let sharedText = await extractSharedText()
            let note = Note(type: .text, text: sharedText ?? "Shared item")
            note.folder = folder
            modelContext.insert(note)

            do {
                try modelContext.save()
                SharedDataManager.shared.reloadWidgets()
                isSaved = true

                // Brief delay so the user sees the confirmation, then dismiss.
                try? await Task.sleep(for: .seconds(0.8))
                onComplete()
            } catch {
                print("[ShareExtension] Failed to save: \(error)")
                isProcessing = false
            }
        }
    }

    /// Extracts plain-text content from the share extension input items.
    private func extractSharedText() async -> String? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return nil
        }

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    let result = try? await provider.loadItem(
                        forTypeIdentifier: "public.plain-text"
                    )
                    if let text = result as? String {
                        return text
                    }
                }
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    let result = try? await provider.loadItem(
                        forTypeIdentifier: "public.url"
                    )
                    if let url = result as? URL {
                        return url.absoluteString
                    }
                }
            }
        }
        return nil
    }
}
