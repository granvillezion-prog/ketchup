Generate only one file:
ios-native/App/KetchUpApp.swift

Rules:
- Make it the native SwiftUI @main app entry
- Import SwiftUI and FirebaseCore
- Call FirebaseApp.configure() exactly once at app launch
- Present AuthenticatedRootView() as the root view
- Do not create any other files
- Do not add extra navigation or auth UI
- Keep it minimal and compile-safe

Before writing code, show:
1. the exact app structure
2. where FirebaseApp.configure() will run
3. any blocker that would prevent this file from compiling