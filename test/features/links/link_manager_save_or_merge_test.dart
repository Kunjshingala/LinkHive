import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/utils/url_canonical.dart';
import 'package:link_hive/features/links/manager/link_manager.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkRepository extends Mock implements LinkRepository {}

/// saveOrMerge / undoMerge / keepOnlyVersion against an in-memory store.
///
/// The repository is mocked but behaves like the real one for the calls the
/// manager makes (find by canonical key, add, update, get), with a small
/// write delay so concurrent calls genuinely overlap.
void main() {
  late MockLinkRepository repository;
  late Map<String, LinkModel> store;
  late LinkManager manager;
  late bool failNextWrite;

  final now = DateTime.utc(2026, 10, 7, 9);
  final nowMs = now.millisecondsSinceEpoch;

  setUpAll(() {
    registerFallbackValue(
      const LinkModel(id: 'fallback', url: '', title: '', createdAt: 0),
    );
  });

  setUp(() {
    repository = MockLinkRepository();
    store = {};
    failNextWrite = false;
    manager = LinkManager(repository: repository, clock: () => now);

    Future<void> write(LinkModel link) async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (failNextWrite) {
        failNextWrite = false;
        throw StateError('Hive write failed');
      }
      store[link.id] = link;
    }

    when(() => repository.findByCanonicalUrl(any())).thenAnswer((inv) {
      final key = canonicalUrl(inv.positionalArguments.first as String);
      final matches = store.values.where((l) => canonicalUrl(l.url) == key);
      if (matches.isEmpty) return null;
      return matches.reduce((a, b) => a.createdAt <= b.createdAt ? a : b);
    });
    when(
      () => repository.addLink(any()),
    ).thenAnswer((inv) => write(inv.positionalArguments.first as LinkModel));
    when(
      () => repository.updateLink(any()),
    ).thenAnswer((inv) => write(inv.positionalArguments.first as LinkModel));
    when(
      () => repository.getLinkById(any()),
    ).thenAnswer((inv) => store[inv.positionalArguments.first as String]);
  });

  LinkModel candidate(
    String id,
    String url, {
    List<String> categories = const [],
  }) => LinkModel(
    id: id,
    url: url,
    title: '',
    createdAt: nowMs,
    isQuickSaved: true,
    categories: categories,
  );

  const reelA =
      'https://www.instagram.com/reel/DeKio97zfoF/?stkn=aW4yNHE1cm9ubW00';
  const reelB =
      'https://www.instagram.com/reel/DeKio97zfoF/?stkn=c29tZXRoaW5nZWxzZQ';

  group('created', () {
    test(
      'a new URL is stored with shareCount 1 and lastSharedAt = createdAt',
      () async {
        final result = await manager.saveOrMerge(candidate('1', reelA));

        expect(result, isA<SaveCreated>());
        final saved = store['1']!;
        expect(saved.shareCount, 1);
        expect(saved.lastSharedAt, nowMs);
        expect(saved.url, reelA);
      },
    );

    test('a schedule picked on the form applies to the new link', () async {
      await manager.saveOrMerge(candidate('1', reelA), resurfaceAt: 123);
      expect(store['1']!.resurfaceAt, 123);
    });
  });

  group('merged', () {
    late LinkModel original;

    setUp(() {
      original = LinkModel(
        id: 'orig',
        url: reelA,
        title: 'Varun Mayya on Instagram',
        priority: 'High',
        categories: const ['ai'],
        createdAt: 1000,
        shareCount: 1,
        lastSharedAt: 1000,
      );
      store['orig'] = original;
    });

    test(
      'a re-share merges into the original instead of creating a link',
      () async {
        final result = await manager.saveOrMerge(candidate('new', reelB));

        expect(result, isA<SaveMerged>());
        expect(store.keys, ['orig']);
        final merged = store['orig']!;
        expect(merged.shareCount, 2);
        expect(merged.lastSharedAt, nowMs);
        expect(merged.resurfaceAt, nowMs, reason: 'due again in Today');
      },
    );

    test('keeps every existing field, including the saved URL', () async {
      await manager.saveOrMerge(
        candidate('new', reelB, categories: const ['video']),
      );

      final merged = store['orig']!;
      expect(merged.url, reelA);
      expect(merged.title, 'Varun Mayya on Instagram');
      expect(merged.priority, 'High');
      expect(merged.categories, unorderedEquals(['ai', 'video']));
    });

    test('a different URL is kept as another version', () async {
      final result = await manager.saveOrMerge(candidate('new', reelB));

      expect((result as SaveMerged).addedVersion, isTrue);
      expect(store['orig']!.otherUrls, [reelB]);
    });

    test('the exact same URL is not added as a version', () async {
      final result = await manager.saveOrMerge(candidate('new', reelA));

      expect((result as SaveMerged).addedVersion, isFalse);
      expect(store['orig']!.otherUrls, isEmpty);
    });

    test('keeps at most 5 other versions, dropping the oldest', () async {
      for (var i = 1; i <= 6; i++) {
        await manager.saveOrMerge(
          candidate(
            'n$i',
            'https://www.instagram.com/reel/DeKio97zfoF/?stkn=v$i',
          ),
        );
      }

      final versions = store['orig']!.otherUrls;
      expect(versions, hasLength(LinkManager.maxOtherUrls));
      expect(versions.first, endsWith('stkn=v2'));
      expect(versions.last, endsWith('stkn=v6'));
    });

    test('an archived link comes back unread and due', () async {
      store['orig'] = original.copyWith(isRead: true, lastResurfacedAt: 5000);

      await manager.saveOrMerge(candidate('new', reelB));

      final merged = store['orig']!;
      expect(merged.isRead, isFalse);
      expect(merged.resurfaceAt, nowMs);
      expect(merged.lastResurfacedAt, 5000, reason: 'unchanged by a merge');
    });

    test('an explicit Tonight/Weekend pick beats "due now"', () async {
      await manager.saveOrMerge(candidate('new', reelB), resurfaceAt: 99999);
      expect(store['orig']!.resurfaceAt, 99999);
    });

    test('Someday leaves it unread but not due', () async {
      store['orig'] = original.copyWith(isRead: true, resurfaceAt: 42);

      await manager.saveOrMerge(
        candidate('new', reelB),
        clearResurfaceAt: true,
      );

      expect(store['orig']!.isRead, isFalse);
      expect(store['orig']!.resurfaceAt, isNull);
    });

    test('Quick-links Inbox membership is not changed by a merge', () async {
      await manager.saveOrMerge(candidate('new', reelB));
      expect(store['orig']!.isQuickSaved, isFalse);
    });
  });

  group('undoMerge', () {
    test('reverts the merge and never deletes the original', () async {
      final original = LinkModel(
        id: 'orig',
        url: reelA,
        title: 'T',
        createdAt: 1000,
      );
      store['orig'] = original;

      final result =
          await manager.saveOrMerge(candidate('new', reelB)) as SaveMerged;
      await manager.undoMerge(result.previous);

      final reverted = store['orig']!;
      expect(reverted.shareCount, 1);
      expect(reverted.lastSharedAt, isNull, reason: 'legacy null restored');
      expect(reverted.resurfaceAt, isNull, reason: 'not left due');
      expect(reverted.otherUrls, isEmpty);
      expect(reverted.isRead, isFalse);
      verifyNever(() => repository.deleteLink(any()));
    });

    test('restores archived state', () async {
      store['orig'] = LinkModel(
        id: 'orig',
        url: reelA,
        title: 'T',
        createdAt: 1000,
        isRead: true,
      );

      final result =
          await manager.saveOrMerge(candidate('new', reelB)) as SaveMerged;
      await manager.undoMerge(result.previous);

      expect(store['orig']!.isRead, isTrue);
    });

    test('keeps metadata that arrived after the merge', () async {
      store['orig'] = LinkModel(
        id: 'orig',
        url: reelA,
        title: '',
        createdAt: 1000,
      );

      final result =
          await manager.saveOrMerge(candidate('new', reelB)) as SaveMerged;
      store['orig'] = store['orig']!.copyWith(
        title: 'Fetched title',
        image: 'img',
      );
      await manager.undoMerge(result.previous);

      expect(store['orig']!.title, 'Fetched title');
      expect(store['orig']!.image, 'img');
    });

    test('does nothing when the link was deleted meanwhile', () async {
      store['orig'] = LinkModel(
        id: 'orig',
        url: reelA,
        title: '',
        createdAt: 1000,
      );
      final result =
          await manager.saveOrMerge(candidate('new', reelB)) as SaveMerged;
      store.remove('orig');

      await manager.undoMerge(result.previous);

      expect(store, isEmpty);
    });
  });

  group('keepOnlyVersion', () {
    test('makes the chosen URL the link and clears the others', () async {
      store['orig'] = LinkModel(
        id: 'orig',
        url: reelA,
        title: 'T',
        createdAt: 1000,
        otherUrls: const [reelB],
      );

      await manager.keepOnlyVersion(store['orig']!, reelB);

      expect(store['orig']!.url, reelB);
      expect(store['orig']!.otherUrls, isEmpty);
    });
  });

  group('serialization', () {
    test(
      'two concurrent shares of one URL make one link with shareCount 2',
      () async {
        await Future.wait([
          manager.saveOrMerge(candidate('a', reelA)),
          manager.saveOrMerge(candidate('b', reelB)),
        ]);

        expect(store, hasLength(1));
        expect(store.values.single.shareCount, 2);
      },
    );

    test('a failed save does not block the next one', () async {
      failNextWrite = true;
      await expectLater(
        manager.saveOrMerge(candidate('a', reelA)),
        throwsStateError,
      );

      final result = await manager.saveOrMerge(candidate('b', reelA));

      expect(result, isA<SaveCreated>());
      expect(store.keys, ['b']);
    });

    test(
      'an Undo racing a re-share applies in order without losing a count',
      () async {
        store['orig'] = LinkModel(
          id: 'orig',
          url: reelA,
          title: '',
          createdAt: 1000,
        );
        final first =
            await manager.saveOrMerge(candidate('n1', reelB)) as SaveMerged;

        await Future.wait([
          manager.undoMerge(first.previous),
          manager.saveOrMerge(candidate('n2', reelB)),
        ]);

        // Undo ran first (shareCount back to 1), then the re-share counted.
        expect(store['orig']!.shareCount, 2);
      },
    );
  });
}
