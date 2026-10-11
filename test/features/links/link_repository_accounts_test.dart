import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/constants/hive_constants.dart';
import 'package:link_hive/core/models/conflict_record.dart';
import 'package:link_hive/core/models/sync_operation.dart';
import 'package:link_hive/core/models/sync_tombstone.dart';
import 'package:link_hive/core/utils/hive_helper.dart';
import 'package:link_hive/features/links/models/category_model.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';

import '../../helpers/fake_firebase_firestore_service.dart';

/// Two accounts using one phone, with a real Hive store and a fake cloud.
///
/// See `.ai/context/sync-contract.md` for the rules these tests protect.
void main() {
  const accountA = 'account-a';
  const accountB = 'account-b';

  late Directory hiveDirectory;
  late FakeFirebaseFirestoreService cloud;
  late LinkRepository repository;
  String? currentUid;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'linkhive-accounts-test-',
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
    repository = LinkRepository(
      firebaseService: cloud,
      hiveHelper: HiveHelper(),
      uidProvider: () => currentUid,
    );
  });

  tearDown(() => Hive.close());
  tearDownAll(() => hiveDirectory.delete(recursive: true));

  LinkModel link(String id, {int createdAt = 100}) => LinkModel(
    id: id,
    url: 'https://example.com/$id',
    title: id,
    createdAt: createdAt,
  );

  List<String> localIds() =>
      (repository.queryLinks(limit: 100).map((l) => l.id).toList()..sort());

  test('guest links merge into the first account that syncs', () async {
    cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
    await repository.addLink(link('guest-1'));
    await repository.addLink(link('guest-2'));

    currentUid = accountA;
    await repository.syncPendingLinks();
    await repository.pullFromCloud();

    expect(localIds(), ['a-1', 'guest-1', 'guest-2']);
    expect(cloud.linksOf(accountA).map((l) => l.id).toSet(), {
      'a-1',
      'guest-1',
      'guest-2',
    });
  });

  test(
    'switching accounts without a wipe still shows the new account\'s older links (#7)',
    () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
      cloud.seedLink(accountB, link('b-1'), syncedAt: 1000);
      cloud.seedLink(accountB, link('b-2'), syncedAt: 2000);

      currentUid = accountA;
      await repository.pullFromCloud(); // the cursor is now "just now"
      currentUid = accountB; // sign-out cleared nothing
      await repository.pullFromCloud();

      expect(localIds(), ['b-1', 'b-2']);
    },
  );

  test(
    'another account\'s queued delete is not pushed into the new account (#8)',
    () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);

      currentUid = accountA;
      await repository.pullFromCloud();
      currentUid = null; // signed out, nothing wiped
      await repository.deleteLink('a-1'); // queues a delete operation
      currentUid = accountB;
      await repository.syncPendingLinks();

      expect(cloud.deletedLinkIdsOf(accountB), isEmpty);
      expect(cloud.linksOf(accountA).map((l) => l.id), ['a-1']);
    },
  );

  group('a wipe while a sync is waiting on the cloud', () {
    /// Holds the first call to [method] open until `release` is called.
    ({Future<void> reached, void Function() release}) holdCall(String method) {
      final reached = Completer<void>();
      final gate = Completer<void>();
      cloud.onCall = (called, uid) async {
        if (called != method) return;
        if (!reached.isCompleted) reached.complete();
        await gate.future;
      };
      return (reached: reached.future, release: gate.complete);
    }

    Object? setting(String key) => Hive.box(HiveConstants.settingsBox).get(key);

    test('a late push does not write the wiped link back', () async {
      currentUid = accountA;
      await repository.addLink(link('a-1'));
      final hold = holdCall('saveLink');

      final push = repository.syncPendingLinks();
      await hold.reached;
      await repository.clearLocalData();
      hold.release();
      await push;

      expect(localIds(), isEmpty);
      expect(repository.pendingSyncOperations, isEmpty);
    });

    test('a late pull does not write the wiped links or owner back', () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
      currentUid = accountA;
      final hold = holdCall('fetchLinks');

      final pull = repository.pullFromCloud();
      await hold.reached;
      await repository.clearLocalData();
      hold.release();
      await pull;

      expect(localIds(), isEmpty);
      expect(setting(HiveConstants.lastPulledAtKey), isNull);
      expect(setting(HiveConstants.ownerUidKey), isNull);
    });

    test('a late pull does not rewrite the cursor after the wipe', () async {
      cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
      currentUid = accountA;
      final hold = holdCall('fetchCategories');

      final pull = repository.pullFromCloud(); // links are already written here
      await hold.reached;
      await repository.clearLocalData();
      hold.release();
      await pull;

      expect(localIds(), isEmpty);
      expect(setting(HiveConstants.lastPulledAtKey), isNull);
    });
  });

  group('owner check', () {
    Object? setting(String key) => Hive.box(HiveConstants.settingsBox).get(key);

    test(
      'an install from before owners were recorded resets a stale cursor once',
      () async {
        cloud.seedLink(accountA, link('a-1'), syncedAt: 1000);
        await Hive.box(HiveConstants.settingsBox).put(
          HiveConstants.lastPulledAtKey,
          DateTime.now().toUtc().millisecondsSinceEpoch,
        );

        currentUid = accountA;
        await repository.pullFromCloud();

        expect(localIds(), ['a-1']);
        expect(setting(HiveConstants.ownerUidKey), accountA);
      },
    );

    test('the same account keeps using the incremental pull', () async {
      final calls = <String>[];
      cloud.onCall = (method, uid) async => calls.add(method);

      currentUid = accountA;
      await repository.pullFromCloud();
      calls.clear();
      await repository.pullFromCloud();

      expect(calls, contains('fetchLinksSince'));
      expect(calls, isNot(contains('fetchLinks')));
    });

    test(
      'a different owner is wiped: links, queue and cursor go, the new uid owns the phone',
      () async {
        currentUid = accountA;
        await repository.addLink(link('a-local'));
        await repository.pullFromCloud();
        expect(repository.pendingSyncOperations, isNotEmpty);

        currentUid = accountB;
        await repository.pullFromCloud();

        expect(localIds(), isEmpty);
        expect(repository.pendingSyncOperations, isEmpty);
        expect(setting(HiveConstants.ownerUidKey), accountB);
      },
    );
  });
}
