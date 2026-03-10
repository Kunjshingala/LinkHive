import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/utils/utils.dart';
import '../../links/repository/link_repository.dart';
import 'account_event.dart';
import 'account_state.dart';

/// BLoC for the Account screen — manages auth state display and sign-in/out.
class AccountBloc extends Bloc<AccountEvent, AccountState> {
  final AuthService _authService;
  final LinkRepository _linkRepository;

  AccountBloc({required AuthService authService, required LinkRepository linkRepository})
    : _authService = authService,
      _linkRepository = linkRepository,
      super(const AccountInitial()) {
    on<AccountLoadRequested>(_onLoad);
    on<AccountSignOutRequested>(_onSignOutRequested);
    on<AccountGoogleSignInRequested>(_onGoogleSignIn);

    // Kick off by dispatching a load event so state is emitted via the handler
    add(const AccountLoadRequested());
  }

  void _onLoad(AccountLoadRequested event, Emitter<AccountState> emit) {
    final user = FirebaseAuth.instance.currentUser;
    final (total, synced, unsynced) = _linkRepository.getLinkStats();

    if (user != null) {
      emit(AccountAuthenticated(user, totalLinks: total, syncedLinks: synced, unsyncedLinks: unsynced));
    } else {
      emit(AccountGuest(totalLinks: total, syncedLinks: synced, unsyncedLinks: unsynced));
    }
  }

  Future<void> _onSignOutRequested(AccountSignOutRequested event, Emitter<AccountState> emit) async {
    emit(const AccountLoading());
    try {
      await _authService.signOut();
      emit(const AccountSignedOut());
    } catch (e) {
      emit(AccountError('Sign out failed: $e'));
    }
  }

  Future<void> _onGoogleSignIn(AccountGoogleSignInRequested event, Emitter<AccountState> emit) async {
    emit(const AccountLoading());
    try {
      await _authService.signInWithGoogle();
      final user = FirebaseAuth.instance.currentUser;

      // Sync any links the user saved while browsing as a guest.
      // We fire-and-forget here — failures are logged inside syncPendingLinks.
      if (user != null) {
        unawaited(_linkRepository.syncPendingLinks());
      }

      final (total, synced, unsynced) = _linkRepository.getLinkStats();
      if (user != null) {
        emit(AccountAuthenticated(user, totalLinks: total, syncedLinks: synced, unsyncedLinks: unsynced));
      } else {
        emit(AccountGuest(totalLinks: total, syncedLinks: synced, unsyncedLinks: unsynced));
      }
    } catch (e) {
      printLog(tag: 'AccountBloc', msg: 'Google sign-in error: $e');
      emit(AccountError(e.toString()));
    }
  }
}
