# NEVER DO — LinkHive Hard Rules

These are non-negotiable. Breaking any of these rules is a hard stop.

---

## State Management

- ❌ **NEVER** use `setState` for business logic — use Bloc
- ❌ **NEVER** call `setState` outside a `StatefulWidget` lifecycle method
- ❌ **NEVER** bypass the Bloc layer to mutate data directly from a widget
- ❌ **NEVER** create a `StatefulWidget` when a `StatelessWidget` + Bloc suffices
- ❌ **NEVER** expose a Bloc's internal stream directly — use `BlocBuilder`/`BlocListener`

---

## UI & Styling (Neo-Brutalism)

- ❌ **NEVER** use hardcoded colors (`Color(0xFF...)` or `Colors.xxx`) inside UI widgets. Always use `AppColors`.
- ❌ **NEVER** use hardcoded spacing values/EdgeInsets. Always use `AppSpacing`.
- ❌ **NEVER** use soft, blurry Material drop shadows (`BoxShadow` with high blur radius). Always use hard offset borders/shadows (blur 0).
- ❌ **NEVER** use thin or invisible borders on active cards. Always use thick (2px) black borders (`AppColors.border`).
- ❌ **NEVER** use `AlertDialog` or `showDialog` for pop-ups. Always use `showModalBottomSheet` to adhere to the design system.

---

## Authentication & Security

- ❌ **NEVER** hardcode credentials, API keys, or Firebase config values in source code
- ❌ **NEVER** commit `google-services.json` or `GoogleService-Info.plist` to the repo (they should be gitignored)
- ❌ **NEVER** skip authentication checks — always go through `AuthGate`
- ❌ **NEVER** trust `snapshot.data` from Firebase without null checking

---

## Architecture

- ❌ **NEVER** import from one feature into another feature (e.g., `features/auth/` into `features/home/`) — go through `core/` or shared widgets
- ❌ **NEVER** put business logic inside screen widgets or `sharedWidgets/`
- ❌ **NEVER** instantiate services directly in widgets — always use `locator<T>()`
- ❌ **NEVER** add new routes by raw string paths — use `MyRouteName` constants and `GoRoute` definitions in `route.dart`

---

## Navigation

- ❌ **NEVER** use `Navigator.push/pop` or `Navigator.of(context).push/pop` directly — use `go_router` via `context.go()`, `context.push()`, `context.goNamed()`, `context.pushNamed()`, or `context.pop()`.
- ❌ **NEVER** hardcode route paths as strings in widgets

---

## Codebase Health

- ❌ **NEVER** commit code with lint warnings — run `fvm flutter analyze` first
- ❌ **NEVER** leave `TODO` or `FIXME` comments without a linked issue
- ❌ **NEVER** delete or modify `firebase_options.dart` manually — regenerate with `flutterfire configure`
- ❌ **NEVER** run `flutter` directly if FVM is set up — always prefix with `fvm`
