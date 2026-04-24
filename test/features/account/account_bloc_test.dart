import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/auth_service.dart';
import 'package:link_hive/features/account/bloc/account_bloc.dart';
import 'package:link_hive/features/account/bloc/account_event.dart';
import 'package:link_hive/features/account/bloc/account_state.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/firebase_mock.dart';

class MockAuthService extends Mock implements AuthService {}

class MockLinkRepository extends Mock implements LinkRepository {}

void main() {
  group('AccountBloc', () {
    late MockAuthService mockAuthService;
    late MockLinkRepository mockRepository;

    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    setUp(() {
      mockAuthService = MockAuthService();
      mockRepository = MockLinkRepository();
      // Stub getLinkStats — called by the auto-dispatched AccountLoadRequested
      when(() => mockRepository.getLinkStats()).thenReturn((5, 2, 3));
    });

    // The constructor auto-dispatches AccountLoadRequested which reads
    // FirebaseAuth.instance.currentUser. In the test environment this
    // returns null, so the bloc emits AccountGuest.

    group('AccountLoadRequested', () {
      blocTest<AccountBloc, AccountState>(
        'emits AccountGuest with stats for unauthenticated user',
        build: () => AccountBloc(
          authService: mockAuthService,
          linkRepository: mockRepository,
        ),
        // Constructor auto-dispatches load, which emits AccountGuest
        // because FirebaseAuth.instance.currentUser is null in tests.
        expect: () => [
          const AccountGuest(totalLinks: 5, syncedLinks: 0, unsyncedLinks: 5),
        ],
      );
    });

    group('AccountSignOutRequested', () {
      blocTest<AccountBloc, AccountState>(
        'emits [AccountLoading, AccountSignedOut] on successful sign out',
        build: () {
          when(() => mockAuthService.signOut()).thenAnswer((_) async {});
          return AccountBloc(
            authService: mockAuthService,
            linkRepository: mockRepository,
          );
        },
        skip: 1, // Skip auto-load AccountGuest
        act: (bloc) => bloc.add(const AccountSignOutRequested()),
        expect: () => [const AccountLoading(), const AccountSignedOut()],
        verify: (_) {
          verify(() => mockAuthService.signOut()).called(1);
          verifyNever(() => mockRepository.clearLocalData());
          verifyNever(() => mockRepository.clearRemoteData());
        },
      );

      blocTest<AccountBloc, AccountState>(
        'clears local data when clearLocal is true',
        build: () {
          when(() => mockAuthService.signOut()).thenAnswer((_) async {});
          when(() => mockRepository.clearLocalData())
              .thenAnswer((_) async {});
          return AccountBloc(
            authService: mockAuthService,
            linkRepository: mockRepository,
          );
        },
        skip: 1,
        act: (bloc) =>
            bloc.add(const AccountSignOutRequested(clearLocal: true)),
        expect: () => [const AccountLoading(), const AccountSignedOut()],
        verify: (_) {
          verify(() => mockRepository.clearLocalData()).called(1);
          verifyNever(() => mockRepository.clearRemoteData());
        },
      );

      blocTest<AccountBloc, AccountState>(
        'clears remote data when clearRemote is true',
        build: () {
          when(() => mockAuthService.signOut()).thenAnswer((_) async {});
          when(() => mockRepository.clearRemoteData())
              .thenAnswer((_) async {});
          return AccountBloc(
            authService: mockAuthService,
            linkRepository: mockRepository,
          );
        },
        skip: 1,
        act: (bloc) =>
            bloc.add(const AccountSignOutRequested(clearRemote: true)),
        expect: () => [const AccountLoading(), const AccountSignedOut()],
        verify: (_) {
          verify(() => mockRepository.clearRemoteData()).called(1);
          verifyNever(() => mockRepository.clearLocalData());
        },
      );

      blocTest<AccountBloc, AccountState>(
        'emits [AccountLoading, AccountError] when sign out fails',
        build: () {
          when(() => mockAuthService.signOut())
              .thenThrow(Exception('Sign out failed'));
          return AccountBloc(
            authService: mockAuthService,
            linkRepository: mockRepository,
          );
        },
        skip: 1,
        act: (bloc) => bloc.add(const AccountSignOutRequested()),
        expect: () => [const AccountLoading(), isA<AccountError>()],
      );
    });

    group('AccountGoogleSignInRequested', () {
      blocTest<AccountBloc, AccountState>(
        'emits [AccountLoading, AccountError] when Google sign-in fails',
        build: () {
          when(() => mockAuthService.signInWithGoogle())
              .thenThrow(Exception('Google sign-in cancelled'));
          return AccountBloc(
            authService: mockAuthService,
            linkRepository: mockRepository,
          );
        },
        skip: 1,
        act: (bloc) => bloc.add(const AccountGoogleSignInRequested()),
        expect: () => [const AccountLoading(), isA<AccountError>()],
      );

      blocTest<AccountBloc, AccountState>(
        'emits AccountGuest after successful sign-in when currentUser is still null',
        build: () {
          when(() => mockAuthService.signInWithGoogle())
              .thenAnswer((_) async => null);
          return AccountBloc(
            authService: mockAuthService,
            linkRepository: mockRepository,
          );
        },
        skip: 1,
        act: (bloc) => bloc.add(const AccountGoogleSignInRequested()),
        expect: () => [
          const AccountLoading(),
          const AccountGuest(totalLinks: 5, syncedLinks: 0, unsyncedLinks: 5),
        ],
      );
    });
  });
}
