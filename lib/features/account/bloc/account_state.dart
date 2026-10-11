import 'package:equatable/equatable.dart';

import 'package:firebase_auth/firebase_auth.dart';

abstract class AccountState extends Equatable {
  const AccountState();

  @override
  List<Object?> get props => [];
}

class AccountInitial extends AccountState {
  const AccountInitial();
}

class AccountAuthenticated extends AccountState {
  final User user;
  final int totalLinks;
  final int syncedLinks;
  final int unsyncedLinks;

  const AccountAuthenticated(this.user, {this.totalLinks = 0, this.syncedLinks = 0, this.unsyncedLinks = 0});

  @override
  List<Object?> get props => [user.uid, totalLinks, syncedLinks, unsyncedLinks];
}

class AccountGuest extends AccountState {
  final int totalLinks;
  final int syncedLinks;
  final int unsyncedLinks;

  const AccountGuest({this.totalLinks = 0, this.syncedLinks = 0, this.unsyncedLinks = 0});

  @override
  List<Object?> get props => [totalLinks, syncedLinks, unsyncedLinks];
}

class AccountLoading extends AccountState {
  const AccountLoading();
}

class AccountSignedOut extends AccountState {
  const AccountSignedOut();
}

class AccountError extends AccountState {
  final String message;
  const AccountError(this.message);

  @override
  List<Object?> get props => [message];
}

/// This phone's copy of the data was removed. The account stays signed in.
class AccountLocalWiped extends AccountState {
  const AccountLocalWiped();
}

/// The account's cloud data and this phone's copy were deleted.
class AccountCloudDeleted extends AccountState {
  const AccountCloudDeleted();
}

/// There is more unsynced work than the user was shown, so nothing was changed.
class AccountNeedsReconfirmation extends AccountState {
  const AccountNeedsReconfirmation();
}

/// What the user asked for when an [AccountActionFailed] happened.
enum AccountAction { wipeLocal, deleteCloud }

/// A wipe failed part-way. Sync is allowed again; the wipe can be retried.
class AccountActionFailed extends AccountState {
  final AccountAction action;
  const AccountActionFailed(this.action);

  @override
  List<Object?> get props => [action];
}
