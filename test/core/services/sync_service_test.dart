import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:link_hive/core/services/sync_engine.dart';
import 'package:link_hive/core/services/sync_service.dart';
import 'package:link_hive/core/services/sync_status.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkRepository extends Mock implements LinkRepository {}

class MockUser extends Mock implements User {}

void main() {
  group('SyncService', () {
    late MockLinkRepository repository;
    late SyncEngine engine;
    late StreamController<InternetStatus> connectivity;
    late SyncService syncService;
    var signedIn = true;
    var hasInternet = true;

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    setUp(() {
      signedIn = true;
      hasInternet = true;
      repository = MockLinkRepository();
      when(
        () => repository.unsyncedSummary(),
      ).thenReturn(const UnsyncedSummary(changes: 2));
      when(() => repository.lastFailure).thenReturn(null);
      when(() => repository.lastPulledAt).thenReturn(null);
      when(() => repository.syncPendingLinks()).thenAnswer((_) async {});
      when(() => repository.pullFromCloud()).thenAnswer((_) async {});
      engine = SyncEngine(
        repository: repository,
        isAuthenticated: () => signedIn,
      );
      connectivity = StreamController<InternetStatus>.broadcast();
      syncService = SyncService(
        linkRepository: repository,
        syncEngine: engine,
        connectivityChanges: connectivity.stream,
        hasInternetAccess: () async => hasInternet,
        authChanges: const Stream<Never>.empty(),
        currentUser: () => signedIn ? MockUser() : null,
      );
    });

    tearDown(() async {
      syncService.dispose();
      await connectivity.close();
    });

    test('can be instantiated', () {
      expect(syncService, isNotNull);
    });

    test('dispose does not throw when called before startListening', () {
      expect(() => syncService.dispose(), returnsNormally);
    });

    test('tells the engine when the connection is lost and returns', () async {
      syncService.startListening();
      await pump();
      expect(engine.status, SyncStatus.idle);

      connectivity.add(InternetStatus.disconnected);
      await pump();
      expect(engine.status, SyncStatus.waitingForInternet);

      connectivity.add(InternetStatus.connected);
      await pump();
      expect(engine.status, SyncStatus.idle);
    });

    test('starts a sync when the connection returns', () async {
      syncService.startListening();
      await pump();
      clearInteractions(repository); // the pull started at launch

      connectivity.add(InternetStatus.connected);
      await pump();

      verify(() => repository.syncPendingLinks()).called(1);
    });

    test('learns at start that the phone is offline', () async {
      hasInternet = false;

      syncService.startListening();
      await pump();

      expect(engine.status, SyncStatus.waitingForInternet);
    });

    test(
      'keeps assuming the phone is online if the first check fails',
      () async {
        final failing = SyncService(
          linkRepository: repository,
          syncEngine: engine,
          connectivityChanges: connectivity.stream,
          hasInternetAccess: () async => throw Exception('no probe'),
          authChanges: const Stream<Never>.empty(),
          currentUser: () => signedIn ? MockUser() : null,
        );

        failing.startListening();
        await pump();

        expect(engine.status, SyncStatus.idle);
        await connectivity.close();
      },
    );

    test('a background sync that fails is handled, not thrown', () async {
      when(() => repository.syncPendingLinks()).thenThrow(Exception('boom'));
      final unhandled = <Object>[];

      await runZonedGuarded(() async {
        syncService.requestSyncInBackground();
        await pump();
        await pump();
      }, (error, stack) => unhandled.add(error));

      expect(unhandled, isEmpty);
      expect(engine.status, SyncStatus.failed);
    });
  });
}
