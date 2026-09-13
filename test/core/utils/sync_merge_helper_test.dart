import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/utils/sync_merge_helper.dart';
import 'package:link_hive/features/links/models/link_model.dart';

void main() {
  group('SyncMergeHelper', () {
    late LinkModel baseLink;
    late LinkModel cloudLink;
    late LinkModel localLink;

    setUp(() {
      final now = DateTime.now();
      baseLink = LinkModel(
        id: '1',
        title: 'Base Title',
        url: 'https://base.com',
        description: 'Base Description',
        image: 'base_image.png',
        categories: ['tech'],
        priority: 'Normal',
        isSynced: true,
        createdAt: now.millisecondsSinceEpoch,
        syncedAt: now.millisecondsSinceEpoch,
      );
      
      cloudLink = baseLink.copyWith();
      localLink = baseLink.copyWith();
    });

    test('returns cloud link if no local edits', () {
      final result = SyncMergeHelper.merge(
        base: baseLink,
        local: localLink, // Same as base
        cloud: cloudLink, // Same as base
      );

      expect(result.id, cloudLink.id);
      expect(result.title, cloudLink.title);
      expect(result.isSynced, true);
    });

    test('preserves local edits if cloud has not changed', () {
      localLink = localLink.copyWith(title: 'Local Title');

      final result = SyncMergeHelper.merge(
        base: baseLink,
        local: localLink,
        cloud: cloudLink, // Still 'Base Title'
      );

      expect(result.title, 'Local Title');
      // Should flag as unsynced so we push the changes
      expect(result.isSynced, false);
    });

    test('cloud edits win on conflict', () {
      localLink = localLink.copyWith(title: 'Local Title');
      cloudLink = cloudLink.copyWith(title: 'Cloud Title');

      final result = SyncMergeHelper.merge(
        base: baseLink,
        local: localLink,
        cloud: cloudLink,
      );

      // Cloud wins direct conflicts
      expect(result.title, 'Cloud Title');
      // Since it perfectly matches cloud, it's synced
      expect(result.isSynced, true);
    });

    test('merges non-conflicting fields gracefully', () {
      localLink = localLink.copyWith(title: 'Local Title');
      cloudLink = cloudLink.copyWith(description: 'Cloud Description');

      final result = SyncMergeHelper.merge(
        base: baseLink,
        local: localLink,
        cloud: cloudLink,
      );

      expect(result.title, 'Local Title'); // Kept local change
      expect(result.description, 'Cloud Description'); // Received cloud change
      expect(result.isSynced, false); // Because we kept a local change
    });

    test('merges category arrays correctly (unions and diffs)', () {
      baseLink = baseLink.copyWith(categories: ['A', 'B']);
      // Local removed 'B', added 'C'
      localLink = localLink.copyWith(categories: ['A', 'C']);
      // Cloud added 'D'
      cloudLink = cloudLink.copyWith(categories: ['A', 'B', 'D']);

      final result = SyncMergeHelper.merge(
        base: baseLink,
        local: localLink,
        cloud: cloudLink,
      );

      // Result should have:
      // 'A' (kept by both)
      // 'C' (added locally)
      // 'D' (added by cloud)
      // and NOT 'B' (removed locally)
      expect(result.categories, unorderedEquals(['A', 'C', 'D']));
      expect(result.isSynced, false);
    });
  });
}
