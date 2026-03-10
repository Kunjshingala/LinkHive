# Testing Conventions — LinkHive

## Philosophy

- Test Blocs, not widgets (widget tests are secondary)
- Test business logic paths: success, loading, error
- Use `bloc_test` package for Bloc unit tests (add it to `dev_dependencies` when writing tests)

---

## Test Structure

```
test/
  features/
    authentication/
      auth_bloc_test.dart
    home/
      home_bloc_test.dart
    splash/
      splash_bloc_test.dart
  core/
    services/
      auth_service_test.dart
```

Mirror the `lib/` feature structure inside `test/`.

---

## Bloc Test Pattern

```dart
blocTest<AuthBloc, AuthState>(
  'emits [AuthLoading, AuthSuccess] on valid sign in',
  build: () => AuthBloc(authService: mockAuthService),
  act: (bloc) => bloc.add(AuthSignInRequested(email: 'a@b.com', password: '123')),
  expect: () => [const AuthLoading(), const AuthSuccess()],
);
```

- Mock services with `mockito` or `mocktail`
- Test every event handler with: happy path + error path
- Assert state sequence — order matters in Bloc

---

## What NOT to Test

- `main.dart` setup
- Pure layout widgets (CommonAppBar, CustomButton) — keep these dumb
- Firebase SDK internals — mock the `AuthService` boundary instead

---

## Running Tests

```bash
fvm flutter test
fvm flutter test test/features/authentication/auth_bloc_test.dart
```
