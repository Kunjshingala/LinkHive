import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/account_session_service.dart';
import 'package:link_hive/core/services/auth_service.dart';
import 'package:link_hive/core/services/cloud_sync_service.dart';
import 'package:link_hive/core/services/sync_control.dart';
import 'package:link_hive/core/services/sync_status.dart';
import 'package:link_hive/features/links/repository/local_data_store.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

class MockSyncControl extends Mock implements SyncControl {}

class MockLocalDataStore extends Mock implements LocalDataStore {}

class MockRemoteDataStore extends Mock implements RemoteDataStore {}

void main() {
  late MockAuthService auth;
  late MockSyncControl sync;
  late MockLocalDataStore store;
  late MockRemoteDataStore remote;
  late AccountSessionService session;
  late UnsyncedSummary current;

  setUp(() {
    auth = MockAuthService();
    sync = MockSyncControl();
    store = MockLocalDataStore();
    remote = MockRemoteDataStore();
    current = const UnsyncedSummary();
    when(() => store.unsyncedSummary()).thenAnswer((_) => current);
    when(() => store.isWipePending).thenReturn(false);
    when(() => store.setWipePending(any())).thenAnswer((_) async {});
    when(() => store.clearLocalData()).thenAnswer((_) async {});
    when(() => remote.clearRemoteData()).thenAnswer((_) async {});
    when(() => auth.signOut()).thenAnswer((_) async {});
    session = AccountSessionService(authService: auth, sync: sync, store: store, remote: remote);
  });

  group('signOut', () {
    test('pauses sync, marks the wipe, wipes, signs out, clears the marker and '
        'resumes, in that order', () async {
      final result = await session.signOut(confirmed: current);

      expect(result, SessionActionResult.completed);
      verifyInOrder([
        () => sync.pause(),
        () => store.setWipePending(true),
        () => store.clearLocalData(),
        () => auth.signOut(),
        () => store.setWipePending(false),
        () => sync.resume(),
      ]);
      verifyNever(() => remote.clearRemoteData());
    });

    test('deletes the cloud data after the marker and before the wipe', () async {
      await session.signOut(confirmed: current, clearRemote: true);

      verifyInOrder([
        () => store.setWipePending(true),
        () => remote.clearRemoteData(),
        () => store.clearLocalData(),
        () => auth.signOut(),
      ]);
    });

    test('changes nothing when there is more unsynced work than the user saw', () async {
      current = const UnsyncedSummary(changes: 3);

      final result = await session.signOut(confirmed: const UnsyncedSummary(changes: 2));

      expect(result, SessionActionResult.needsReconfirmation);
      verifyNever(() => sync.pause());
      verifyNever(() => store.setWipePending(any()));
      verifyNever(() => store.clearLocalData());
      verifyNever(() => auth.signOut());
    });

    test('a new conflict also needs reconfirmation', () async {
      current = const UnsyncedSummary(conflicts: 1);

      final result = await session.signOut(confirmed: const UnsyncedSummary());

      expect(result, SessionActionResult.needsReconfirmation);
    });

    test('proceeds when there is the same or less unsynced work than the user saw', () async {
      current = const UnsyncedSummary(changes: 1);

      final result = await session.signOut(confirmed: const UnsyncedSummary(changes: 2));

      expect(result, SessionActionResult.completed);
    });

    test('keeps sync paused until the wipe has finished', () async {
      final wipe = Completer<void>();
      when(() => store.clearLocalData()).thenAnswer((_) => wipe.future);

      final signOut = session.signOut(confirmed: current);
      await Future<void>.delayed(Duration.zero);

      verify(() => sync.pause()).called(1);
      verifyNever(() => sync.resume());

      wipe.complete();
      await signOut;
      verify(() => sync.resume()).called(1);
    });

    test('a failed wipe leaves the marker set, does not sign out, and resumes sync', () async {
      when(() => store.clearLocalData()).thenThrow(StateError('disk full'));

      await expectLater(session.signOut(confirmed: current), throwsA(isA<StateError>()));

      verifyNever(() => auth.signOut());
      verifyNever(() => store.setWipePending(false));
      verify(() => sync.resume()).called(1);
    });

    test('a failed sign-out after the wipe leaves the marker set and resumes sync', () async {
      when(() => auth.signOut()).thenThrow(StateError('auth down'));

      await expectLater(session.signOut(confirmed: current), throwsA(isA<StateError>()));

      verify(() => store.clearLocalData()).called(1);
      verifyNever(() => store.setWipePending(false));
      verify(() => sync.resume()).called(1);
    });
  });

  group('wipeLocalData', () {
    test('wipes and stays signed in', () async {
      final result = await session.wipeLocalData(confirmed: current);

      expect(result, SessionActionResult.completed);
      verifyInOrder([
        () => sync.pause(),
        () => store.setWipePending(true),
        () => store.clearLocalData(),
        () => store.setWipePending(false),
        () => sync.resume(),
      ]);
      verifyNever(() => auth.signOut());
    });

    test('needs reconfirmation when more unsynced work appeared', () async {
      current = const UnsyncedSummary(changes: 1);

      final result = await session.wipeLocalData(confirmed: const UnsyncedSummary());

      expect(result, SessionActionResult.needsReconfirmation);
      verifyNever(() => store.clearLocalData());
    });
  });

  group('deleteCloudData', () {
    test('deletes the cloud data and the phone\'s copy, and stays signed in', () async {
      final result = await session.deleteCloudData(confirmed: current);

      expect(result, SessionActionResult.completed);
      verifyInOrder([
        () => sync.pause(),
        () => store.setWipePending(true),
        () => remote.clearRemoteData(),
        () => store.clearLocalData(),
        () => store.setWipePending(false),
        () => sync.resume(),
      ]);
      verifyNever(() => auth.signOut());
    });

    test('changes nothing when more unsynced work appeared', () async {
      current = const UnsyncedSummary(changes: 1);

      final result = await session.deleteCloudData(confirmed: const UnsyncedSummary());

      expect(result, SessionActionResult.needsReconfirmation);
      verifyNever(() => remote.clearRemoteData());
      verifyNever(() => store.clearLocalData());
    });

    test('does not touch the phone when the cloud delete fails', () async {
      when(() => remote.clearRemoteData()).thenThrow(StateError('offline'));

      await expectLater(session.deleteCloudData(confirmed: current), throwsA(isA<StateError>()));

      verifyNever(() => store.clearLocalData());
      verify(() => sync.resume()).called(1);
    });
  });

  group('recoverInterruptedWipe', () {
    test('finishes a wipe that was interrupted', () async {
      when(() => store.isWipePending).thenReturn(true);

      await session.recoverInterruptedWipe();

      verifyInOrder([() => store.clearLocalData(), () => store.setWipePending(false)]);
    });

    test('does nothing when no wipe was interrupted', () async {
      await session.recoverInterruptedWipe();

      verifyNever(() => store.clearLocalData());
      verifyNever(() => store.setWipePending(any()));
    });
  });

  group('requestSync', () {
    test('asks the engine for a sync', () async {
      when(() => sync.requestSync()).thenAnswer((_) async {});

      await session.requestSync();

      verify(() => sync.requestSync()).called(1);
    });

    test('a failed sync is shown through the status, not thrown', () async {
      when(() => sync.requestSync()).thenThrow(StateError('offline'));

      await expectLater(session.requestSync(), completes);
    });
  });
}
