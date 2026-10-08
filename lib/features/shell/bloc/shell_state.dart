import 'package:equatable/equatable.dart';

/// Base class for all shell states
abstract class ShellState extends Equatable {
  const ShellState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class ShellInitial extends ShellState {
  const ShellInitial();
}

/// State after first back press - user should see "press again to exit" message
class ShellBackPressedOnce extends ShellState {
  final DateTime pressTime;

  const ShellBackPressedOnce({required this.pressTime});

  @override
  List<Object?> get props => [pressTime];
}

/// State when user can exit (second press within timeout)
class ShellCanExit extends ShellState {
  const ShellCanExit();
}
