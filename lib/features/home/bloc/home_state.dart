import 'package:equatable/equatable.dart';

/// Base class for all home states
abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class HomeInitial extends HomeState {
  const HomeInitial();
}

/// State after first back press - user should see "press again to exit" message
class HomeBackPressedOnce extends HomeState {
  final DateTime pressTime;

  const HomeBackPressedOnce({required this.pressTime});

  @override
  List<Object?> get props => [pressTime];
}

/// State when user can exit (second press within timeout)
class HomeCanExit extends HomeState {
  const HomeCanExit();
}
