import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../../features/links/repository/link_repository.dart';
import '../utils/utils.dart';
import 'sync_engine.dart';

/// Background sync service that watches real internet connectivity.
///
/// Uses [InternetConnection] (from internet_connection_checker_plus) which
/// performs an actual HTTP/TCP check — not just OS hardware state.
/// It tells the [SyncEngine] whether the phone is online, and when the
/// connection returns and the user is authenticated, pushes pending local
/// links to Firestore.
class SyncService {
  final SyncEngine _syncEngine;
  final Stream<InternetStatus>? _connectivityChanges;
  final Future<bool> Function()? _hasInternetAccess;
  final Stream<User?>? _authChanges;
  final User? Function()? _currentUser;

  StreamSubscription<InternetStatus>? _subscription;
  StreamSubscription<User?>? _authSubscription;
  Timer? _periodicTimer;
  bool _started = false;

  /// The optional stream and function parameters replace the real connectivity
  /// and Firebase Auth sources, so the service can be tested without them.
  SyncService({
    required LinkRepository linkRepository,
    SyncEngine? syncEngine,
    Stream<InternetStatus>? connectivityChanges,
    Future<bool> Function()? hasInternetAccess,
    Stream<User?>? authChanges,
    User? Function()? currentUser,
  }) : _syncEngine = syncEngine ?? SyncEngine(repository: linkRepository),
       _connectivityChanges = connectivityChanges,
       _hasInternetAccess = hasInternetAccess,
       _authChanges = authChanges,
       _currentUser = currentUser;

  void startListening() {
    if (_started) return;
    _started = true;

    final currentUser = (_currentUser ?? _firebaseCurrentUser)();
    _syncEngine.setCloudWorkEnabled(currentUser != null);
    if (currentUser != null) requestSyncInBackground(pull: true);

    _authSubscription =
        (_authChanges ?? FirebaseAuth.instance.authStateChanges()).listen((
          user,
        ) {
          final isAuthenticated = user != null;
          _syncEngine.setCloudWorkEnabled(isAuthenticated);
          if (isAuthenticated) requestSyncInBackground(pull: true);
        });

    _checkConnectivityNow();
    _subscription =
        (_connectivityChanges ?? InternetConnection().onStatusChange).listen((
          status,
        ) {
          final online = status == InternetStatus.connected;
          _syncEngine.setOnline(online);
          if (online) requestSyncInBackground();
        });

    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => requestSyncInBackground(),
    );
  }

  User? _firebaseCurrentUser() => FirebaseAuth.instance.currentUser;

  /// Learns the connection once at start, before the first change event.
  /// If the check itself fails the engine keeps assuming the phone is online.
  void _checkConnectivityNow() {
    final hasInternet =
        _hasInternetAccess ?? (() => InternetConnection().hasInternetAccess);
    unawaited(
      hasInternet().then(
        _syncEngine.setOnline,
        onError: (Object error) {
          printLog(
            tag: 'SyncService',
            msg: 'Connectivity check failed: $error',
          );
        },
      ),
    );
  }

  Future<void> requestSync({bool pull = false}) =>
      _syncEngine.requestSync(pull: pull);

  /// Starts a sync that nobody waits for. A failure is logged here and shown
  /// through the sync status, so it never becomes an unhandled error.
  void requestSyncInBackground({bool pull = false}) {
    unawaited(
      _syncEngine.requestSync(pull: pull).catchError((Object error) {
        printLog(tag: 'SyncService', msg: 'Background sync failed: $error');
      }),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _authSubscription?.cancel();
    _periodicTimer?.cancel();
    _syncEngine.setCloudWorkEnabled(false);
    _syncEngine.dispose();
  }
}
