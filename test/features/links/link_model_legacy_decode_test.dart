import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:link_hive/features/links/models/link_model.dart';

/// Writes a link exactly as the app did before shareCount / lastSharedAt /
/// otherUrls existed: fields 0–13 only, same typeId as [LinkModelAdapter].
class _LegacyLinkModelAdapter extends TypeAdapter<LinkModel> {
  @override
  final int typeId = 0;

  @override
  LinkModel read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, LinkModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.image)
      ..writeByte(5)
      ..write(obj.categories)
      ..writeByte(6)
      ..write(obj.priority)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.syncedAt)
      ..writeByte(9)
      ..write(obj.isSynced)
      ..writeByte(10)
      ..write(obj.isRead)
      ..writeByte(11)
      ..write(obj.isQuickSaved)
      ..writeByte(12)
      ..write(obj.resurfaceAt)
      ..writeByte(13)
      ..write(obj.lastResurfacedAt);
  }
}

/// Regression guard for the launch crash class from 2026-09-24: adding
/// `@HiveField(11)` without a default made every pre-existing link throw
/// `type 'Null' is not a subtype of type 'bool'` in `HiveHelper.init()`.
/// Every link on the user's phone today was written without fields 14–16, so
/// they must decode with safe defaults through the real generated adapter.
void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('linkhive-legacy-');
    Hive.init(hiveDirectory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'a link stored before fields 14–16 existed decodes with defaults',
    () async {
      Hive.registerAdapter<LinkModel>(_LegacyLinkModelAdapter());
      final legacyBox = await Hive.openBox<LinkModel>('links');
      await legacyBox.put(
        'old-1',
        const LinkModel(
          id: 'old-1',
          url: 'https://www.linkedin.com/in/kunjshingala09',
          title: 'Kunj Shingala | LinkedIn',
          createdAt: 1758000000000,
          isRead: true,
          isQuickSaved: true,
          lastResurfacedAt: 1758500000000,
        ),
      );
      await legacyBox.close();

      Hive.registerAdapter<LinkModel>(LinkModelAdapter(), override: true);
      final box = await Hive.openBox<LinkModel>('links');
      final link = box.get('old-1')!;

      expect(link.shareCount, 1);
      expect(link.lastSharedAt, isNull);
      expect(link.otherUrls, isEmpty);
      // The fields that were stored must come back unchanged.
      expect(link.url, 'https://www.linkedin.com/in/kunjshingala09');
      expect(link.title, 'Kunj Shingala | LinkedIn');
      expect(link.isRead, isTrue);
      expect(link.isQuickSaved, isTrue);
      expect(link.lastResurfacedAt, 1758500000000);
    },
  );
}
