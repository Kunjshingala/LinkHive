import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';

/// High-level state exposed by the sync engine for UI and diagnostics.
///
/// Precedence when several apply: [conflict] first. Offline, it is
/// [waitingForInternet] when changes are pending, otherwise [idle]. Online, it
/// is [syncing] while a run is active, otherwise [failed] after a failure,
/// otherwise [idle].
enum SyncStatus {
  /// Nothing is running. There may still be changes waiting for their turn.
  idle,

  /// Online and a sync run is active.
  syncing,

  /// Offline with changes that have not reached the cloud yet. Not a failure.
  waitingForInternet,

  /// Online, and the last attempt failed. A retry is scheduled.
  failed,

  /// Local and cloud edits collided and need the user's decision.
  conflict,
}

/// Why a sync attempt failed, in terms the UI can explain to the user.
enum SyncFailure {
  /// A cloud call did not answer in time.
  timeout,

  /// The cloud refused the request for this account.
  permissionDenied,

  /// The cloud service could not be reached.
  unavailable,

  /// Anything else. The details are in the debug log.
  unknown;

  static SyncFailure fromError(Object error) {
    if (error is TimeoutException) return timeout;
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => permissionDenied,
        'unavailable' => unavailable,
        'deadline-exceeded' => timeout,
        _ => unknown,
      };
    }
    return unknown;
  }
}

/// What has not reached the cloud yet.
class UnsyncedSummary extends Equatable {
  const UnsyncedSummary({this.changes = 0, this.failedChanges = 0, this.conflicts = 0});

  /// Queued writes: links and categories created, edited or deleted here.
  final int changes;

  /// How many of [changes] failed their last attempt.
  final int failedChanges;

  /// Edits that collided with the cloud and wait for the user.
  final int conflicts;

  bool get isEmpty => changes == 0 && conflicts == 0;

  /// True if there is more unsynced work here than in [other], for example a
  /// link saved after the user was shown [other].
  bool hasMoreThan(UnsyncedSummary other) => changes > other.changes || conflicts > other.conflicts;

  @override
  List<Object?> get props => [changes, failedChanges, conflicts];
}

/// Everything the UI shows about sync, in one value.
class SyncSnapshot extends Equatable {
  const SyncSnapshot({
    this.status = SyncStatus.idle,
    this.pendingChanges = 0,
    this.conflicts = 0,
    this.lastSyncedAt,
    this.failure,
  });

  final SyncStatus status;

  /// Queued writes that have not reached the cloud yet.
  final int pendingChanges;

  /// Edits that collided with the cloud and wait for the user.
  final int conflicts;

  /// When the last successful pull finished, in milliseconds since the epoch.
  final int? lastSyncedAt;

  /// Set only while [status] is [SyncStatus.failed].
  final SyncFailure? failure;

  /// What would be lost if the phone were wiped now, as the user saw it.
  UnsyncedSummary get unsynced => UnsyncedSummary(changes: pendingChanges, conflicts: conflicts);

  @override
  List<Object?> get props => [status, pendingChanges, conflicts, lastSyncedAt, failure];
}
