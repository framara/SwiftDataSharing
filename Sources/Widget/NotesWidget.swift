//
//  NotesWidget.swift
//  NotesWidget
//
//  A simple widget that displays the most recent notes.
//  Reads from the shared container via WidgetDataManager (actor, read-only).
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Snapshot Model

/// Lightweight struct snapshot — widgets should never hold live @Model references.
struct NoteSnapshot: Identifiable {
    let id: UUID
    let text: String
    let folderName: String
    let createdAt: Date
}

// MARK: - Timeline Entry

struct NotesEntry: TimelineEntry {
    let date: Date
    let notes: [NoteSnapshot]
}

// MARK: - Timeline Provider

struct NotesProvider: TimelineProvider {
    typealias Entry = NotesEntry

    func placeholder(in context: Context) -> NotesEntry {
        NotesEntry(date: .now, notes: [
            NoteSnapshot(id: UUID(), text: "Sample note", folderName: "Inbox", createdAt: .now),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (NotesEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<NotesEntry>) -> Void) {
        Task { @Sendable in
            let notes = await fetchRecentNotes()
            let entry = NotesEntry(date: .now, notes: notes)
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }

    private func fetchRecentNotes() async -> [NoteSnapshot] {
        do {
            let container = try await WidgetDataManager.shared.getContainer()
            let context = ModelContext(container)

            var descriptor = FetchDescriptor<Note>(
                sortBy: [SortDescriptor(\Note.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 5

            let notes = try context.fetch(descriptor)
            return notes.map { note in
                NoteSnapshot(
                    id: note.id,
                    text: note.displayText,
                    folderName: note.folder?.name ?? "Unknown",
                    createdAt: note.createdAt
                )
            }
        } catch {
            print("[Widget] Failed to fetch: \(error)")
            return []
        }
    }
}

// MARK: - Widget View

struct NotesWidgetEntryView: View {
    var entry: NotesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Notes")
                .font(.headline)
                .foregroundStyle(.secondary)

            if entry.notes.isEmpty {
                Text("No notes yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(entry.notes.prefix(3)) { note in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.text)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(note.folderName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
    }
}

// MARK: - Widget Declaration

struct NotesWidget: Widget {
    let kind = "NotesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NotesProvider()) { entry in
            NotesWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recent Notes")
        .description("Shows your latest saved notes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
