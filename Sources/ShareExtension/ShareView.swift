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
import UniformTypeIdentifiers

struct ShareView: View {
    let extensionContext: NSExtensionContext?
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]

    @State private var isProcessing = false
    @State private var isSaved = false

    private struct SharedContent {
        let type: NoteType
        let text: String?
        let url: URL?
        let title: String?
    }

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
            let content = await extractSharedContent()
            let note: Note
            if let content {
                note = Note(
                    type: content.type,
                    text: content.text,
                    url: content.url,
                    title: content.title
                )
            } else {
                note = Note(type: .text, text: "Shared item")
            }
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

    /// Extracts supported content from the share extension input items.
    private func extractSharedContent() async -> SharedContent? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return nil
        }

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    let result = try? await provider.loadItem(
                        forTypeIdentifier: UTType.plainText.identifier
                    )
                    if let text = result as? String, !text.isEmpty {
                        return SharedContent(type: .text, text: text, url: nil, title: nil)
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    let result = try? await provider.loadItem(
                        forTypeIdentifier: UTType.url.identifier
                    )
                    if let url = result as? URL {
                        let title = url.isFileURL ? url.lastPathComponent : (url.host() ?? "Link")
                        return SharedContent(type: .link, text: nil, url: url, title: title)
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    let result = try? await provider.loadItem(
                        forTypeIdentifier: UTType.image.identifier
                    )
                    if let imageURL = result as? URL {
                        return SharedContent(
                            type: .image,
                            text: nil,
                            url: nil,
                            title: imageURL.lastPathComponent
                        )
                    }
                    if let suggestedName = provider.suggestedName, !suggestedName.isEmpty {
                        return SharedContent(type: .image, text: nil, url: nil, title: suggestedName)
                    }
                    return SharedContent(type: .image, text: nil, url: nil, title: "Shared image")
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    let result = try? await provider.loadItem(
                        forTypeIdentifier: UTType.fileURL.identifier
                    )
                    if let fileURL = result as? URL {
                        return SharedContent(
                            type: .link,
                            text: nil,
                            url: fileURL,
                            title: fileURL.lastPathComponent
                        )
                    }
                    if let suggestedName = provider.suggestedName, !suggestedName.isEmpty {
                        return SharedContent(type: .link, text: nil, url: nil, title: suggestedName)
                    }
                }
            }
        }
        return nil
    }
}
