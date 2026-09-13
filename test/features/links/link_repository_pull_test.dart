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

  const cloudLink = LinkModel(
    id: 'cloud-link',
    url: 'https://cloud.example',
    title: 'Cloud link',
    createdAt: 1,
    isSynced: true,
  );
  const cloudCategory = CategoryModel(id: 'cloud-category', name: 'Cloud');

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'linkhive-pull-test-',
    );
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(LinkModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(SyncOperationAdapter());
    Hive.registerAdapter(SyncTombstoneAdapter());
    Hive.registerAdapter(ConflictRecordAdapter());
  });

  Future<void> openBoxes() async {
    await Hive.openBox<LinkModel>(HiveConstants.linksBox);
    await Hive.openBox<LinkModel>(HiveConstants.baseLinksBox);
    await Hive.openBox<LinkModel>(HiveConstants.conflictLinksBox);
    await Hive.openBox<CategoryModel>(HiveConstants.categoriesBox);
    await Hive.openBox<SyncOperation>(HiveConstants.syncOperationsBox);
    await Hive.openBox<SyncTombstone>(HiveConstants.syncTombstonesBox);
    await Hive.openBox<ConflictRecord>(HiveConstants.conflictRecordsBox);
  }

  setUp(() async {
    await openBoxes();
    await Future.wait([
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

  test(
    'pull restores remote links and categories into Hive after local data is cleared',
    () async {
      when(
        () => firebaseService.fetchLinks('user-1'),
      ).thenAnswer((_) async => [cloudLink]);
      when(
        () => firebaseService.fetchDeletedLinks('user-1'),
      ).thenAnswer((_) async => []);
      when(
        () => firebaseService.fetchCategories('user-1'),
      ).thenAnswer((_) async => [cloudCategory]);
      when(
        () => firebaseService.fetchDeletedCategories('user-1'),
      ).thenAnswer((_) async => []);

      await repository.clearLocalData();
      await repository.pullFromCloud();

      expect(repository.queryLinks(limit: 10).single.id, cloudLink.id);
      expect(repository.getCategories().single.id, cloudCategory.id);
    },
  );

  test('pull preserves a same-field edit as an unresolved conflict', () async {
    const base = LinkModel(
      id: 'conflict-link',
      url: 'https://example.com',
      title: 'Base title',
      createdAt: 1,
      isSynced: true,
    );
    final local = base.copyWith(title: 'Local title', isSynced: false);
    final cloud = base.copyWith(title: 'Cloud title', isSynced: true);
    await Hive.box<LinkModel>(HiveConstants.linksBox).put(base.id, local);
    await Hive.box<LinkModel>(HiveConstants.baseLinksBox).put(base.id, base);
    when(
      () => firebaseService.fetchLinks('user-1'),
    ).thenAnswer((_) async => [cloud]);
    when(
      () => firebaseService.fetchDeletedLinks('user-1'),
    ).thenAnswer((_) async => []);
    when(
      () => firebaseService.fetchCategories('user-1'),
    ).thenAnswer((_) async => []);
    when(
      () => firebaseService.fetchDeletedCategories('user-1'),
    ).thenAnswer((_) async => []);

    await repository.pullFromCloud();

    expect(repository.queryLinks(limit: 10).single.title, 'Local title');
    expect(repository.conflicts.single.conflictingFields, ['title']);
    expect(repository.conflicts.single.cloudVersion?['title'], 'Cloud title');
  });

  test(
    'pull records a conflict when a pending local operation meets a cloud edit',
    () async {
      const base = LinkModel(
        id: 'pending-conflict-link',
        url: 'https://example.com',
        title: 'Base title',
        createdAt: 1,
        isSynced: true,
      );
      await Hive.box<LinkModel>(HiveConstants.linksBox).put(base.id, base);
      await Hive.box<LinkModel>(HiveConstants.baseLinksBox).put(base.id, base);
      await repository.updateLink(base.copyWith(title: 'Local title'));
      final cloud = base.copyWith(title: 'Cloud title', isSynced: true);
      when(
        () => firebaseService.fetchLinks('user-1'),
      ).thenAnswer((_) async => [cloud]);
      when(
        () => firebaseService.fetchDeletedLinks('user-1'),
      ).thenAnswer((_) async => []);
      when(
        () => firebaseService.fetchCategories('user-1'),
      ).thenAnswer((_) async => []);
      when(
        () => firebaseService.fetchDeletedCategories('user-1'),
      ).thenAnswer((_) async => []);

      await repository.pullFromCloud();

      expect(repository.conflicts.single.linkId, base.id);
      expect(repository.conflicts.single.conflictingFields, ['title']);
    },
  );

  test(
    'local tombstones prevent an older remote link from reappearing',
    () async {
      await Hive.box<SyncTombstone>(HiveConstants.syncTombstonesBox).put(
        '${SyncOperation.linkEntity}:${cloudLink.id}',
        const SyncTombstone(
          entityType: SyncOperation.linkEntity,
          entityId: 'cloud-link',
          deletedAt: 2,
        ),
      );
      when(
        () => firebaseService.fetchLinks('user-1'),
      ).thenAnswer((_) async => [cloudLink]);
      when(
        () => firebaseService.fetchDeletedLinks('user-1'),
      ).thenAnswer((_) async => []);
      when(
        () => firebaseService.fetchCategories('user-1'),
      ).thenAnswer((_) async => []);
      when(
        () => firebaseService.fetchDeletedCategories('user-1'),
      ).thenAnswer((_) async => []);

      await repository.pullFromCloud();

      expect(repository.queryLinks(limit: 10), isEmpty);
    },
  );

  test(
    'keep-local conflict resolution queues the selected local version',
    () async {
      const base = LinkModel(
        id: 'resolve-link',
        url: 'https://example.com',
        title: 'Base title',
        createdAt: 1,
        isSynced: true,
      );
      final local = base.copyWith(title: 'Local title', isSynced: false);
      final cloud = base.copyWith(title: 'Cloud title', isSynced: true);
      await Hive.box<LinkModel>(HiveConstants.linksBox).put(base.id, local);
      await Hive.box<LinkModel>(HiveConstants.baseLinksBox).put(base.id, base);
      when(
        () => firebaseService.fetchLinks('user-1'),
      ).thenAnswer((_) async => [cloud]);
      when(
        () => firebaseService.fetchDeletedLinks('user-1'),
      ).thenAnswer((_) async => []);
      when(
        () => firebaseService.fetchCategories('user-1'),
      ).thenAnswer((_) async => []);
      when(
        () => firebaseService.fetchDeletedCategories('user-1'),
      ).thenAnswer((_) async => []);

      await repository.pullFromCloud();
      final conflict = repository.conflicts.single;
      await repository.resolveConflictKeepLocal(conflict.conflictId);

      expect(repository.conflicts, isEmpty);
      expect(
        repository.pendingSyncOperations.single.payload['title'],
        'Local title',
      );
    },
  );
}
