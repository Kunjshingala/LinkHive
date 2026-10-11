import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/account_session_service.dart';
import 'package:link_hive/core/services/auth_service.dart';
import 'package:link_hive/core/services/sync_status.dart';
import 'package:link_hive/features/account/bloc/account_bloc.dart';
import 'package:link_hive/features/account/bloc/account_event.dart';
import 'package:link_hive/features/account/bloc/account_state.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/firebase_mock.dart';

class MockAuthService extends Mock implements AuthService {}

class MockLinkRepository extends Mock implements LinkRepository {}

class MockAccountSessionService extends Mock implements AccountSessionService {}

void main() {
  group('AccountBloc', () {
    late MockAuthService mockAuthService;
    late MockLinkRepository mockRepository;
    late MockAccountSessionService mockSession;

    AccountBloc buildBloc() => AccountBloc(
      authService: mockAuthService,
      linkRepository: mockRepository,
      sessionService: mockSession,
    );

    setUpAll(() async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    });

    setUp(() {
      mockAuthService = MockAuthService();
      mockRepository = MockLinkRepository();
      mockSession = MockAccountSessionService();
      // Stub getLinkStats — called by the auto-dispatched AccountLoadRequested
      when(() => mockRepository.getLinkStats()).thenReturn((5, 2, 3));
    });

    // The constructor auto-dispatches AccountLoadRequested which reads
    // FirebaseAuth.instance.currentUser. In the test environment this
    // returns null, so the bloc emits AccountGuest.
    const guest = AccountGuest(totalLinks: 5, syncedLinks: 0, unsyncedLinks: 5);

    group('AccountLoadRequested', () {
      blocTest<AccountBloc, AccountState>(
        'emits AccountGuest with stats for unauthenticated user',
        build: buildBloc,
        // Constructor auto-dispatches load, which emits AccountGuest
        // because FirebaseAuth.instance.currentUser is null in tests.
        expect: () => [guest],
      );
    });

    group('AccountSignOutRequested', () {
      const shown = UnsyncedSummary(changes: 2);

      blocTest<AccountBloc, AccountState>(
        'signs out through the session service, then shows the account again',
        build: () {
          when(
            () => mockSession.signOut(confirmed: shown),
          ).thenAnswer((_) async => SessionActionResult.completed);
          return buildBloc();
        },
        skip: 1, // Skip auto-load AccountGuest
        act: (bloc) =>
            bloc.add(const AccountSignOutRequested(confirmed: shown)),
        expect: () => [
          const AccountLoading(),
          const AccountSignedOut(),
          guest,
        ],
        verify: (_) {
          verify(() => mockSession.signOut(confirmed: shown)).called(1);
          verifyNever(() => mockAuthService.signOut());
        },
      );

      blocTest<AccountBloc, AccountState>(
        'asks the user to confirm again when more unsynced work appeared',
        build: () {
          when(
            () => mockSession.signOut(confirmed: shown),
          ).thenAnswer((_) async => SessionActionResult.needsReconfirmation);
          return buildBloc();
        },
        skip: 1,
        act: (bloc) =>
            bloc.add(const AccountSignOutRequested(confirmed: shown)),
        expect: () => [
          const AccountLoading(),
          const AccountNeedsReconfirmation(),
          guest,
        ],
      );

      blocTest<AccountBloc, AccountState>(
        'reports a failed sign-out instead of saying it worked',
        build: () {
          when(
            () => mockSession.signOut(confirmed: shown),
          ).thenThrow(Exception('Sign out failed'));
          return buildBloc();
        },
        skip: 1,
        act: (bloc) =>
            bloc.add(const AccountSignOutRequested(confirmed: shown)),
        expect: () => [
          const AccountLoading(),
          const AccountActionFailed(AccountAction.signOut),
          guest,
        ],
      );
    });


    group('AccountWipeLocalRequested', () {
      const shown = UnsyncedSummary(changes: 2);

      blocTest<AccountBloc, AccountState>(
        'wipes through the session service, then shows the account again',
        build: () {
          when(
            () => mockSession.wipeLocalData(confirmed: shown),
          ).thenAnswer((_) async => SessionActionResult.completed);
          return buildBloc();
        },
        skip: 1,
        act: (bloc) =>
            bloc.add(const AccountWipeLocalRequested(confirmed: shown)),
        expect: () => [
          const AccountLoading(),
          const AccountLocalWiped(),
          guest,
        ],
        verify: (_) {
          verify(() => mockSession.wipeLocalData(confirmed: shown)).called(1);
        },
      );

      blocTest<AccountBloc, AccountState>(
        'asks the user to confirm again when more unsynced work appeared',
        build: () {
          when(
            () => mockSession.wipeLocalData(confirmed: shown),
          ).thenAnswer((_) async => SessionActionResult.needsReconfirmation);
          return buildBloc();
        },
        skip: 1,
        act: (bloc) =>
            bloc.add(const AccountWipeLocalRequested(confirmed: shown)),
        expect: () => [
          const AccountLoading(),
          const AccountNeedsReconfirmation(),
          guest,
        ],
      );

      blocTest<AccountBloc, AccountState>(
        'reports a failed wipe and shows the account again',
        build: () {
          when(
            () => mockSession.wipeLocalData(confirmed: shown),
          ).thenThrow(StateError('disk full'));
          return buildBloc();
        },
        skip: 1,
        act: (bloc) =>
            bloc.add(const AccountWipeLocalRequested(confirmed: shown)),
        expect: () => [
          const AccountLoading(),
          const AccountActionFailed(AccountAction.wipeLocal),
          guest,
        ],
      );
    });

    group('AccountDeleteCloudDataRequested', () {
      const shown = UnsyncedSummary();

      blocTest<AccountBloc, AccountState>(
        'deletes the cloud data through the session service',
        build: () {
          when(
            () => mockSession.deleteCloudData(confirmed: shown),
          ).thenAnswer((_) async => SessionActionResult.completed);
          return buildBloc();
        },
        skip: 1,
        act: (bloc) =>
            bloc.add(const AccountDeleteCloudDataRequested(confirmed: shown)),
        expect: () => [
          const AccountLoading(),
          const AccountCloudDeleted(),
          guest,
        ],
      );

      blocTest<AccountBloc, AccountState>(
        'reports a failed delete',
        build: () {
          when(
            () => mockSession.deleteCloudData(confirmed: shown),
          ).thenThrow(StateError('offline'));
          return buildBloc();
        },
        skip: 1,
        act: (bloc) =>
            bloc.add(const AccountDeleteCloudDataRequested(confirmed: shown)),
        expect: () => [
          const AccountLoading(),
          const AccountActionFailed(AccountAction.deleteCloud),
          guest,
        ],
      );
    });

    group('AccountGoogleSignInRequested', () {
      blocTest<AccountBloc, AccountState>(
        'emits [AccountLoading, AccountError] when Google sign-in fails',
        build: () {
          when(
            () => mockAuthService.signInWithGoogle(),
          ).thenThrow(Exception('Google sign-in cancelled'));
          return buildBloc();
        },
        skip: 1,
        act: (bloc) => bloc.add(const AccountGoogleSignInRequested()),
        expect: () => [const AccountLoading(), isA<AccountError>()],
      );

      blocTest<AccountBloc, AccountState>(
        'emits AccountGuest after successful sign-in when currentUser is still null',
        build: () {
          when(
            () => mockAuthService.signInWithGoogle(),
          ).thenAnswer((_) async => null);
          return buildBloc();
        },
        skip: 1,
        act: (bloc) => bloc.add(const AccountGoogleSignInRequested()),
        expect: () => [const AccountLoading(), guest],
      );
    });
  });
}
