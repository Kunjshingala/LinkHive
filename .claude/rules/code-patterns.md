# Code Patterns

> Real patterns extracted from the LinkHive codebase. Use these as canonical templates.

## BLoC Pattern

Every feature follows the sealed-class BLoC pattern. Template from `LinkBloc`:

### Event file (`*_event.dart`)
```dart
part of '<feature>_bloc.dart';

sealed class LinkEvent extends Equatable {
  const LinkEvent();
}

class LinkLoadRequested extends LinkEvent {
  const LinkLoadRequested();
  @override
  List<Object?> get props => [];
}

class LinkDeleteRequested extends LinkEvent {
  const LinkDeleteRequested({required this.linkId});
  final String linkId;
  @override
  List<Object?> get props => [linkId];
}
```

### State file (`*_state.dart`)
```dart
part of '<feature>_bloc.dart';

sealed class LinkState extends Equatable {
  const LinkState();
}

class LinkInitial extends LinkState {
  const LinkInitial();
  @override
  List<Object?> get props => [];
}

class LinkLoading extends LinkState {
  const LinkLoading();
  @override
  List<Object?> get props => [];
}

class LinksLoaded extends LinkState {
  const LinksLoaded({required this.links, ...});
  final List<LinkModel> links;
  // Use copyWith for immutable updates
  LinksLoaded copyWith({List<LinkModel>? links, ...}) => LinksLoaded(links: links ?? this.links, ...);
  @override
  List<Object?> get props => [links, ...];
}

class LinkError extends LinkState {
  const LinkError({required this.message});
  final String message;
  @override
  List<Object?> get props => [message];
}
```

### BLoC file (`*_bloc.dart`)
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
// ... other imports

part '<feature>_event.dart';
part '<feature>_state.dart';

class LinkBloc extends Bloc<LinkEvent, LinkState> {
  final LinkRepository _repository;

  LinkBloc({required LinkRepository repository})
      : _repository = repository,
        super(const LinkInitial()) {
    on<LinkLoadRequested>(_onLoadRequested);
    on<LinkDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(
    LinkLoadRequested event,
    Emitter<LinkState> emit,
  ) async {
    emit(const LinkLoading());
    try {
      final links = _repository.queryLinks();
      emit(LinksLoaded(links: links));
    } catch (e) {
      emit(LinkError(message: e.toString()));
    }
  }
}
```

## Screen Pattern

Outer widget creates `BlocProvider`. Inner `_Content` widget has all UI.

```dart
// outer: <feature>_screen.dart
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LinkBloc(repository: locator<LinkRepository>())
        ..add(const LinkLoadRequested()),
      child: const _HomeContent(),
    );
  }
}

// inner: _<feature>_content.dart (or private class in same file)
class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<LinkBloc, LinkState>(
        builder: (context, state) {
          return switch (state) {
            LinkInitial() || LinkLoading() => const CircularProgressIndicator(),
            LinksLoaded(:final links) => _buildList(context, links),
            LinkError(:final message) => Text(message),
          };
        },
      ),
    );
  }
}
```

Use `BlocListener` for side effects (navigation, snackbars):
```dart
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthSuccess) context.goNamed(MyRouteName.homeScreen);
    if (state is AuthError) showSnackBar(state.message);
  },
  child: ...,
)
```

## Neo-Brutalism UI Rules

```dart
// ❌ Never — raw values
color: Color(0xFF1E1E1E)
padding: EdgeInsets.all(16)
style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)

// ✅ Always — design tokens
color: AppColors.black
padding: EdgeInsets.all(AppSpacing.md)
style: AppTypography.bodyLarge
```

Hard offset shadows (not soft blur):
```dart
// ✅ Neo-Brutalist shadow
BoxDecoration(
  border: Border.all(color: AppColors.black, width: 2),
  boxShadow: [
    BoxShadow(
      color: AppColors.shadowMint,   // or shadowPeach, shadowSky, etc.
      offset: const Offset(4, 4),
      blurRadius: 0,                 // Always 0 — no blur
    ),
  ],
)
```

## Custom Widget Replacements

| Never use | Always use | File |
|---|---|---|
| `ElevatedButton` / `TextButton` | `NeoBrutalistButton` | `lib/sharedWidgets/custom_button.dart` |
| `TextFormField` directly | `CustomTextField` | `lib/sharedWidgets/custom_text_field.dart` |
| `showDialog` / `AlertDialog` | `showConfirmationBottomSheet` / `showOptionsBottomSheet` | `lib/sharedWidgets/` |
| `AppBar` directly | `CommonAppBar` | `lib/sharedWidgets/common_app_bar.dart` |

## Navigation Pattern

```dart
// ❌ Never
Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen()));
context.go('/home');

// ✅ Always
context.goNamed(MyRouteName.homeScreen);
context.pushNamed(MyRouteName.addLink, extra: urlString);
context.pop();
```

## Dependency Injection Pattern

Services are retrieved from `locator` — never instantiated in widgets or BLoCs:

```dart
// ❌ Never instantiate in a widget or Bloc
final authService = AuthService();

// ✅ In screen: inject via BlocProvider
BlocProvider(
  create: (_) => AuthBloc(authService: locator<AuthService>()),
  child: ...
)

// ✅ In Bloc: receive via constructor
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(const AuthInitial()) { ... }
}
```

Register new services in `lib/core/utils/locator.dart`:
```dart
locator.registerLazySingleton<MyService>(() => MyService());
```

## Logging & SnackBars

```dart
// Debug logging (never raw print())
printLog(tag: 'LinkBloc', msg: 'Loading links with filter: $category');

// User-facing notifications (never ScaffoldMessenger directly)
showSnackBar('Link deleted successfully');
```

Both utilities are in `lib/core/utils/utils.dart`.

## Error Handling in BLoCs

```dart
Future<void> _onLoadRequested(
  LinkLoadRequested event,
  Emitter<LinkState> emit,
) async {
  emit(const LinkLoading());   // Always emit Loading first
  try {
    final result = await _repository.someOperation();
    emit(LinksLoaded(links: result));
  } catch (e) {
    emit(LinkError(message: e.toString()));   // Always emit Error on failure
  }
}
```
