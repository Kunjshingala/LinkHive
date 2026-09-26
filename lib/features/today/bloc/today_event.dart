part of 'today_bloc.dart';

sealed class TodayEvent extends Equatable {
  const TodayEvent();

  @override
  List<Object?> get props => [];
}

class TodayLoadRequested extends TodayEvent {
  const TodayLoadRequested();
}

/// Opens the current candidate's URL and marks it consumed.
class TodayOpenRequested extends TodayEvent {
  const TodayOpenRequested();
}

/// Marks the current candidate consumed without opening it.
class TodayArchiveRequested extends TodayEvent {
  const TodayArchiveRequested();
}

/// Leaves the current candidate unread but moves it out of today's pick.
class TodaySnoozeRequested extends TodayEvent {
  const TodaySnoozeRequested();
}
