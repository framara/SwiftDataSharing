# SwiftData + App Group Sharing

A minimal reference project showing how to **share a single SwiftData database between an iOS app, a Share Extension, and a Widget** using App Groups.

This is the pattern most Apple developers struggle with and there is no clean, end-to-end example. This repo is that example.

## The Problem

You have three targets that need to access the same data:

| Target | Access | Challenge |
|--------|--------|-----------|
| Main App | Read / Write | Owns the container and drives iCloud sync |
| Share Extension | Read / Write | Runs in a separate process, needs the same DB |
| Widget | **Read-only** | Runs on background threads, must not write or sync |

SwiftData defaults to storing the database in the app's private sandbox, which extensions and widgets cannot access.

## The Solution

### 1. App Group Container

All three targets point at the same `.sqlite` file inside the shared App Group directory:

```swift
let groupURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.example.swiftdatasharing"
)!
let storeURL = groupURL.appendingPathComponent("AppData.sqlite")
```

### 2. Shared `ModelConfiguration`

```swift
let config = ModelConfiguration(
    schema: schema,
    url: storeURL,
    cloudKitDatabase: .none // or .automatic for the main app
)
```

### 3. Two Entry Points

| Entry Point | Used By | Thread Safety |
|-------------|---------|---------------|
| `SharedDataManager` (`@MainActor`, singleton) | App + Share Extension | MainActor-isolated |
| `WidgetDataManager` (`actor`, singleton) | Widget only | Actor-isolated for background |

### 4. Schema Migration Plan

All targets use the same `AppMigrationPlan` so the schema chain is consistent everywhere. This prevents the widget from seeing an unrecognized schema version and failing silently.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  App Group Container             │
│                                                  │
│    ┌──────────────────────────────────────┐      │
│    │          AppData.sqlite              │      │
│    └──────────────────────────────────────┘      │
│         ▲              ▲              ▲           │
│         │              │              │           │
│    Read/Write     Read/Write      Read-only      │
│         │              │              │           │
│  ┌──────────┐  ┌──────────────┐  ┌─────────┐    │
│  │ Main App │  │   Share Ext  │  │  Widget  │    │
│  └──────────┘  └──────────────┘  └─────────┘    │
│         │              │              │           │
│  SharedDataManager  SharedDataManager  WidgetData│
│  (@MainActor)       (@MainActor)     Manager     │
│                                      (actor)     │
└─────────────────────────────────────────────────┘
```

## Key Files

```
Sources/
├── Shared/                    # Added to ALL three targets
│   ├── Models/
│   │   ├── Folder.swift       # @Model - container for notes
│   │   ├── Note.swift         # @Model - a saved piece of content
│   │   ├── NoteType.swift     # Enum: text, link, image
│   │   └── SchemaVersions.swift # Versioned schemas + migration plan
│   └── Services/
│       └── SharedDataManager.swift  # Singleton container (App + Extension)
├── App/                       # Main app target only
│   ├── SwiftDataSharingApp.swift
│   ├── ContentView.swift
│   └── FolderDetailView.swift
├── ShareExtension/            # Share Extension target only
│   ├── ShareViewController.swift
│   └── ShareView.swift
└── Widget/                    # Widget target only
    ├── WidgetDataManager.swift  # Actor-based read-only container
    ├── NotesWidget.swift
    └── NotesWidgetBundle.swift
```

## Quick Start

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` from `project.yml`. This avoids messy pbxproj merge conflicts and makes the multi-target setup reproducible.

```bash
# 1. Install XcodeGen (if you don't have it)
brew install xcodegen

# 2. Generate the Xcode project
xcodegen generate

# 3. Open and run
open SwiftDataSharing.xcodeproj
```

### Configure for your team

1. Open the project in Xcode and set your **Development Team** on all 3 targets
2. Update the App Group identifier in `AppConstants.appGroupID` (in `SharedDataManager.swift`) and in `project.yml` to match your team's provisioning
3. Regenerate: `xcodegen generate`

### Target Membership

XcodeGen handles this automatically via `project.yml`. For reference:

| File | App | Share Ext | Widget |
|------|-----|-----------|--------|
| `Shared/Models/*` | Yes | Yes | Yes |
| `Shared/Services/SharedDataManager.swift` | Yes | Yes | Yes |
| `App/*` | Yes | - | - |
| `ShareExtension/*` | - | Yes | - |
| `Widget/WidgetDataManager.swift` | - | - | Yes |
| `Widget/NotesWidget.swift` | - | - | Yes |
| `Widget/NotesWidgetBundle.swift` | - | - | Yes |

## Schema Migrations

When you need to add a field after your first release:

```swift
// 1. Add the optional field to the live model
@Model final class Note {
    // ... existing fields ...
    var subtitle: String? = nil  // NEW
}

// 2. Create a new schema version
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)
    static var models: [any PersistentModel.Type] { [Folder.self, Note.self] }
}

// 3. Add V2 to the migration plan (keep V1!)
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]  // NEVER remove old versions
    }
    static var stages: [MigrationStage] { [] }  // Additive optionals = automatic
}

// 4. Update SharedDataManager and WidgetDataManager to use SchemaV2
```

For **breaking changes** (renaming fields, changing types), see the template in `SchemaVersions.swift`.

## Requirements

- iOS 17.0+
- Xcode 16+
- Swift 6
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Widget shows stale data | Call `WidgetCenter.shared.reloadAllTimelines()` after every save |
| Share extension can't find DB | Ensure both targets have the same App Group enabled |
| Widget crashes on background thread | Use an `actor` (WidgetDataManager), not `@MainActor` |
| Migration fails silently | Include ALL schema versions in `AppMigrationPlan.schemas` |
| iCloud conflicts in widget | Set `cloudKitDatabase: .none` in the widget — only the main app syncs |
| Swift 6 actor isolation error | Shared constants (like App Group ID) must live outside `@MainActor` classes — use a plain `enum` namespace |

## Adding iCloud Sync

To enable CloudKit sync for the main app:

```swift
// In SharedDataManager.createContainer():
let config = ModelConfiguration(
    schema: schema,
    url: storeURL,
    cloudKitDatabase: .automatic  // Enable iCloud sync
)
```

The Share Extension can also use `.automatic` if it writes data that should sync. The Widget should always use `.none`.

## Credits

Extracted from [ToMe](https://horchatastudio.com/app/tome), an iOS app for saving and organizing content.

## License

MIT
