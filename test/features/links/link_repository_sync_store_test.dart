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
import 'package:link_hive/features/links/repository/local_data_store.dart';

/// The wipe guard of [SyncStore]: once the phone is wiped, a sync run can no
/// longer write anything locally (sync contract invariant 5).
void main() {
  late Directory hiveDirectory;
  late LinkRepository repository;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'linkhive-sync-store-test-',
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
    repository = LinkRepository(hiveHelper: HiveHelper());
  });

  tearDown(() => Hive.close());
  tearDownAll(() => hiveDirectory.delete(recursive: true));

  const link = LinkModel(
    id: 'l-1',
    url: 'https://example.com/l-1',
    title: 'l-1',
    createdAt: 100,
  );
  final operation = SyncOperation(
    operationId: 'op-1',
    entityType: SyncOperation.linkEntity,
    entityId: 'l-1',
    operationType: SyncOperation.create,
    payload: link.toSyncPayload(),
    createdAt: 1,
    nextAttemptAt: 1,
  );

  /// Every sync-state box and setting is empty, as right after a wipe.
  void expectNothingStored() {
    expect(Hive.box<LinkModel>(HiveConstants.linksBox).isEmpty, isTrue);
    expect(Hive.box<LinkModel>(HiveConstants.baseLinksBox).isEmpty, isTrue);
    expect(
      Hive.box<LinkModel>(HiveConstants.conflictLinksBox).isEmpty,
      isTrue,
    );
    expect(
      Hive.box<CategoryModel>(HiveConstants.categoriesBox).isEmpty,
      isTrue,
    );
    expect(
      Hive.box<SyncOperation>(HiveConstants.syncOperationsBox).isEmpty,
      isTrue,
    );
    expect(
      Hive.box<ConflictRecord>(HiveConstants.conflictRecordsBox).isEmpty,
      isTrue,
    );
    final settings = Hive.box(HiveConstants.settingsBox);
    expect(settings.get(HiveConstants.lastPulledAtKey), isNull);
    expect(settings.get(HiveConstants.ownerUidKey), isNull);
  }

  group('a run that began before a wipe writes nothing', () {
    final writes = <String, Future<bool> Function(SyncRunToken run)>{
      'putOperation': (run) => repository.putOperation(run, operation),
      'finishPushed': (run) => repository.finishPushed(run, operation),
      'putCloudLink': (run) => repository.putCloudLink(run, link),
      'applyMerge': (run) =>
          repository.applyMerge(run, link.copyWith(isSynced: false), link),
      'removeLink': (run) => repository.removeLink(run, 'l-1'),
      'removeBaseLink': (run) => repository.removeBaseLink(run, 'l-1'),
      'saveConflict': (run) => repository.saveConflict(
        run,
        linkId: 'l-1',
        base: link,
        local: link,
        cloud: null,
        fields: const ['delete'],
      ),
      'putCategory': (run) =>
          repository.putCategory(run, CategoryModel(id: 'c-1', name: 'Work')),
      'removeCategory': (run) => repository.removeCategory(run, 'c-1'),
      'resetPullCursor': (run) => repository.resetPullCursor(run),
      'writePullCursor': (run) => repository.writePullCursor(run, 42),
    };

    for (final entry in writes.entries) {
      test(entry.key, () async {
        final run = (await repository.beginRun('user-1'))!;
        await repository.clearLocalData();

        expect(await entry.value(run), isFalse);
        expectNothingStored();
      });
    }
  });

  group('a wipe between the writes of one call', () {
    test('applyMerge stops before the base and the queue', () async {
      final run = (await repository.beginRun('user-1'))!;

      // The first write starts synchronously; the wipe lands right after it.
      final merge = repository.applyMerge(
        run,
        link.copyWith(title: 'merged', isSynced: false),
        link,
      );
      await repository.clearLocalData();

      expect(await merge, isFalse);
      expectNothingStored();
    });

    test('finishPushed stops before the base and the queue', () async {
      final run = (await repository.beginRun('user-1'))!;
      final processing = operation.copyWith(state: SyncOperation.processing);
      await repository.putOperation(run, processing);

      final finish = repository.finishPushed(run, processing);
      await repository.clearLocalData();

      expect(await finish, isFalse);
      expectNothingStored();
    });
  });

  test('a Hive write started before a wipe is removed by it', () async {
    final write = Hive.box<LinkModel>(HiveConstants.linksBox).put('l-1', link);
    await repository.clearLocalData();
    await write;

    expect(Hive.box<LinkModel>(HiveConstants.linksBox).isEmpty, isTrue);
  });

  group('beginRun', () {
    Object? owner() =>
        Hive.box(HiveConstants.settingsBox).get(HiveConstants.ownerUidKey);

    test('claims a phone with no owner', () async {
      expect(await repository.beginRun('user-1'), isNotNull);
      expect(owner(), 'user-1');
    });

    test('a wipe while claiming a guest phone records no owner', () async {
      final begin = repository.beginRun('user-1');
      await repository.clearLocalData();

      expect(await begin, isNull);
      expect(owner(), isNull);
    });

    test(
      'a wipe while replacing another account\'s data records no owner',
      () async {
        await Hive.box(
          HiveConstants.settingsBox,
        ).put(HiveConstants.ownerUidKey, 'user-2');

        final begin = repository.beginRun('user-1');
        await repository.clearLocalData();

        expect(await begin, isNull);
        expect(owner(), isNull);
      },
    );

    test('a run is stale after a wipe and current otherwise', () async {
      final run = (await repository.beginRun('user-1'))!;
      expect(repository.isCurrentRun(run), isTrue);

      await repository.clearLocalData();

      expect(repository.isCurrentRun(run), isFalse);
    });
  });
}
