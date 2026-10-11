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

/// Signs out and removes this phone's copy of the data.
class AccountSignOutRequested extends AccountEvent {
  /// What the user was shown when they confirmed. A sign-out that would lose
  /// more than this is not carried out.
  final UnsyncedSummary confirmed;

  const AccountSignOutRequested({required this.confirmed});

  @override
  List<Object?> get props => [confirmed];
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
