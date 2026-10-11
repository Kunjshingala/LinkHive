import 'package:equatable/equatable.dart';

import '../../../core/services/sync_status.dart';

abstract class AccountEvent extends Equatable {
  const AccountEvent();

  @override
  List<Object?> get props => [];
}

class AccountLoadRequested extends AccountEvent {
  const AccountLoadRequested();
}

class AccountSignOutRequested extends AccountEvent {
  final bool clearLocal;
  final bool clearRemote;

  const AccountSignOutRequested({this.clearLocal = false, this.clearRemote = false});

  @override
  List<Object?> get props => [clearLocal, clearRemote];
}

class AccountGoogleSignInRequested extends AccountEvent {
  const AccountGoogleSignInRequested();
}

/// Removes this phone's copy of the data and stays signed in.
class AccountWipeLocalRequested extends AccountEvent {
  /// What the user was shown when they confirmed. A wipe that would lose more
  /// than this is not carried out.
  final UnsyncedSummary confirmed;

  const AccountWipeLocalRequested({required this.confirmed});

  @override
  List<Object?> get props => [confirmed];
}

/// Deletes the account's data in the cloud, and this phone's copy.
class AccountDeleteCloudDataRequested extends AccountEvent {
  final UnsyncedSummary confirmed;

  const AccountDeleteCloudDataRequested({required this.confirmed});

  @override
  List<Object?> get props => [confirmed];
}
