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
  const AccountSignOutRequested();
}

class AccountGoogleSignInRequested extends AccountEvent {
  const AccountGoogleSignInRequested();
}
