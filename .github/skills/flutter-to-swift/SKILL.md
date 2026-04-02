---
name: flutter-to-swift
description: Migrate Flutter/Dart files to SwiftUI in controlled batches with dependency tracing and Xcode validation.
---

When invoked for a migration task:

1. Read the requested Dart file and all directly referenced local files first.
2. Build a dependency map before writing Swift.
3. Identify:
   - models
   - services
   - managers/state
   - routing dependencies
   - storage dependencies
   - platform frameworks required
4. Create or update Swift files only inside `ios-native/`.
5. Keep architecture traceable to the original Flutter app.
6. If a dependency is missing:
   - migrate it first, or
   - stub it clearly with TODO comments and exact expected interface requirements.
7. Never migrate more than one architecture layer at a time unless explicitly requested.
8. For views:
   - keep UI logic separated from service logic
   - avoid embedding business logic directly in SwiftUI view bodies
9. End every task with:
   - files created
   - dependency map
   - unresolved dependencies
   - compile risks
   - next 1 to 3 files that should be migrated