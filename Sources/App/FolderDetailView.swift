//
//  FolderDetailView.swift
//  SwiftDataSharing
//
//  Shows notes inside a folder and allows adding new ones.
//

import SwiftUI
import SwiftData

struct FolderDetailView: View {
    let folder: Folder
    @Environment(\.modelContext) private var modelContext
    @State private var newNoteText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Notes list
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(folder.sortedNotes) { note in
                        NoteCard(note: note, folderColor: folder.colorHex, onDelete: {
                            deleteNote(note)
                        })
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .background(Color(.systemGroupedBackground))
            .overlay {
                if folder.sortedNotes.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "note.text",
                        description: Text("Add a note below or share content from another app.")
                    )
                }
            }

            // Input bar
            HStack(spacing: 10) {
                TextField("Add a note...", text: $newNoteText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                    .focused($isInputFocused)
                    .submitLabel(.done)
                    .onSubmit { addNote() }

                Button(action: addNote) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSave ? Color(hex: folder.colorHex) : Color(.tertiaryLabel))
                }
                .disabled(!canSave)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var canSave: Bool {
        !newNoteText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func addNote() {
        let text = newNoteText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let note = Note(type: .text, text: text)
        note.folder = folder
        modelContext.insert(note)
        try? modelContext.save()
        SharedDataManager.shared.reloadWidgets()
        newNoteText = ""
    }

    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
        try? modelContext.save()
        SharedDataManager.shared.reloadWidgets()
    }
}

// MARK: - Note Card

private struct NoteCard: View {
    let note: Note
    let folderColor: String
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: noteIcon)
                .font(.subheadline)
                .foregroundStyle(Color(hex: folderColor))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.displayText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(note.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var noteIcon: String {
        switch note.type {
        case .text: "note.text"
        case .link: "link"
        case .image: "photo"
        }
    }
}
