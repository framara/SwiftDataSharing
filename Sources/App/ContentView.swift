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
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(folders) { folder in
                        NavigationLink(destination: FolderDetailView(folder: folder)) {
                            FolderRow(folder: folder)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
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
}

// MARK: - Folder Row

private struct FolderRow: View {
    let folder: Folder

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: folder.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color(hex: folder.colorHex))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(noteCountLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var noteCountLabel: String {
        let count = folder.notes?.count ?? 0
        return count == 1 ? "1 note" : "\(count) notes"
    }
}

// MARK: - Color Hex

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
