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

/// findByCanonicalUrl against real Hive boxes: the lookup saveOrMerge relies
/// on. Manager tests mock the repository, so they can't prove this part.
void main() {
  late Directory hiveDirectory;
  late LinkRepository repository;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('linkhive-dedup-');
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(LinkModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(SyncOperationAdapter());
    Hive.registerAdapter(SyncTombstoneAdapter());
  });

  setUp(() async {
    await Hive.openBox<LinkModel>(HiveConstants.linksBox);
    await Hive.openBox<LinkModel>(HiveConstants.baseLinksBox);
    await Hive.openBox<LinkModel>(HiveConstants.conflictLinksBox);
    await Hive.openBox<CategoryModel>(HiveConstants.categoriesBox);
    await Hive.openBox<SyncOperation>(HiveConstants.syncOperationsBox);
    await Hive.openBox<SyncTombstone>(HiveConstants.syncTombstonesBox);
    await Hive.box<LinkModel>(HiveConstants.linksBox).clear();
    await Hive.box<SyncOperation>(HiveConstants.syncOperationsBox).clear();

    repository = LinkRepository(
      firebaseService: MockFirebaseFirestoreService(),
      hiveHelper: HiveHelper(),
    );
  });

  tearDown(() => Hive.close());
  tearDownAll(() => hiveDirectory.delete(recursive: true));

  LinkModel link(String id, String url, int createdAt) =>
      LinkModel(id: id, url: url, title: '', createdAt: createdAt);

  test('finds a saved link through different tracking params', () async {
    await repository.addLink(
      link('1', 'https://youtu.be/Px_3O3KeR24?si=D1aFI2KXKKo0u0ob', 1),
    );

    final found = repository.findByCanonicalUrl(
      'https://youtu.be/Px_3O3KeR24?t=293&si=UzI6xOOWvJbDNkl_',
    );

    expect(found?.id, '1');
  });

  test('returns null for a different link', () async {
    await repository.addLink(
      link('1', 'https://youtu.be/Px_3O3KeR24?si=D1aFI2KXKKo0u0ob', 1),
    );

    expect(
      repository.findByCanonicalUrl('https://youtu.be/3mnhueXepdM?si=ODjo'),
      isNull,
    );
  });

  test(
    'with legacy duplicates, the oldest record is the merge target',
    () async {
      const reel = 'https://www.instagram.com/reel/DeKio97zfoF/';
      await repository.addLink(link('newer', '$reel?stkn=b', 200));
      await repository.addLink(link('oldest', '$reel?stkn=a', 100));
      await repository.addLink(link('middle', reel, 150));

      expect(repository.findByCanonicalUrl('$reel?stkn=c')?.id, 'oldest');
    },
  );
}
