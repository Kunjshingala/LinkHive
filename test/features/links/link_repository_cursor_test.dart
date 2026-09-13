import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/constants/hive_constants.dart';
import 'package:link_hive/core/models/conflict_record.dart';
import 'package:link_hive/core/models/sync_operation.dart';
import 'package:link_hive/core/models/sync_tombstone.dart';
import 'package:link_hive/core/services/firebase_firestore_service.dart';
import 'package:link_hive/core/utils/hive_helper.dart';
import 'package:link_hive/features/links/models/category_model.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFirestoreService extends Mock
    implements FirebaseFirestoreService {}

void main() {
  late Directory hiveDirectory;
  late MockFirebaseFirestoreService firebaseService;
  late LinkRepository repository;

  const baseLink = LinkModel(
    id: 'link-1',
    url: 'https://example.com',
    title: 'Original title',
    createdAt: 1000,
    isSynced: true,
  );

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'linkhive-cursor-test-',
    );
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(LinkModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(SyncOperationAdapter());
    Hive.registerAdapter(SyncTombstoneAdapter());
    Hive.registerAdapter(ConflictRecordAdapter());
  });

  Future<void> openBoxes() async {
    await Hive.openBox(HiveConstants.settingsBox);
    await Hive.openBox<LinkModel>(HiveConstants.linksBox);
    await Hive.openBox<LinkModel>(HiveConstants.baseLinksBox);
    await Hive.openBox<LinkModel>(HiveConstants.conflictLinksBox);
    await Hive.openBox<CategoryModel>(HiveConstants.categoriesBox);
    await Hive.openBox<SyncOperation>(HiveConstants.syncOperationsBox);
    await Hive.openBox<SyncTombstone>(HiveConstants.syncTombstonesBox);
    await Hive.openBox<ConflictRecord>(HiveConstants.conflictRecordsBox);
  }

  void stubEmptyPull() {
    when(
      () => firebaseService.fetchDeletedLinks('user-1'),
    ).thenAnswer((_) async => []);
    when(
      () => firebaseService.fetchCategories('user-1'),
    ).thenAnswer((_) async => []);
    when(
      () => firebaseService.fetchDeletedCategories('user-1'),
    ).thenAnswer((_) async => []);
  }

  setUp(() async {
    await openBoxes();
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
    firebaseService = MockFirebaseFirestoreService();
    repository = LinkRepository(
      firebaseService: firebaseService,
      hiveHelper: HiveHelper(),
      uidProvider: () => 'user-1',
    );
  });

  tearDown(() => Hive.close());
  tearDownAll(() => hiveDirectory.delete(recursive: true));

  test('first pull with no cursor calls fetchLinks (full bootstrap)', () async {
    when(
      () => firebaseService.fetchLinks('user-1'),
    ).thenAnswer((_) async => [baseLink]);
    stubEmptyPull();

    await repository.pullFromCloud();

    verify(() => firebaseService.fetchLinks('user-1')).called(1);
    verifyNever(() => firebaseService.fetchLinksSince(any(), any()));
  });

  test('pull advances the cursor stored in the settings box', () async {
    when(
      () => firebaseService.fetchLinks('user-1'),
    ).thenAnswer((_) async => []);
    stubEmptyPull();

    final before = DateTime.now().toUtc().millisecondsSinceEpoch;
    await repository.pullFromCloud();
    final after = DateTime.now().toUtc().millisecondsSinceEpoch;

    final saved =
        Hive.box(HiveConstants.settingsBox).get(HiveConstants.lastPulledAtKey)
            as int?;
    expect(saved, isNotNull);
    expect(saved, greaterThanOrEqualTo(before));
    expect(saved, lessThanOrEqualTo(after));
  });

  test(
    'subsequent pull calls fetchLinksSince with cursor minus 60-second overlap',
    () async {
      const cursor = 200000;
      const expectedSince = cursor - 60 * 1000; // 60-second overlap
      await Hive.box(
        HiveConstants.settingsBox,
      ).put(HiveConstants.lastPulledAtKey, cursor);

      when(
        () => firebaseService.fetchLinksSince('user-1', expectedSince),
      ).thenAnswer((_) async => []);
      stubEmptyPull();

      await repository.pullFromCloud();

      verify(
        () => firebaseService.fetchLinksSince('user-1', expectedSince),
      ).called(1);
      verifyNever(() => firebaseService.fetchLinks(any()));
    },
  );

  test(
    'clearLocalData resets the cursor to force a full fetch on next pull',
    () async {
      await Hive.box(
        HiveConstants.settingsBox,
      ).put(HiveConstants.lastPulledAtKey, 999999);

      await repository.clearLocalData();

      final cursor =
          Hive.box(HiveConstants.settingsBox).get(HiveConstants.lastPulledAtKey)
              as int?;
      expect(cursor, isNull);
    },
  );

  // ─── Two-device scenarios ─────────────────────────────────────────────────

  test('two-device edit: a link edited on device B is merged into device A on '
      'the next incremental pull', () async {
    // Device A synced this link previously; base == local.
    await Hive.box<LinkModel>(
      HiveConstants.linksBox,
    ).put(baseLink.id, baseLink);
    await Hive.box<LinkModel>(
      HiveConstants.baseLinksBox,
    ).put(baseLink.id, baseLink);

    // Device A last pulled at T=100.
    const cursor = 100;
    await Hive.box(
      HiveConstants.settingsBox,
    ).put(HiveConstants.lastPulledAtKey, cursor);

    // Device B edited the link after T=100; Firestore returns the new version.
    final cloudUpdated = baseLink.copyWith(title: 'Device B title');
    when(
      () => firebaseService.fetchLinksSince('user-1', cursor - 60 * 1000),
    ).thenAnswer((_) async => [cloudUpdated]);
    stubEmptyPull();

    await repository.pullFromCloud();

    // Local title should now reflect device B's edit (no local changes to
    // conflict with).
    expect(repository.queryLinks(limit: 10).single.title, 'Device B title');
    expect(repository.conflicts, isEmpty);
  });

  test('two-device delete: a link deleted on device B is removed from device A '
      'on the next incremental pull', () async {
    // Device A has the link locally and in the base box.
    await Hive.box<LinkModel>(
      HiveConstants.linksBox,
    ).put(baseLink.id, baseLink);
    await Hive.box<LinkModel>(
      HiveConstants.baseLinksBox,
    ).put(baseLink.id, baseLink);

    // Device A last pulled at T=100.
    await Hive.box(
      HiveConstants.settingsBox,
    ).put(HiveConstants.lastPulledAtKey, 100);

    // Device B deleted the link; Firestore tombstone collection reflects this.
    when(
      () => firebaseService.fetchLinksSince('user-1', 100 - 60 * 1000),
    ).thenAnswer((_) async => []);
    when(
      () => firebaseService.fetchDeletedLinks('user-1'),
    ).thenAnswer((_) async => [baseLink.id]);
    when(
      () => firebaseService.fetchCategories('user-1'),
    ).thenAnswer((_) async => []);
    when(
      () => firebaseService.fetchDeletedCategories('user-1'),
    ).thenAnswer((_) async => []);

    await repository.pullFromCloud();

    expect(repository.queryLinks(limit: 10), isEmpty);
  });

  test(
    'overlap window includes records at the exact cursor boundary',
    () async {
      const cursor = 5000;
      const overlap = 60 * 1000;
      // A link whose syncedAt falls inside the overlap window [cursor-overlap,
      // cursor] must be fetched even though it predates the cursor.
      final linkAtBoundary = baseLink.copyWith(id: 'boundary-link');

      await Hive.box(
        HiveConstants.settingsBox,
      ).put(HiveConstants.lastPulledAtKey, cursor);

      when(
        () => firebaseService.fetchLinksSince('user-1', cursor - overlap),
      ).thenAnswer((_) async => [linkAtBoundary]);
      stubEmptyPull();

      await repository.pullFromCloud();

      expect(
        repository.queryLinks(limit: 10).any((l) => l.id == 'boundary-link'),
        isTrue,
      );
    },
  );
}
