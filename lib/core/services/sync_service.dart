import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../../features/links/repository/link_repository.dart';
import 'sync_engine.dart';

/// Background sync service that watches real internet connectivity.
///
/// Uses [InternetConnection] (from internet_connection_checker_plus) which
/// performs an actual HTTP/TCP check — not just OS hardware state.
/// When connectivity is restored and user is authenticated, pushes
/// pending local links to Firestore via [LinkRepository.syncPendingLinks].
class SyncService {
  final SyncEngine _syncEngine;
  StreamSubscription<InternetStatus>? _subscription;
  StreamSubscription<User?>? _authSubscription;
  bool _started = false;

  SyncService({required LinkRepository linkRepository, SyncEngine? syncEngine})
    : _syncEngine = syncEngine ?? SyncEngine(repository: linkRepository);

  void startListening() {
    if (_started) return;
    _started = true;

    final currentUser = FirebaseAuth.instance.currentUser;
    _syncEngine.setCloudWorkEnabled(currentUser != null);
    if (currentUser != null) _syncEngine.requestSync(pull: true);

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      final isAuthenticated = user != null;
      _syncEngine.setCloudWorkEnabled(isAuthenticated);
      if (isAuthenticated) _syncEngine.requestSync(pull: true);
    });

    _subscription = InternetConnection().onStatusChange.listen((status) async {
      if (status == InternetStatus.connected) {
        await _syncEngine.requestSync();
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _authSubscription?.cancel();
    _syncEngine.setCloudWorkEnabled(false);
    _syncEngine.dispose();
  }
}
