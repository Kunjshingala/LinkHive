part of 'today_bloc.dart';

sealed class TodayState extends Equatable {
  const TodayState();

  @override
  List<Object?> get props => [];
}

class TodayInitial extends TodayState {
  const TodayInitial();
}

class TodayLoading extends TodayState {
  const TodayLoading();
}

class TodayLoaded extends TodayState {
  const TodayLoaded(this.link);

  final LinkModel link;

  @override
  List<Object?> get props => [link];
}

/// Nothing left to resurface — every saved link has been read.
class TodayEmpty extends TodayState {
  const TodayEmpty();
}
