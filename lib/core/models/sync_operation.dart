import 'package:hive_flutter/hive_flutter.dart';

part 'sync_operation.g.dart';

/// Durable local operation waiting to be synchronized with Firestore.
@HiveType(typeId: 2)
class SyncOperation {
  @HiveField(0)
  final String operationId;

  @HiveField(1)
  final String entityType;

  @HiveField(2)
  final String entityId;

  @HiveField(3)
  final String operationType;

  @HiveField(4)
  final Map<String, dynamic> payload;

  @HiveField(5)
  final int createdAt;

  @HiveField(6)
  final int attemptCount;

  @HiveField(7)
  final int nextAttemptAt;

  @HiveField(8)
  final String? lastError;

  @HiveField(9)
  final String state;

  const SyncOperation({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    this.attemptCount = 0,
    required this.nextAttemptAt,
    this.lastError,
    this.state = pending,
  });

  static const String linkEntity = 'link';
  static const String categoryEntity = 'category';
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String failed = 'failed';
  static const String blocked = 'blocked';

  SyncOperation copyWith({
    String? operationType,
    Map<String, dynamic>? payload,
    int? attemptCount,
    int? nextAttemptAt,
    String? lastError,
    bool clearLastError = false,
    String? state,
  }) {
    return SyncOperation(
      operationId: operationId,
      entityType: entityType,
      entityId: entityId,
      operationType: operationType ?? this.operationType,
      payload: payload ?? this.payload,
      createdAt: createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      state: state ?? this.state,
    );
  }
}
