# Code Style & Conventions — LinkHive

## Language & Formatting

- **Dart** — follow official Dart style guide
- Use `dart format` (via FVM) before committing: `fvm dart format lib/`
- Max line length: 100 characters (matches `analysis_options.yaml`)
- Use `const` constructors wherever possible (linter enforces this)

---

## File & Directory Naming

- Files: `snake_case.dart`
- Directories: `snake_case/`
- Do NOT use `camelCase` or `PascalCase` for filenames

---

## Class Naming

| Component | Convention | Example |
|---|---|---|
| Screen widget | `PascalCase + Screen` | `HomeScreen`, `LoginScreen` |
| Bloc | `PascalCase + Bloc` | `AuthBloc`, `SplashBloc` |
| Event | `PascalCase + (action verb)` | `AuthSignInRequested`, `SplashStarted` |
| State | `PascalCase + (state noun)` | `AuthLoading`, `AuthSuccess`, `AuthError` |
| Service | `PascalCase + Service` | `AuthService` |
| Repository (future) | `PascalCase + Repository` | `LinkRepository` |
| Widget file (shared) | descriptive + type | `common_app_bar.dart`, `custom_button.dart` |

---

## Bloc Pattern Rules

Every feature follows this structure:
```
features/
  my_feature/
    bloc/
      my_feature_bloc.dart   # Event handlers in constructor via on<Event>()
      my_feature_event.dart  # Abstract base + concrete events, extend Equatable
      my_feature_state.dart  # Abstract base + concrete states, extend Equatable
    my_screen.dart           # Outer widget creates BlocProvider
    _my_screen_content.dart  # (or private inner class) — uses BlocBuilder/Listener
```

- Outer screen widget **only** wraps content in `BlocProvider`
- Inner content widget is `StatelessWidget` — keep business logic in Bloc
- States extend `Equatable` and override `props`
- Events extend `Equatable` and override `props` when they carry data
- Use `const` for events/states that carry no data

---

## Widget Patterns

- Prefer `StatelessWidget` + Bloc over `StatefulWidget` + local state
- Use `BlocListener` for side effects (navigation, snackbars)
- Use `BlocBuilder` for UI rebuilds
- Use `BlocConsumer` when both are needed in the same widget
- Navigation: always use `context.goNamed()` or `context.pushNamed()` with `MyRouteName` constants
- Pickers/Pop-ups: ALWAYS use `showModalBottomSheet()` rather than `showDialog()` or `AlertDialog`.

---

## UI Implementations

- **Tokens Only:** NEVER use hardcoded colors (`Colors.white`, `Color(0xFF...)`) or spacing (`EdgeInsets.all(16)`).
- **Colors:** Always use `AppColors.*` from `lib/core/theme/app_colors.dart`.
- **Spacing:** Always use `AppSpacing.*` from `lib/core/theme/app_spacing.dart`.
- **Typography:** Always use `AppTypography.*` from `lib/core/theme/app_typography.dart`.
- **Theme:** Rely on the global `Theme.of(context)` provided by `buildLinkHiveTheme()` for standard component styling when possible.

---

## Imports

Order imports in this sequence (enforced by linter):
1. Dart SDK (`dart:`)
2. Flutter SDK (`package:flutter/`)
3. External packages (alphabetical)
4. Local project imports (relative paths)

---

## Comments

- Use `///` doc comments on public classes, methods, and non-obvious fields
- Use `//` for inline logic explanations
- Do NOT comment out dead code — delete it

---

## Error Handling

- Blocs: always wrap async operations in `try/catch`, emit `ErrorState` on failure
- Services: throw descriptive error strings (not raw exceptions)
- AuthService pattern: catch `FirebaseAuthException`, map to user-friendly messages
