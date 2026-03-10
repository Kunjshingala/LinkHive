import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../../features/links/repository/link_repository.dart';
import '../utils/utils.dart';

/// Background sync service that watches real internet connectivity.
///
/// Uses [InternetConnection] (from internet_connection_checker_plus) which
/// performs an actual HTTP/TCP check — not just OS hardware state.
/// When connectivity is restored and user is authenticated, pushes
/// pending local links to Firestore via [LinkRepository.syncPendingLinks].
class SyncService {
  final LinkRepository _linkRepository;
  StreamSubscription<InternetStatus>? _subscription;

  SyncService({required LinkRepository linkRepository}) : _linkRepository = linkRepository;

  void startListening() {
    _subscription = InternetConnection().onStatusChange.listen((status) async {
      if (status == InternetStatus.connected) {
        printLog(tag: 'SyncService', msg: 'Internet connected — syncing pending links');
        await _syncIfAuthenticated();
      }
    });
  }

  Future<void> _syncIfAuthenticated() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _linkRepository.syncPendingLinks();
  }

  void dispose() {
    _subscription?.cancel();
  }
}
