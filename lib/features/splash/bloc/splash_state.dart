import 'package:equatable/equatable.dart';

/// Base class for all splash states
abstract class SplashState extends Equatable {
  const SplashState();

  @override
  List<Object?> get props => [];
}

/// Initial state before splash starts
class SplashInitial extends SplashState {
  const SplashInitial();
}

/// State while showing splash screen
class SplashLoading extends SplashState {
  const SplashLoading();
}

/// State when splash is complete and ready to navigate
class SplashComplete extends SplashState {
  const SplashComplete();
}
