import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/auth_service.dart';
import 'package:link_hive/features/authentication/bloc/auth_bloc.dart';
import 'package:link_hive/features/authentication/bloc/auth_event.dart';
import 'package:link_hive/features/authentication/bloc/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

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
          () => mockAuthService.signInWithEmailPassword('test@test.com', 'password'),
        ).thenAnswer((_) async => null); // mock the implicit dynamic return
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthSignInRequested(email: 'test@test.com', password: 'password')),
      expect: () => [const AuthLoading(), const AuthSuccess()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when signInWithEmailPassword fails',
      build: () {
        when(
          () => mockAuthService.signInWithEmailPassword('test@test.com', 'password'),
        ).thenThrow(Exception('Auth Failed'));
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthSignInRequested(email: 'test@test.com', password: 'password')),
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
