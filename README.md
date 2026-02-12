# SwiftData + App Group Sharing

A minimal, working reference project showing how to **share a single SwiftData database between an iOS app, a Share Extension, and a Widget** using App Groups.

This is the pattern most Apple developers struggle with. There is no clean, end-to-end example in Apple's documentation. This repo is that example.

> Extracted from [ToMe](https://framara.net/projects/ToMe), an iOS app for saving and organizing content from anywhere.

https://github.com/user-attachments/assets/69198c9e-e8db-4633-885c-1797e4e02fa4

## The Problem

You have three targets that need to access the same data:

| Target | Access | Challenge |
|--------|--------|-----------|
| Main App | Read / Write | Owns the container and drives iCloud sync |
| Share Extension | Read / Write | Runs in a separate process, needs the same DB |
| Widget | **Read-only** | Runs on background threads, must not write or sync |

SwiftData stores the database in the app's private sandbox by default. Extensions and widgets **cannot access it**.

## The Solution

### 1. App Group Container

All three targets point at the same `.sqlite` file inside the shared App Group directory:

```swift
let groupURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.example.swiftdatasharing"
)!
let storeURL = groupURL.appendingPathComponent("AppData.sqlite")
```

### 2. Shared ModelConfiguration

```swift
let config = ModelConfiguration(
    schema: schema,
    url: storeURL,
    cloudKitDatabase: .none   // or .automatic for the main app
)
```

### 3. Two Container Managers

| Manager | Used By | Isolation | Why |
|---------|---------|-----------|-----|
| `SharedDataManager` | App + Share Extension | `@MainActor` singleton | Both run on the main thread |
| `WidgetDataManager` | Widget only | `actor` singleton | Widget runs on background threads |

### 4. Schema Migration Plan

All targets share the same `AppMigrationPlan` so the schema chain is consistent everywhere. This prevents the widget from crashing on an unrecognized schema version.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                   App Group Container                 │
│                                                       │
│       ┌──────────────────────────────────┐            │
│       │         AppData.sqlite           │            │
│       └──────────────────────────────────┘            │
│            ▲              ▲              ▲             │
│            │              │              │             │
│       Read/Write     Read/Write      Read-only        │
│            │              │              │             │
│     ┌──────────┐  ┌──────────────┐  ┌──────────┐     │
│     │ Main App │  │  Share Ext   │  │  Widget   │     │
│     └──────────┘  └──────────────┘  └──────────┘     │
│            │              │              │             │
│    SharedDataManager  SharedDataManager  WidgetData   │
│     (@MainActor)      (@MainActor)      Manager      │
│                                         (actor)       │
└──────────────────────────────────────────────────────┘
```

## Project Structure

```
Sources/
├── Shared/                        ← All three targets
│   ├── Models/
│   │   ├── Folder.swift           # @Model — container for notes
│   │   ├── Note.swift             # @Model — a saved piece of content
│   │   ├── NoteType.swift         # Enum: text, link, image
│   │   └── SchemaVersions.swift   # Versioned schemas + migration plan
│   └── Services/
│       └── SharedDataManager.swift # Singleton container + widget reload
│
├── App/                           ← Main app only
│   ├── SwiftDataSharingApp.swift  # Entry point + seed data
│   ├── ContentView.swift          # Folder list
│   └── FolderDetailView.swift     # Notes list + add
│
├── ShareExtension/                ← Share Extension only
│   ├── ShareViewController.swift  # UIHostingController wrapper
│   └── ShareView.swift            # Folder picker + content extraction
│
└── Widget/                        ← Widget only
    ├── WidgetDataManager.swift    # Actor-based read-only container
    ├── NotesWidget.swift          # Timeline provider + widget view
    └── NotesWidgetBundle.swift    # Widget bundle entry point
```

## Quick Start

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` from `project.yml`. This avoids `.pbxproj` merge conflicts and makes the multi-target setup reproducible.

```bash
# 1. Install XcodeGen (if you don't have it)
brew install xcodegen

# 2. Set your Development Team (required for extensions)
#    Open project.yml and set DEVELOPMENT_TEAM to your team ID

# 3. Generate the Xcode project
xcodegen generate

# 4. Open and run
open SwiftDataSharing.xcodeproj
```

### Why is the Development Team required?

Extensions (Share Extension, Widget) must be properly code-signed for the OS to register them. Without a valid `DEVELOPMENT_TEAM`:

- `pluginkit` won't discover the Share Extension
- The extension **won't appear** in the share sheet
- This applies even on the Simulator

Set your team ID in `project.yml` at `settings.base.DEVELOPMENT_TEAM`. You can find it in Xcode under **Signing & Capabilities**, or in your [Apple Developer account](https://developer.apple.com/account).

### Customizing for your app

1. Set `DEVELOPMENT_TEAM` in `project.yml`
2. Update the App Group ID in `AppConstants.appGroupID` (`SharedDataManager.swift`) and in all three entitlements entries in `project.yml`
3. Regenerate: `xcodegen generate`

## Key Patterns

### Writing data (App + Share Extension)

```swift
let context = ModelContext(SharedDataManager.shared.container)
let note = Note(type: .text, text: "Hello")
note.folder = someFolder
context.insert(note)
try context.save()
SharedDataManager.shared.reloadWidgets()  // Always reload after save
```

### Reading data (Widget)

```swift
// Widget uses an actor — safe for background threads
let container = try await WidgetDataManager.shared.getContainer()
let context = ModelContext(container)
let notes = try context.fetch(FetchDescriptor<Note>())
```

### Share Extension activation

The Share Extension uses a proper `NSExtensionActivationRule` dictionary (not `TRUEPREDICATE`) to declare supported content types:

```xml
NSExtensionActivationSupportsText = YES
NSExtensionActivationSupportsWebURLWithMaxCount = 1
NSExtensionActivationSupportsWebPageWithMaxCount = 1
NSExtensionActivationSupportsImageWithMaxCount = 10
NSExtensionActivationSupportsFileWithMaxCount = 10
```

> `TRUEPREDICATE` is a development shortcut that Apple rejects on App Store submission. It may also cause the extension to not appear on newer iOS versions.

## Schema Migrations

When you need to add a field after your first release:

```swift
// 1. Add the optional field to the model
@Model final class Note {
    // ... existing fields ...
    var subtitle: String? = nil  // NEW — optional + default = lightweight migration
}

// 2. Create a new schema version
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)
    static var models: [any PersistentModel.Type] { [Folder.self, Note.self] }
}

// 3. Add to the migration plan (never remove old versions)
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }
    static var stages: [MigrationStage] { [] }  // Additive optionals = automatic
}

// 4. Update SharedDataManager and WidgetDataManager to reference SchemaV2
```

For **breaking changes** (renaming fields, changing types), add a `MigrationStage.custom` block. See the template in `SchemaVersions.swift`.

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Share Extension not in share sheet | Set a valid `DEVELOPMENT_TEAM` and use a proper activation rule dictionary (not `TRUEPREDICATE`) |
| Widget shows stale data | Call `WidgetCenter.shared.reloadAllTimelines()` after every save |
| Share Extension can't find DB | Both targets must have the same App Group in entitlements |
| Widget crashes on background thread | Use an `actor` (`WidgetDataManager`), not `@MainActor` |
| Migration fails silently | Include ALL schema versions in `AppMigrationPlan.schemas` |
| iCloud conflicts in widget | Set `cloudKitDatabase: .none` in the widget — only the main app should sync |
| Swift 6 actor isolation error | Shared constants (like App Group ID) must live outside `@MainActor` classes — use a plain `enum` namespace |
| App renders in small window | Include `UILaunchScreen` in the app's Info.plist (set via `INFOPLIST_KEY_UILaunchScreen_Generation: YES`) |

## Adding iCloud Sync

To enable CloudKit sync for the main app:

```swift
// In SharedDataManager, change:
cloudKitDatabase: .none
// to:
cloudKitDatabase: .automatic
```

The Share Extension can also use `.automatic` if it writes data that should sync. The Widget should **always** use `.none`.

## Requirements

- iOS 17.0+
- Xcode 16+
- Swift 6
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Credits

Extracted from [ToMe](https://framara.net/projects/ToMe) by [framara](https://framara.net).

## License

MIT
