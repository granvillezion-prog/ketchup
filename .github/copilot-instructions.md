# Swift migration operating rules

You are migrating this Flutter app to a native iOS SwiftUI app for Xcode.

Non-negotiable rules:
- Never modify, delete, or overwrite original Flutter/Dart files unless explicitly asked.
- Create Swift equivalents in a separate mirrored structure under `ios-native/`.
- Preserve business logic naming where possible so file mapping stays traceable.
- Before converting any file, inspect all referenced local types, services, managers, and storage dependencies.
- Never claim a feature is working unless all referenced types, imports, and dependencies are wired consistently.
- Prefer compile-safe Swift over visually perfect Swift.
- Prefer SwiftUI for views and app structure unless UIKit is clearly required.
- Use ObservableObject, @Published, @StateObject, and @EnvironmentObject when appropriate for shared state.
- For async work, prefer modern Swift concurrency (`async/await`) when practical.
- Do not invent fake implementations for Firebase auth, Firestore, camera, contacts, AVFoundation, CallKit, push notifications, or video calling.
- If platform-specific implementation is missing, leave a clear TODO with the exact interface and required framework.
- Keep generated code modular and readable.
- Keep filenames and type names consistent with the original architecture when possible.

Migration order:
1. models
2. services
3. managers/state/storage
4. routing/app shell
5. auth flow
6. today screen logic
7. call screen/camera/video flow
8. profile/circle/friends flow
9. cleanup and polish

Output format after each migration task:
- Files created
- Files updated
- Dependencies inspected
- Unresolved dependencies
- Compile risks
- Exact next Xcode validation step

Hard constraints:
- Do not migrate the whole app in one pass.
- Do not silently skip dependencies.
- Do not replace a complex dependency with fake placeholder logic unless explicitly labeled as a stub/TODO.
- Do not move to the next layer while the current layer has unresolved structural errors.