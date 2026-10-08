import 'package:equatable/equatable.dart';

/// Base class for all shell events
abstract class ShellEvent extends Equatable {
  const ShellEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered when back button is pressed
class ShellBackPressed extends ShellEvent {
  const ShellBackPressed();
}
