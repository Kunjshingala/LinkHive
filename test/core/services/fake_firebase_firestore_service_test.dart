import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/features/links/models/link_model.dart';

import '../../helpers/fake_firebase_firestore_service.dart';

void main() {
  const link = LinkModel(
    id: 'link-1',
    url: 'https://example.com',
    title: 'Example',
    createdAt: 100,
  );

  late int now;
  late FakeFirebaseFirestoreService cloud;

  setUp(() {
    now = 5000;
    cloud = FakeFirebaseFirestoreService(clock: () => now);
  });

  test(
    'a write stamps syncedAt from the server clock and marks it synced',
    () async {
      await cloud.saveLink('a', link);

      final stored = cloud.linksOf('a').single;
      expect(stored.syncedAt, 5000);
      expect(stored.isSynced, isTrue);
    },
  );

  test(
    'fetchLinksSince includes a link synced exactly at the boundary',
    () async {
      await cloud.saveLink('a', link);
      now = 6000;
      await cloud.saveLink('a', link.copyWith(id: 'link-2'));

      expect((await cloud.fetchLinksSince('a', 5000)).map((l) => l.id), [
        'link-1',
        'link-2',
      ]);
      expect((await cloud.fetchLinksSince('a', 5001)).map((l) => l.id), [
        'link-2',
      ]);
    },
  );

  test(
    'updateLink on a missing document throws not-found, like Firestore',
    () async {
      await expectLater(
        cloud.updateLink('a', link),
        throwsA(
          isA<FirebaseException>().having((e) => e.code, 'code', 'not-found'),
        ),
      );
    },
  );

  test('deleteLink removes the link and writes a tombstone', () async {
    await cloud.saveLink('a', link);
    now = 7000;
    await cloud.deleteLink('a', 'link-1');

    expect(cloud.linksOf('a'), isEmpty);
    expect(await cloud.fetchDeletedLinks('a'), ['link-1']);
    expect(await cloud.fetchDeletedLinksSince('a', 7000), ['link-1']);
    expect(await cloud.fetchDeletedLinksSince('a', 7001), isEmpty);
  });

  test('accounts are isolated by uid', () async {
    await cloud.saveLink('a', link);

    expect(cloud.linksOf('b'), isEmpty);
    expect(await cloud.fetchLinks('b'), isEmpty);
  });

  test('onCall can hold a call open until the test releases it', () async {
    final gate = Completer<void>();
    cloud.onCall = (method, uid) =>
        method == 'saveLink' ? gate.future : Future.value();

    var finished = false;
    final save = cloud.saveLink('a', link).then((_) => finished = true);
    await Future<void>.delayed(Duration.zero);

    expect(finished, isFalse);
    expect(cloud.linksOf('a'), isEmpty);

    gate.complete();
    await save;
    expect(cloud.linksOf('a'), hasLength(1));
  });
}
