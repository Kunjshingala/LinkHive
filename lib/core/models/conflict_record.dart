import 'package:hive_flutter/hive_flutter.dart';

part 'conflict_record.g.dart';

/// Preserves both local and cloud versions when automatic reconciliation is unsafe.
@HiveType(typeId: 4)
class ConflictRecord {
  @HiveField(0)
  final String conflictId;

  @HiveField(1)
  final String linkId;

  @HiveField(2)
  final List<String> conflictingFields;

  @HiveField(3)
  final Map<String, dynamic> baseVersion;

  @HiveField(4)
  final Map<String, dynamic> localVersion;

  @HiveField(5)
  final Map<String, dynamic>? cloudVersion;

  @HiveField(6)
  final int createdAt;

  @HiveField(7)
  final String status;

  const ConflictRecord({
    required this.conflictId,
    required this.linkId,
    required this.conflictingFields,
    required this.baseVersion,
    required this.localVersion,
    required this.cloudVersion,
    required this.createdAt,
    this.status = unresolved,
  });

  static const String unresolved = 'unresolved';
  static const String resolved = 'resolved';
}
