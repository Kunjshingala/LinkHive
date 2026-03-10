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
  });
}
