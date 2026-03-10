import 'package:equatable/equatable.dart';

/// Base class for all home events
abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered when back button is pressed
class HomeBackPressed extends HomeEvent {
  const HomeBackPressed();
}
