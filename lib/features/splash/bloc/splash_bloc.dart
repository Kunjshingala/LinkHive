import 'package:flutter_bloc/flutter_bloc.dart';

import 'splash_event.dart';
import 'splash_state.dart';

/// BLoC that handles splash screen logic including timer
class SplashBloc extends Bloc<SplashEvent, SplashState> {
  static const _splashDuration = Duration(seconds: 3);

  SplashBloc() : super(const SplashInitial()) {
    on<SplashStarted>(_onStarted);
  }

  /// Handle splash started event
  /// Wait for 3 seconds then emit complete state
  Future<void> _onStarted(
    SplashStarted event,
    Emitter<SplashState> emit,
  ) async {
    emit(const SplashLoading());
    await Future.delayed(_splashDuration);
    // The splash can be replaced before the timer fires — e.g. a cold-start
    // share routes to Home + AddLink. Don't emit (which would navigate Home and
    // clobber that screen) once this bloc has been closed.
    if (isClosed) return;
    emit(const SplashComplete());
  }
}
