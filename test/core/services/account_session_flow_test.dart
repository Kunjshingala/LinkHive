import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/constants/hive_constants.dart';
import 'package:link_hive/core/models/conflict_record.dart';
import 'package:link_hive/core/models/sync_operation.dart';
import 'package:link_hive/core/models/sync_tombstone.dart';
import 'package:link_hive/core/services/account_session_service.dart';
import 'package:link_hive/core/services/cloud_sync_service.dart';
import 'package:link_hive/core/services/auth_service.dart';
import 'package:link_hive/core/services/sync_engine.dart';
import 'package:link_hive/core/utils/hive_helper.dart';
import 'package:link_hive/features/links/models/category_model.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_firebase_firestore_service.dart';

class MockAuthService extends Mock implements AuthService {}

/// Whole stories of accounts sharing one phone, and of one account syncing: the
/// real repository, the real sync engine and the real session service, with a
/// fake cloud.
void main() {
  const accountA = 'account-a';
  const accountB = 'account-b';

  late Directory hiveDirectory;
  late FakeFirebaseFirestoreService cloud;
  late LinkRepository repository;
  late SyncEngine engine;
  late AccountSessionService session;
  late MockAuthService auth;
  String? currentUid;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'linkhive-session-test-',
    );
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(LinkModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(SyncOperationAdapter());
    Hive.registerAdapter(SyncTombstoneAdapter());
    Hive.registerAdapter(ConflictRecordAdapter());
  });

  setUp(() async {
    await Hive.openBox(HiveConstants.settingsBox);
    await Hive.openBox<LinkModel>(HiveConstants.linksBox);
    await Hive.openBox<LinkModel>(HiveConstants.baseLinksBox);
    await Hive.openBox<LinkModel>(HiveConstants.conflictLinksBox);
    await Hive.openBox<CategoryModel>(HiveConstants.categoriesBox);
    await Hive.openBox<SyncOperation>(HiveConstants.syncOperationsBox);
    await Hive.openBox<SyncTombstone>(HiveConstants.syncTombstonesBox);
    await Hive.openBox<ConflictRecord>(HiveConstants.conflictRecordsBox);
    await Future.wait([
      Hive.box(HiveConstants.settingsBox).clear(),
      Hive.box<LinkModel>(HiveConstants.linksBox).clear(),
      Hive.box<LinkModel>(HiveConstants.baseLinksBox).clear(),
      Hive.box<LinkModel>(HiveConstants.conflictLinksBox).clear(),
      Hive.box<CategoryModel>(HiveConstants.categoriesBox).clear(),
      Hive.box<SyncOperation>(HiveConstants.syncOperationsBox).clear(),
      Hive.box<SyncTombstone>(HiveConstants.syncTombstonesBox).clear(),
      Hive.box<ConflictRecord>(HiveConstants.conflictRecordsBox).clear(),
    ]);

    currentUid = null;
    cloud = FakeFirebaseFirestoreService();
    repository = LinkRepository(hiveHelper: HiveHelper());
    final cloudSync = CloudSyncService(
      firebaseService: cloud,
      store: repository,
      uidProvider: () => currentUid,
    );
    engine = SyncEngine(
      cloudSync: cloudSync,
      repository: repository,
      isAuthenticated: () => currentUid != null,
    );
    auth = MockAuthService();
    when(() => auth.signOut()).thenAnswer((_) async => currentUid = null);
    session = AccountSessionService(
      authService: auth,
      sync: engine,
      store: repository,
      remote: cloudSync,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await Hive.close();
  });

  tearDownAll(() => hiveDirectory.delete(recursive: true));

  LinkModel link(String id) => LinkModel(
    id: id,
    url: 'https://example.com/$id',
    title: id,
    createdAt: 100,
  );

  List<String> localIds() =>
      repository.queryLinks(limit: 100).map((l) => l.id).toList()..sort();

  List<String> cloudIds(String uid) =>
      cloud.linksOf(uid).map((l) => l.id).toList()..sort();

  Future<void> signIn(String uid) async {
    currentUid = uid;
    await engine.requestSync(pull: true);
  }

  Future<SessionActionResult> signOut() =>
      session.signOut(confirmed: repository.unsyncedSummary());

  Object? setting(String key) => Hive.box(HiveConstants.settingsBox).get(key);

  test(
    'a second account sees only its own links, and neither cloud is touched',
    () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
      cloud.seedLink(accountA, link('a-2'), syncedAt: 2000);
      cloud.seedLink(accountB, link('b-1'), syncedAt: 1500);

      await signIn(accountA);
      expect(localIds(), ['a-1', 'a-2']);

      expect(await signOut(), SessionActionResult.completed);
      expect(localIds(), isEmpty);
      expect(setting(HiveConstants.ownerUidKey), isNull);
      expect(setting(HiveConstants.lastPulledAtKey), isNull);
      expect(repository.isWipePending, isFalse);

      await signIn(accountB);

      expect(localIds(), ['b-1']);
      expect(cloudIds(accountA), ['a-1', 'a-2']);
      expect(cloudIds(accountB), ['b-1']);
      expect(cloud.deletedLinkIdsOf(accountB), isEmpty);
    },
  );

  test(
    'links that reached the cloud come back when the same account signs in again',
    () async {
      await signIn(accountA);
      await repository.addLink(link('a-new'));
      await engine.requestSync(); // pushed

      await signOut();
      expect(localIds(), isEmpty);
      await signIn(accountA);

      expect(localIds(), ['a-new']);
    },
  );

  test(
    'signing out with unsynced work, once confirmed, loses only that work',
    () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
      await signIn(accountA);
      await repository.addLink(link('a-unsynced')); // never pushed

      final shown = repository.unsyncedSummary();
      expect(shown.changes, 1);
      expect(
        await session.signOut(confirmed: shown),
        SessionActionResult.completed,
      );

      await signIn(accountA);
      expect(localIds(), ['a-1']);
      expect(cloudIds(accountA), ['a-1']);
    },
  );

  test('a link saved after the sheet was shown stops the sign-out', () async {
    await signIn(accountA);
    final shown = repository.unsyncedSummary(); // nothing unsynced
    await repository.addLink(link('saved-meanwhile'));

    final result = await session.signOut(confirmed: shown);

    expect(result, SessionActionResult.needsReconfirmation);
    expect(currentUid, accountA);
    expect(localIds(), ['saved-meanwhile']);
    // Sync still works: nothing was left paused.
    await engine.requestSync();
    expect(cloudIds(accountA), ['saved-meanwhile']);
  });

  test('signing out anyway works while a push is stuck, and the late push '
      'writes nothing back', () async {
    await signIn(accountA);
    await repository.addLink(link('a-stuck'));
    final reached = Completer<void>();
    final gate = Completer<void>();
    cloud.onCall = (method, uid) async {
      if (method != 'saveLink') return;
      if (!reached.isCompleted) reached.complete();
      await gate.future;
    };

    final push = engine.requestSync();
    await reached.future;

    // The user does not wait: sign out anyway while the request hangs.
    expect(await signOut(), SessionActionResult.completed);
    gate.complete();
    await push;

    expect(localIds(), isEmpty);
    expect(repository.pendingSyncOperations, isEmpty);

    cloud.onCall = null;
    cloud.seedLink(accountB, link('b-1'), syncedAt: 1000);
    await signIn(accountB);
    expect(localIds(), ['b-1']);
  });

  test('sync runs are accepted again after a sign-out', () async {
    await signIn(accountA);
    await signOut();

    cloud.seedLink(accountB, link('b-1'), syncedAt: 1000);
    await signIn(accountB);

    expect(localIds(), ['b-1']);
  });

  test(
    'a wipe interrupted by the app being killed is finished at the next launch',
    () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
      await signIn(accountA);
      await repository.setWipePending(true); // the app died right after this

      await session.recoverInterruptedWipe();

      expect(localIds(), isEmpty);
      expect(repository.isWipePending, isFalse);
      expect(setting(HiveConstants.ownerUidKey), isNull);
    },
  );

  test(
    'without an interrupted wipe the launch recovery leaves the data alone',
    () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
      await signIn(accountA);

      await session.recoverInterruptedWipe();

      expect(localIds(), ['a-1']);
    },
  );

  test(
    'deleting the cloud data empties the account and the phone, and stays signed in',
    () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
      cloud.seedLink(accountB, link('b-1'), syncedAt: 1000);
      await signIn(accountA);

      final result = await session.deleteCloudData(
        confirmed: repository.unsyncedSummary(),
      );

      expect(result, SessionActionResult.completed);
      expect(currentUid, accountA);
      expect(localIds(), isEmpty);
      expect(cloudIds(accountA), isEmpty);
      expect(cloudIds(accountB), ['b-1']); // another account is untouched
      await engine.requestSync(pull: true);
      expect(localIds(), isEmpty); // nothing comes back: it is gone for good
    },
  );

  test(
    'a full resync brings back a cloud link the normal sync skipped',
    () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 5000);
      await signIn(accountA); // the cursor is now at 5000
      // A link whose server time is behind the cursor, for example one that
      // was written late by another device.
      cloud.seedLink(accountA, link('a-late'), syncedAt: 1000);

      await engine.requestSync(pull: true);
      expect(localIds(), ['a-1']);

      await engine.requestFullResync();
      expect(localIds(), ['a-1', 'a-late']);
    },
  );

  test('a full resync keeps what is only on this phone', () async {
    await signIn(accountA);
    await repository.addLink(link('a-unsynced'));

    await engine.requestFullResync();

    expect(localIds(), ['a-unsynced']);
    expect(cloudIds(accountA), ['a-unsynced']); // pushed first, then pulled
  });

  test(
    '"Delete local data" stays signed in and the next sync refills the phone',
    () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
      await signIn(accountA);

      final result = await session.wipeLocalData(
        confirmed: repository.unsyncedSummary(),
      );

      expect(result, SessionActionResult.completed);
      expect(currentUid, accountA);
      expect(localIds(), isEmpty);
      await engine.requestSync(pull: true);
      expect(localIds(), ['a-1']);
    },
  );
}
