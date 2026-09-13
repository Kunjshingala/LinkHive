import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../features/links/repository/link_repository.dart';
import 'sync_status.dart';

/// Serializes cloud sync requests so only one push/pull run is active at once.
class SyncEngine {
  final LinkRepository _repository;
  final bool Function() _isAuthenticated;

  Future<void>? _activeRun;
  bool _cloudWorkEnabled = true;
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  SyncStatus _status = SyncStatus.idle;

  SyncEngine({
    required LinkRepository repository,
    bool Function()? isAuthenticated,
  }) : _repository = repository,
       _isAuthenticated =
           isAuthenticated ?? (() => FirebaseAuth.instance.currentUser != null);

  /// Enables or disables cloud work for the current authentication session.
  void setCloudWorkEnabled(bool enabled) {
    _cloudWorkEnabled = enabled;
  }

  SyncStatus get status => _status;

  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Requests a sync. Concurrent requests share the same in-flight future.
  Future<void> requestSync({bool pull = false}) {
    if (!_cloudWorkEnabled || !_isAuthenticated()) return Future<void>.value();

    final activeRun = _activeRun;
    if (activeRun != null) return activeRun;

    final run = _run(pull: pull);
    _activeRun = _clearActiveRun(run);
    return _activeRun!;
  }

  Future<void> _clearActiveRun(Future<void> run) async {
    try {
      await run;
    } finally {
      _activeRun = null;
    }
  }

  Future<void> _run({required bool pull}) async {
    _setStatus(SyncStatus.syncing);
    try {
      await _repository.syncPendingLinks();
      if (pull) await _repository.pullFromCloud();
      _setStatus(
        _repository.conflicts.isEmpty ? SyncStatus.idle : SyncStatus.conflict,
      );
    } catch (_) {
      _setStatus(SyncStatus.failed);
      rethrow;
    }
  }

  void _setStatus(SyncStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  Future<void> dispose() async {
    await _statusController.close();
  }
}
