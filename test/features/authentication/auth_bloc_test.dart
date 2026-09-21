import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/auth_service.dart';
import 'package:link_hive/features/authentication/bloc/auth_bloc.dart';
import 'package:link_hive/features/authentication/bloc/auth_event.dart';
import 'package:link_hive/features/authentication/bloc/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

class MockUserCredential extends Mock implements UserCredential {}

void main() {
  group('AuthBloc', () {
    late MockAuthService mockAuthService;
    late AuthBloc authBloc;

    setUp(() {
      mockAuthService = MockAuthService();
      authBloc = AuthBloc(authService: mockAuthService);
    });

    tearDown(() {
      authBloc.close();
    });

    test('initial state is AuthInitial', () {
      expect(authBloc.state, const AuthInitial());
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthSuccess] when signInWithEmailPassword succeeds',
      build: () {
        when(
          () => mockAuthService.signInWithEmailPassword(
            'test@test.com',
            'password',
          ),
        ).thenAnswer((_) async => null); // mock the implicit dynamic return
        return authBloc;
      },
      act: (bloc) => bloc.add(
        const AuthSignInRequested(email: 'test@test.com', password: 'password'),
      ),
      expect: () => [const AuthLoading(), const AuthSuccess()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when signInWithEmailPassword fails',
      build: () {
        when(
          () => mockAuthService.signInWithEmailPassword(
            'test@test.com',
            'password',
          ),
        ).thenThrow(Exception('Auth Failed'));
        return authBloc;
      },
      act: (bloc) => bloc.add(
        const AuthSignInRequested(email: 'test@test.com', password: 'password'),
      ),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthSuccess] when signInWithGoogle returns a credential',
      build: () {
        when(
          () => mockAuthService.signInWithGoogle(),
        ).thenAnswer((_) async => MockUserCredential());
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), const AuthSuccess()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthInitial] and no error when the user cancels Google sign-in',
      build: () {
        // AuthService returns null for a user-dismissed Google sheet.
        when(
          () => mockAuthService.signInWithGoogle(),
        ).thenAnswer((_) async => null);
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), const AuthInitial()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when Google sign-in genuinely fails',
      build: () {
        when(
          () => mockAuthService.signInWithGoogle(),
        ).thenThrow(Exception('Google Failed'));
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthInitial] when signOut succeeds',
      build: () {
        when(() => mockAuthService.signOut()).thenAnswer((_) async {});
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthSignOutRequested()),
      expect: () => [const AuthLoading(), const AuthInitial()],
    );
  });
}
