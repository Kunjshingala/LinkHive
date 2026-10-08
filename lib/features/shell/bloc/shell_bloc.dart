import 'package:flutter_bloc/flutter_bloc.dart';

import 'shell_event.dart';
import 'shell_state.dart';

/// BLoC that handles the tab shell's back button: press twice to exit
class ShellBloc extends Bloc<ShellEvent, ShellState> {
  static const _backPressTimeout = Duration(seconds: 3);

  ShellBloc() : super(const ShellInitial()) {
    on<ShellBackPressed>(_onBackPressed);
  }

  /// Handle back button press
  /// First press: show message and update state
  /// Second press within timeout: allow exit
  void _onBackPressed(ShellBackPressed event, Emitter<ShellState> emit) {
    final currentState = state;

    if (currentState is ShellBackPressedOnce) {
      final now = DateTime.now();
      final difference = now.difference(currentState.pressTime);

      if (difference > _backPressTimeout) {
        // Timeout passed, treat as first press again
        emit(ShellBackPressedOnce(pressTime: now));
      } else {
        // Within timeout, allow exit
        emit(const ShellCanExit());
      }
    } else {
      // First press
      emit(ShellBackPressedOnce(pressTime: DateTime.now()));
    }
  }
}
