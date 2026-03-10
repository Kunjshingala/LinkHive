import 'package:equatable/equatable.dart';

/// Base class for all authentication states
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state when authentication has not started
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// State when authentication operation is in progress
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// State when authentication operation completed successfully
class AuthSuccess extends AuthState {
  const AuthSuccess();
}

/// State when authentication operation failed
class AuthError extends AuthState {
  final String message;
  final Exception? exception;

  const AuthError({required this.message, this.exception});

  @override
  List<Object?> get props => [message, exception];
}
