import 'package:flutter_bloc/flutter_bloc.dart';

import 'home_event.dart';
import 'home_state.dart';

/// BLoC that handles home screen business logic including back button handling
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  static const _backPressTimeout = Duration(seconds: 3);

  HomeBloc() : super(const HomeInitial()) {
    on<HomeBackPressed>(_onBackPressed);
  }

  /// Handle back button press
  /// First press: show message and update state
  /// Second press within timeout: allow exit
  void _onBackPressed(HomeBackPressed event, Emitter<HomeState> emit) {
    final currentState = state;

    if (currentState is HomeBackPressedOnce) {
      final now = DateTime.now();
      final difference = now.difference(currentState.pressTime);

      if (difference > _backPressTimeout) {
        // Timeout passed, treat as first press again
        emit(HomeBackPressedOnce(pressTime: now));
      } else {
        // Within timeout, allow exit
        emit(const HomeCanExit());
      }
    } else {
      // First press
      emit(HomeBackPressedOnce(pressTime: DateTime.now()));
    }
  }
}
