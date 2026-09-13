import 'package:firebase_auth/firebase_auth.dart';

import '../../features/links/repository/link_repository.dart';

/// Serializes cloud sync requests so only one push/pull run is active at once.
class SyncEngine {
  final LinkRepository _repository;
  final bool Function() _isAuthenticated;

  Future<void>? _activeRun;
  bool _cloudWorkEnabled = true;

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
    await _repository.syncPendingLinks();
    if (pull) await _repository.pullFromCloud();
  }
}
