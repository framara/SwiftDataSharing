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

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Add a note...", text: $newNoteText)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") { addNote() }
                        .disabled(newNoteText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Notes") {
                ForEach(folder.sortedNotes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.displayText)
                            .font(.body)
                        Text(note.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: deleteNotes)
            }
        }
        .navigationTitle(folder.name)
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

    private func deleteNotes(at offsets: IndexSet) {
        let sorted = folder.sortedNotes
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        try? modelContext.save()
        SharedDataManager.shared.reloadWidgets()
    }
}
