import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// BlocObserver for debugging bloc events and state changes
class AppBlocObserver extends BlocObserver {
  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    if (kDebugMode) {
      debugPrint('🔵 Event: $event in ${bloc.runtimeType}');
    }
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    if (kDebugMode) {
      debugPrint('🟢 Transition: ${bloc.runtimeType}');
      debugPrint('   From: ${transition.currentState}');
      debugPrint('   To: ${transition.nextState}');
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    if (kDebugMode) {
      debugPrint('🔴 Error in ${bloc.runtimeType}: $error');
    }
  }
}
