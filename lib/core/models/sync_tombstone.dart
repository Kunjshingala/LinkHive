import 'package:hive_flutter/hive_flutter.dart';

part 'sync_tombstone.g.dart';

/// Durable marker preventing a deleted local record from being recreated by a pull.
@HiveType(typeId: 3)
class SyncTombstone {
  @HiveField(0)
  final String entityType;

  @HiveField(1)
  final String entityId;

  @HiveField(2)
  final int deletedAt;

  const SyncTombstone({
    required this.entityType,
    required this.entityId,
    required this.deletedAt,
  });
}
