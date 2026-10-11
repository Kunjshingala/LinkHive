import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

import '../../features/links/repository/link_repository.dart';
import 'sync_status.dart';

/// Serializes cloud sync requests so only one push/pull run is active at once,
/// and reports what is really happening as a [SyncSnapshot].
class SyncEngine {
  final LinkRepository _repository;
  final bool Function() _isAuthenticated;

  Future<void>? _activeRun;
  bool _activeRunPulls = false;
  Future<void>? _queuedPull;
  bool _running = false;
  bool _cloudWorkEnabled = true;
  bool _paused = false;

  /// Assumed online until [setOnline] says otherwise.
  bool _online = true;
  SyncFailure? _runFailure;

  final StreamController<SyncSnapshot> _changes =
      StreamController<SyncSnapshot>.broadcast();

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

  /// Tells the engine whether the phone can reach the internet.
  void setOnline(bool online) {
    if (_online == online) return;
    _online = online;
    _emit();
  }

  /// Refuses new sync runs until [resume], for example while the phone is
  /// being wiped. A run that is already going keeps going; the repository's
  /// wipe guard stops its local writes.
  void pause() {
    _paused = true;
  }

  void resume() {
    _paused = false;
  }

  SyncStatus get status => snapshot.status;

  /// What the UI shows about sync right now.
  SyncSnapshot get snapshot {
    final summary = _repository.unsyncedSummary();
    final failure = _runFailure ?? _repository.lastFailure;
    final hasFailure = failure != null || summary.failedChanges > 0;
    final status = _statusFor(summary, hasFailure: hasFailure);
    return SyncSnapshot(
      status: status,
      pendingChanges: summary.changes,
      lastSyncedAt: _repository.lastPulledAt,
      failure: status == SyncStatus.failed
          ? (failure ?? SyncFailure.unknown)
          : null,
    );
  }

  /// A new snapshot whenever something it shows changes: the engine's own state
  /// or the queue of unsynced writes. Read [snapshot] for the current one.
  Stream<SyncSnapshot> watch() => Rx.merge<Object?>([
    _changes.stream,
    _repository.watchSyncOperations(),
  ]).map((_) => snapshot).distinct();

  SyncStatus _statusFor(UnsyncedSummary summary, {required bool hasFailure}) {
    if (summary.conflicts > 0) return SyncStatus.conflict;
    // Offline is a state of its own, never a failure and never "syncing".
    if (!_online) {
      return summary.changes > 0
          ? SyncStatus.waitingForInternet
          : SyncStatus.idle;
    }
    if (_running) return SyncStatus.syncing;
    if (hasFailure) return SyncStatus.failed;
    return SyncStatus.idle;
  }

  /// Requests a sync. Concurrent requests share the same in-flight future.
  ///
  /// A pull requested while a push-only run is going is not dropped: it runs
  /// right after that run.
  Future<void> requestSync({bool pull = false}) {
    if (!_cloudWorkEnabled || _paused || !_isAuthenticated()) {
      return Future<void>.value();
    }

    final activeRun = _activeRun;
    if (activeRun == null) return _start(pull: pull);
    if (!pull || _activeRunPulls) return activeRun;
    return _queuedPull ??= _pullAfter(activeRun);
  }

  Future<void> _start({required bool pull}) {
    _activeRunPulls = pull;
    final run = _clearActiveRun(_run(pull: pull));
    _activeRun = run;
    return run;
  }

  Future<void> _pullAfter(Future<void> activeRun) async {
    try {
      await activeRun;
    } on Object {
      // The callers of that run see its error; the pull still gets its turn.
    }
    _queuedPull = null;
    await requestSync(pull: true);
  }

  Future<void> _clearActiveRun(Future<void> run) async {
    try {
      await run;
    } finally {
      _activeRun = null;
    }
  }

  Future<void> _run({required bool pull}) async {
    _running = true;
    _runFailure = null;
    _emit();
    try {
      await _repository.syncPendingLinks();
      if (pull) await _repository.pullFromCloud();
    } catch (error) {
      _runFailure = SyncFailure.fromError(error);
      rethrow;
    } finally {
      _running = false;
      _emit();
    }
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(snapshot);
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}
