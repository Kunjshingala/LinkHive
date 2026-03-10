# Dependencies — LinkHive

> All packages use `any` version constraint in `pubspec.yaml`. Consider pinning to specific versions in production.

---

## Core Dependencies

| Package | Why It Exists |
|---|---|
| `firebase_core` | Required foundation for all Firebase packages |
| `firebase_auth` | User authentication (email/password, Google) |
| `google_sign_in` | Google OAuth flow; **must** call `initialize()` before `authenticate()` |
| `flutter_bloc` | BLoC state management — core architecture pattern |
| `equatable` | Makes event/state equality checks work correctly in Bloc |
| `get_it` | Service locator / DI container; all singletons registered in `locator.dart` |
| `go_router` | Declarative routing; all routes defined in `core/utils/navigation/route.dart` |
| `receive_sharing_intent` | Enables the app to be a share target on Android/iOS |
| `rxdart` | Reactive stream utilities (available for future stream composition) |
| `flutter_svg` | Renders SVG assets |
| `font_awesome_flutter` | Icon set (Font Awesome) |

---

## Dev Dependencies

| Package | Why It Exists |
|---|---|
| `flutter_lints` | Lint rules for Flutter/Dart best practices |
| `flutter_test` | Unit and widget testing framework |

---

## Assets

| Directory | Contents |
|---|---|
| `assets/rive/` | Rive animation files (`.riv`) for animated UI elements |

---

## Notes on Key Packages

### `google_sign_in`
The `GoogleSignIn.instance` pattern requires calling `_googleSignIn.initialize()` before `authenticate()`. This is handled in `AuthService._ensureInitialized()` with an idempotent guard flag.

### `receive_sharing_intent`
Requires Android `AndroidManifest.xml` and iOS `Info.plist` intent filter configuration. The service listens on two streams: foreground (getMediaStream) and cold-start (getInitialMedia). Both subscriptions are managed in `ReceiveSharedIntent` and cancelled on `dispose()`.

### `get_it`
Only `AuthService` and `ReceiveSharedIntent` are currently registered. When adding new services or repositories, register them in `core/utils/locator.dart` using `registerLazySingleton`.
