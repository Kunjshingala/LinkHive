import 'package:equatable/equatable.dart';

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
