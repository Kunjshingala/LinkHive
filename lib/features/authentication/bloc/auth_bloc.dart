import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC that handles all authentication-related business logic
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc({required AuthService authService}) : _authService = authService, super(const AuthInitial()) {
    // Register event handlers
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  /// Handle email/password sign in
  Future<void> _onSignInRequested(AuthSignInRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      await _authService.signInWithEmailPassword(event.email, event.password);
      emit(const AuthSuccess());
    } on Exception catch (e) {
      emit(AuthError(message: e.toString(), exception: e));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Handle email/password sign up
  Future<void> _onSignUpRequested(AuthSignUpRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      await _authService.signUpWithEmailPassword(event.email, event.password);
      emit(const AuthSuccess());
    } on Exception catch (e) {
      emit(AuthError(message: e.toString(), exception: e));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Handle Google sign in
  Future<void> _onGoogleSignInRequested(AuthGoogleSignInRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      await _authService.signInWithGoogle();
      emit(const AuthSuccess());
    } on Exception catch (e) {
      emit(AuthError(message: e.toString(), exception: e));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Handle sign out
  Future<void> _onSignOutRequested(AuthSignOutRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      await _authService.signOut();
      emit(const AuthInitial());
    } on Exception catch (e) {
      emit(AuthError(message: e.toString(), exception: e));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }
}
