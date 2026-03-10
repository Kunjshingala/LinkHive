import 'package:equatable/equatable.dart';

/// Base class for all splash events
abstract class SplashEvent extends Equatable {
  const SplashEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered when splash screen is started
class SplashStarted extends SplashEvent {
  const SplashStarted();
}
