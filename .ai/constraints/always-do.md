# ALWAYS DO — LinkHive Non-Negotiables

---

## State Management

- ✅ **ALWAYS** use `flutter_bloc` for state management — every screen has a Bloc
- ✅ **ALWAYS** emit an initial state from Blocs (constructor `super(initialState)`)
- ✅ **ALWAYS** emit `LoadingState` before any async operation in a Bloc
- ✅ **ALWAYS** emit `ErrorState` with a message when async operations fail
- ✅ **ALWAYS** extend `Equatable` for all events and states, and override `props`

---

## Architecture

- ✅ **ALWAYS** register services as lazy singletons in `core/utils/locator.dart`
- ✅ **ALWAYS** inject services into Blocs via constructor parameter (not `locator` inside Bloc)
- ✅ **ALWAYS** use `MyRouteName` constants for all navigation calls
- ✅ **ALWAYS** split each screen into: outer `BlocProvider` widget + inner `_Content` widget

---

## UI & Styling (Neo-Brutalism)

- ✅ **ALWAYS** use `AppColors` for all color definitions. Never use raw `Color()` or `Colors.xxx`.
- ✅ **ALWAYS** use `AppSpacing` for all padding, margins, gaps, and border radii.
- ✅ **ALWAYS** use hard offset shadows (e.g., `BoxShadow` with `blurRadius: 0`, `offset: Offset(4, 4)`) for the Neo-Brutalism UI Pattern.
- ✅ **ALWAYS** use thick high-contrast borders (usually 2px, `AppColors.border`) on cards, chips, and active elements.
- ✅ **ALWAYS** use `showModalBottomSheet` (specifically the custom Neo-Brutalist ones) for pop-ups and options.

---

## Code Quality

- ✅ **ALWAYS** run `fvm flutter analyze` before committing — zero warnings, zero errors
- ✅ **ALWAYS** use `const` constructors on widgets and events/states that carry no data
- ✅ **ALWAYS** use `printLog(tag: 'Tag', msg: 'message')` for debug logging (not raw `print`)
- ✅ **ALWAYS** use `showSnackBar(message)` from `core/utils/utils.dart` for user-facing notifications

---

## Firebase

- ✅ **ALWAYS** call `Firebase.initializeApp()` before any Firebase usage (handled in `main.dart`)
- ✅ **ALWAYS** check `snapshot.connectionState == ConnectionState.waiting` in `StreamBuilder` on auth state

---

## Flutter Version

- ✅ **ALWAYS** use FVM-managed Flutter: prefix every Flutter/Dart command with `fvm`
  - `fvm flutter run`, `fvm flutter build`, `fvm dart format`, `fvm flutter analyze`
