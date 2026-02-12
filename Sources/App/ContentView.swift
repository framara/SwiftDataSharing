//
//  ContentView.swift
//  SwiftDataSharing
//
//  Displays all folders and allows creating new ones.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]
    @State private var showingAddFolder = false
    @State private var newFolderName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(folders) { folder in
                    NavigationLink(destination: FolderDetailView(folder: folder)) {
                        Label(folder.name, systemImage: folder.icon)
                    }
                }
                .onDelete(perform: deleteFolders)
            }
            .navigationTitle("Folders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddFolder = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Folder", isPresented: $showingAddFolder) {
                TextField("Name", text: $newFolderName)
                Button("Add") { addFolder() }
                Button("Cancel", role: .cancel) { newFolderName = "" }
            }
            .overlay {
                if folders.isEmpty {
                    ContentUnavailableView(
                        "No Folders",
                        systemImage: "folder",
                        description: Text("Tap + to create your first folder.")
                    )
                }
            }
        }
    }

    private func addFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let folder = Folder(name: newFolderName, sortOrder: folders.count)
        modelContext.insert(folder)
        try? modelContext.save()
        SharedDataManager.shared.reloadWidgets()
        newFolderName = ""
    }

    private func deleteFolders(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(folders[index])
        }
        try? modelContext.save()
        SharedDataManager.shared.reloadWidgets()
    }
}
