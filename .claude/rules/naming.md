# Naming Conventions

## Files & Directories

| Type | Convention | Examples |
|---|---|---|
| Dart files | `snake_case.dart` | `link_model.dart`, `add_link_bloc.dart` |
| Directories | `snake_case/` | `features/links/`, `shared_widgets/` |
| ARB files | `app_<locale>.arb` | `app_en.arb`, `app_ar.arb` |

Never use `camelCase` or `PascalCase` for file or directory names.

## Classes

| Component | Suffix | Examples |
|---|---|---|
| Screen widget | `Screen` | `HomeScreen`, `LoginScreen`, `AddLinkScreen` |
| BLoC | `Bloc` | `LinkBloc`, `AuthBloc`, `AddLinkBloc` |
| Cubit | `Cubit` | `ThemeCubit`, `LocaleCubit` |
| Event (base) | `Event` | `LinkEvent`, `AuthEvent` |
| Event (concrete) | `<Subject><Verb>` | `LinkLoadRequested`, `AuthSignInRequested`, `LinkDeleteRequested` |
| State (base) | `State` | `LinkState`, `AuthState` |
| State (concrete) | `<Subject><Adjective>` | `LinkInitial`, `LinkLoading`, `LinksLoaded`, `LinkError` |
| Service | `Service` | `AuthService`, `SyncService`, `LinkMetadataService` |
| Repository | `Repository` | `LinkRepository` |
| Model | `Model` | `LinkModel`, `CategoryModel` |
| Constants class | `Constants` | `HiveConstants`, `FirebaseConstants` |

## Methods

| Role | Pattern | Examples |
|---|---|---|
| BLoC event handler | `_on<EventName>` | `_onLoadRequested`, `_onSearchChanged`, `_onDeleteRequested` |
| Repository write | `add<X>` / `update<X>` / `delete<X>` | `addLink`, `updateLink`, `deleteLink` |
| Repository read | `query<X>` / `get<X>` / `fetch<X>` | `queryLinks`, `getLinkStats`, `fetchCategories` |
| Repository stream | `watch<X>` | `watchLinksBox` |
| Service method | descriptive verb | `signInWithEmailPassword`, `fetchMetadata`, `syncPendingLinks` |

## Routes

Always use `MyRouteName` constants from `lib/core/utils/navigation/route.dart`:

```dart
// ❌ Never
context.go('/home');
context.pushNamed('addLink');

// ✅ Always
context.goNamed(MyRouteName.homeScreen);
context.pushNamed(MyRouteName.addLink, extra: url);
```

When adding a new route, add the constant to `MyRouteName` AND the `GoRoute` to the `router` in the same file.

## Storage Keys

Always define keys as constants — never use raw strings:

```dart
// ❌ Never
box.get('theme_mode');

// ✅ Always
box.get(HiveConstants.themeKey);
```

Hive box names → `HiveConstants` (`lib/core/constants/hive_constants.dart`)
Firestore fields → `FirebaseConstants` (`lib/core/constants/firebase_constants.dart`)

## Feature Directory Structure

New features follow this exact layout:

```
lib/features/<feature_name>/
  <feature_name>_screen.dart     # Outer widget: BlocProvider only
  _<feature_name>_content.dart   # Inner widget: all UI + BlocBuilder/Listener
  bloc/
    <feature_name>_bloc.dart
    <feature_name>_event.dart
    <feature_name>_state.dart
```

Example for a `tags` feature:
```
lib/features/tags/
  tags_screen.dart
  _tags_content.dart
  bloc/
    tags_bloc.dart
    tags_event.dart
    tags_state.dart
```
