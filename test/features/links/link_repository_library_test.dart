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
import 'package:link_hive/features/links/models/link_query.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFirestoreService extends Mock
    implements FirebaseFirestoreService {}

/// The Library queries and bulk writes against real Hive boxes.
void main() {
  late Directory hiveDirectory;
  late LinkRepository repository;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('linkhive-library-');
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
    await Hive.box<LinkModel>(HiveConstants.baseLinksBox).clear();
    await Hive.box<SyncOperation>(HiveConstants.syncOperationsBox).clear();
    await Hive.box<SyncTombstone>(HiveConstants.syncTombstonesBox).clear();

    repository = LinkRepository(
      firebaseService: MockFirebaseFirestoreService(),
      hiveHelper: HiveHelper(),
    );
  });

  tearDown(() => Hive.close());
  tearDownAll(() => hiveDirectory.delete(recursive: true));

  Box<LinkModel> links() => Hive.box<LinkModel>(HiveConstants.linksBox);

  Future<void> put(
    String id, {
    String url = '',
    String title = '',
    List<String> categories = const [],
    String priority = 'Normal',
    int createdAt = 0,
    bool isRead = false,
    bool isQuickSaved = false,
    int shareCount = 1,
  }) => links().put(
    id,
    LinkModel(
      id: id,
      url: url.isEmpty ? 'https://example.com/$id' : url,
      title: title.isEmpty ? id : title,
      categories: categories,
      priority: priority,
      createdAt: createdAt,
      isRead: isRead,
      isQuickSaved: isQuickSaved,
      shareCount: shareCount,
      isSynced: true,
    ),
  );

  List<String> ids(LinkQuery query) =>
      repository.findLinks(query, limit: 100).map((l) => l.id).toList();

  group('findLinks filters', () {
    setUp(() async {
      await put(
        'yt',
        url: 'https://youtu.be/abc',
        categories: ['Watch'],
        priority: 'High',
        createdAt: 3,
      );
      await put(
        'ig',
        url: 'https://www.instagram.com/reel/x/',
        categories: ['Recipes'],
        createdAt: 2,
        isRead: true,
        shareCount: 3,
      );
      await put(
        'blog',
        url: 'https://medium.com/p/1',
        title: 'Pizza dough guide',
        categories: ['Recipes', 'Read'],
        priority: 'low',
        createdAt: 1,
      );
      await put('inbox', isQuickSaved: true, createdAt: 9);
    });

    test('no filters returns every Library link, newest first', () {
      expect(ids(const LinkQuery()), ['yt', 'ig', 'blog']);
    });

    test('never includes Inbox links', () {
      expect(ids(const LinkQuery()), isNot(contains('inbox')));
    });

    test('read state', () {
      expect(ids(const LinkQuery(readFilter: ReadFilter.unread)), [
        'yt',
        'blog',
      ]);
      expect(ids(const LinkQuery(readFilter: ReadFilter.read)), ['ig']);
    });

    test('categories match any of the selected names', () {
      expect(ids(const LinkQuery(categories: {'Read', 'Watch'})), [
        'yt',
        'blog',
      ]);
    });

    test('priorities compare case-insensitively', () {
      expect(ids(const LinkQuery(priorities: {'Low'})), ['blog']);
      expect(ids(const LinkQuery(priorities: {'high', 'LOW'})), [
        'yt',
        'blog',
      ]);
    });

    test('host matches the folded source host', () {
      expect(ids(const LinkQuery(host: 'youtube.com')), ['yt']);
      expect(ids(const LinkQuery(host: 'instagram.com')), ['ig']);
    });

    test('minShareCount backs the Saved 2×+ tile', () {
      expect(ids(const LinkQuery(minShareCount: 2)), ['ig']);
    });

    test('search matches title and URL', () {
      expect(ids(const LinkQuery(search: 'PIZZA')), ['blog']);
      expect(ids(const LinkQuery(search: 'instagram')), ['ig']);
    });

    test('filters combine', () {
      expect(
        ids(
          const LinkQuery(
            categories: {'Recipes'},
            readFilter: ReadFilter.unread,
          ),
        ),
        ['blog'],
      );
    });

    test('countLinks matches the full result size', () {
      expect(repository.countLinks(const LinkQuery(categories: {'Recipes'})), 2);
    });

    test('paging uses offset and limit', () {
      expect(
        repository
            .findLinks(const LinkQuery(), limit: 1, offset: 1)
            .map((l) => l.id),
        ['ig'],
      );
    });
  });

  group('findLinks sort', () {
    setUp(() async {
      await put(
        'a',
        url: 'https://b-site.com/1',
        priority: 'Low',
        createdAt: 1,
        shareCount: 2,
      );
      await put(
        'b',
        url: 'https://a-site.com/1',
        priority: 'High',
        createdAt: 2,
      );
      await put(
        'c',
        url: 'https://c-site.com/1',
        priority: 'Normal',
        createdAt: 3,
        shareCount: 5,
      );
    });

    test('newest and oldest', () {
      expect(ids(const LinkQuery()), ['c', 'b', 'a']);
      expect(ids(const LinkQuery(sort: LinkSort.oldest)), ['a', 'b', 'c']);
    });

    test('priority puts High first and Low last', () {
      expect(ids(const LinkQuery(sort: LinkSort.priority)), ['b', 'c', 'a']);
    });

    test('most saved', () {
      expect(ids(const LinkQuery(sort: LinkSort.mostSaved)), ['c', 'a', 'b']);
    });

    test('site A–Z', () {
      expect(ids(const LinkQuery(sort: LinkSort.site)), ['b', 'a', 'c']);
    });
  });

  group('overview counts', () {
    setUp(() async {
      await put(
        'a',
        url: 'https://youtu.be/1',
        categories: ['Watch'],
        priority: 'High',
      );
      await put(
        'b',
        url: 'https://www.youtube.com/watch?v=2',
        categories: ['Watch', 'Learn'],
        isRead: true,
        shareCount: 2,
      );
      await put(
        'c',
        url: 'https://amazon.in/dp/1',
        categories: ['Shop'],
      );
      await put(
        'inbox',
        url: 'https://youtu.be/3',
        categories: ['Watch'],
        isQuickSaved: true,
      );
    });

    test('getLibraryStats excludes the Inbox', () {
      expect(
        repository.getLibraryStats(),
        const LibraryStats(
          total: 3,
          unread: 2,
          high: 1,
          savedTwicePlus: 1,
          read: 1,
        ),
      );
    });

    test('getSourceCounts groups by folded host, most first', () {
      expect(repository.getSourceCounts(), const [
        NamedCount('youtube.com', 2),
        NamedCount('amazon.in', 1),
      ]);
    });

    test('getCategoryCounts lists names in use, most first then A–Z', () {
      expect(repository.getCategoryCounts(), const [
        NamedCount('Watch', 2),
        NamedCount('Learn', 1),
        NamedCount('Shop', 1),
      ]);
    });

    test('getCategoryCountsForHost keeps names used on 2+ links', () {
      expect(repository.getCategoryCountsForHost('youtube.com'), const [
        NamedCount('Watch', 2),
      ]);
      expect(
        repository.getCategoryCountsForHost('youtube.com', minLinks: 1),
        const [NamedCount('Watch', 2), NamedCount('Learn', 1)],
      );
    });
  });

  group('bulk writes', () {
    List<String> queuedLinkIds() =>
        repository.pendingSyncOperations
            .where((op) => op.entityType == SyncOperation.linkEntity)
            .map((op) => op.entityId)
            .toList()
          ..sort();

    setUp(() async {
      await put('a', categories: ['Watch']);
      await put('b', isRead: true);
      await put('c', priority: 'High');
    });

    test('markLinksRead marks and queues only the unread ones', () async {
      await repository.markLinksRead(['a', 'b', 'missing']);

      expect(links().get('a')!.isRead, isTrue);
      expect(queuedLinkIds(), ['a']);
    });

    test('addCategoryToLinks keeps existing categories', () async {
      await repository.addCategoryToLinks(['a', 'b'], 'Watch');

      expect(links().get('a')!.categories, ['Watch']);
      expect(links().get('b')!.categories, ['Watch']);
      expect(queuedLinkIds(), ['b']);

      await repository.addCategoryToLinks(['a'], 'Learn');
      expect(links().get('a')!.categories, ['Watch', 'Learn']);
    });

    test('setPriorityForLinks skips links already at that priority', () async {
      await repository.setPriorityForLinks(['a', 'c'], 'High');

      expect(links().get('a')!.priority, 'High');
      expect(queuedLinkIds(), ['a']);
    });

    test('deleteLinks deletes and tombstones each link', () async {
      await repository.deleteLinks(['a', 'c', 'missing']);

      expect(links().keys, ['b']);
      expect(
        Hive.box<SyncTombstone>(HiveConstants.syncTombstonesBox).length,
        2,
      );
    });
  });
}
