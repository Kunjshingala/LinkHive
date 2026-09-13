import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/core/constants/hive_constants.dart';
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

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'linkhive-outbox-test-',
    );
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(LinkModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(SyncOperationAdapter());
    Hive.registerAdapter(SyncTombstoneAdapter());
  });

  Future<void> openBoxes() async {
    await Hive.openBox<LinkModel>(HiveConstants.linksBox);
    await Hive.openBox<LinkModel>(HiveConstants.baseLinksBox);
    await Hive.openBox<LinkModel>(HiveConstants.conflictLinksBox);
    await Hive.openBox<CategoryModel>(HiveConstants.categoriesBox);
    await Hive.openBox<SyncOperation>(HiveConstants.syncOperationsBox);
    await Hive.openBox<SyncTombstone>(HiveConstants.syncTombstonesBox);
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
    ]);

    firebaseService = MockFirebaseFirestoreService();
    repository = LinkRepository(
      firebaseService: firebaseService,
      hiveHelper: HiveHelper(),
    );
  });

  tearDown(() => Hive.close());
  tearDownAll(() => hiveDirectory.delete(recursive: true));

  final link = LinkModel(
    id: 'link-1',
    url: 'https://example.com',
    title: 'Example',
    createdAt: 1,
  );

  test(
    'create writes immediately to Hive and queues a durable operation',
    () async {
      await repository.addLink(link);

      expect(repository.queryLinks(limit: 10), hasLength(1));
      expect(repository.queryLinks(limit: 10).single.isSynced, isFalse);
      expect(repository.pendingSyncOperations, hasLength(1));
      expect(
        repository.pendingSyncOperations.single.operationType,
        SyncOperation.create,
      );
      expect(repository.pendingSyncOperations.single.entityId, 'link-1');
    },
  );

  test(
    'create followed by update coalesces to one create with the newest payload',
    () async {
      await repository.addLink(link);
      await repository.updateLink(link.copyWith(title: 'Updated'));

      final operations = repository.pendingSyncOperations;
      expect(operations, hasLength(1));
      expect(operations.single.operationType, SyncOperation.create);
      expect(operations.single.payload['title'], 'Updated');
    },
  );

  test('local data and queued operations survive a Hive restart', () async {
    await repository.addLink(link);
    await Hive.close();
    await openBoxes();

    final restartedRepository = LinkRepository(
      firebaseService: firebaseService,
      hiveHelper: HiveHelper(),
    );
    expect(restartedRepository.queryLinks(limit: 10), hasLength(1));
    expect(restartedRepository.pendingSyncOperations, hasLength(1));
    expect(restartedRepository.pendingSyncOperations.single.entityId, link.id);
  });

  test('delete persists a tombstone and replaces a pending update', () async {
    await Hive.box<LinkModel>(
      HiveConstants.linksBox,
    ).put(link.id, link.copyWith(isSynced: true));
    await Hive.box<LinkModel>(
      HiveConstants.baseLinksBox,
    ).put(link.id, link.copyWith(isSynced: true));
    await repository.updateLink(link.copyWith(title: 'Updated'));
    await repository.deleteLink(link.id);

    expect(repository.queryLinks(limit: 10), isEmpty);
    expect(
      repository.pendingSyncOperations.single.operationType,
      SyncOperation.delete,
    );
    expect(
      Hive.box<SyncTombstone>(
        HiveConstants.syncTombstonesBox,
      ).values.single.entityId,
      link.id,
    );
  });

  test(
    'create followed by delete removes the remote operation but retains the tombstone',
    () async {
      await repository.addLink(link);
      await repository.deleteLink(link.id);

      expect(repository.pendingSyncOperations, isEmpty);
      expect(
        Hive.box<SyncTombstone>(
          HiveConstants.syncTombstonesBox,
        ).values.single.entityId,
        link.id,
      );
    },
  );

  test(
    'category create and delete are represented in the same durable outbox',
    () async {
      const category = CategoryModel(id: 'category-1', name: 'Development');
      await repository.addCategory(category);
      expect(
        repository.pendingSyncOperations.single.entityType,
        SyncOperation.categoryEntity,
      );

      await repository.deleteCategory(category.id);
      expect(repository.pendingSyncOperations, isEmpty);
      expect(
        Hive.box<SyncTombstone>(
          HiveConstants.syncTombstonesBox,
        ).values.single.entityType,
        SyncOperation.categoryEntity,
      );
    },
  );
}
