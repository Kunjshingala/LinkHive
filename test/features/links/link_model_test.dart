import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/constants/firebase_constants.dart';
import 'package:link_hive/features/links/models/link_model.dart';

void main() {
  group('LinkModel', () {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final testLink = LinkModel(
      id: 'test-id',
      url: 'https://flutter.dev',
      title: 'Flutter',
      description: 'Flutter website',
      image: 'image_url',
      categories: ['dev'],
      priority: 'High',
      createdAt: now,
      isSynced: false,
    );

    test('copyWith updates specified fields', () {
      final updated = testLink.copyWith(title: 'Updated Title', isSynced: true);

      expect(updated.id, testLink.id);
      expect(updated.title, 'Updated Title');
      expect(updated.isSynced, true);
      expect(updated.url, testLink.url);
    });

    test('toFirestore returns correct map (excluding syncedAt)', () {
      final map = testLink.toFirestore();

      expect(map[FirebaseConstants.linkUrl], 'https://flutter.dev');
      expect(map[FirebaseConstants.linkTitle], 'Flutter');
      expect(map[FirebaseConstants.linkDescription], 'Flutter website');
      expect(map[FirebaseConstants.linkImage], 'image_url');
      expect(map[FirebaseConstants.linkCategories], ['dev']);
      expect(map[FirebaseConstants.linkPriority], 'High');
      expect(map[FirebaseConstants.linkCreatedAt], now);
      expect(map.containsKey(FirebaseConstants.linkSyncedAt), false);
    });

    test('fromFirestore handles Timestamp correctly', () {
      final timestamp = Timestamp.now();
      final data = {
        FirebaseConstants.linkUrl: 'https://flutter.dev',
        FirebaseConstants.linkTitle: 'Flutter',
        FirebaseConstants.linkDescription: 'Flutter website',
        FirebaseConstants.linkImage: 'image_url',
        FirebaseConstants.linkCategories: ['dev'],
        FirebaseConstants.linkPriority: 'High',
        FirebaseConstants.linkCreatedAt: now,
        FirebaseConstants.linkSyncedAt: timestamp,
      };

      final link = LinkModel.fromFirestore('test-id', data);

      expect(link.id, 'test-id');
      expect(link.url, 'https://flutter.dev');
      expect(link.syncedAt, timestamp.millisecondsSinceEpoch);
      expect(link.isSynced, true);
    });

    test('fromFirestore handles raw integer for syncedAt', () {
      final data = {
        FirebaseConstants.linkUrl: 'https://flutter.dev',
        FirebaseConstants.linkCreatedAt: now,
        FirebaseConstants.linkSyncedAt: now, // Raw integer
      };

      final link = LinkModel.fromFirestore('test-id', data);

      expect(link.syncedAt, now);
      expect(link.isSynced, true);
    });

    test('a new link is saved once with no other versions', () {
      expect(testLink.shareCount, 1);
      expect(testLink.lastSharedAt, isNull);
      expect(testLink.otherUrls, isEmpty);
    });

    test('copyWith updates shareCount, lastSharedAt and otherUrls', () {
      final updated = testLink.copyWith(
        shareCount: 3,
        lastSharedAt: now,
        otherUrls: ['https://flutter.dev/?utm_source=x'],
      );

      expect(updated.shareCount, 3);
      expect(updated.lastSharedAt, now);
      expect(updated.otherUrls, ['https://flutter.dev/?utm_source=x']);
    });

    test(
      'clearLastSharedAt writes null (Undo of a merge on a legacy link)',
      () {
        final shared = testLink.copyWith(lastSharedAt: now);

        expect(shared.copyWith(clearLastSharedAt: true).lastSharedAt, isNull);
        expect(shared.copyWith(lastSharedAt: null).lastSharedAt, now);
      },
    );

    test('toFirestore includes the merge fields', () {
      final map = testLink
          .copyWith(shareCount: 2, lastSharedAt: now, otherUrls: ['u2'])
          .toFirestore();

      expect(map[FirebaseConstants.linkShareCount], 2);
      expect(map[FirebaseConstants.linkLastSharedAt], now);
      expect(map[FirebaseConstants.linkOtherUrls], ['u2']);
    });

    test('fromFirestore defaults the merge fields for legacy docs', () {
      final link = LinkModel.fromFirestore('test-id', {
        FirebaseConstants.linkUrl: 'https://flutter.dev',
        FirebaseConstants.linkCreatedAt: now,
      });

      expect(link.shareCount, 1);
      expect(link.lastSharedAt, isNull);
      expect(link.otherUrls, isEmpty);
    });

    test('fromFirestore reads the merge fields when present', () {
      final link = LinkModel.fromFirestore('test-id', {
        FirebaseConstants.linkUrl: 'https://flutter.dev',
        FirebaseConstants.linkCreatedAt: now,
        FirebaseConstants.linkShareCount: 4,
        FirebaseConstants.linkLastSharedAt: now,
        FirebaseConstants.linkOtherUrls: ['u2', 'u3'],
      });

      expect(link.shareCount, 4);
      expect(link.lastSharedAt, now);
      expect(link.otherUrls, ['u2', 'u3']);
    });
  });
}
