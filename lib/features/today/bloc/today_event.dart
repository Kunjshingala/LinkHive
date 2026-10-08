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
///
/// [url] is a version picked in the "Which version?" sheet (defaults to the
/// link's main URL); [keepOnly] first makes it the link's only URL.
class TodayOpenRequested extends TodayEvent {
  const TodayOpenRequested({this.url, this.keepOnly = false});

  final String? url;
  final bool keepOnly;

  @override
  List<Object?> get props => [url, keepOnly];
}

/// Marks the current candidate consumed without opening it.
class TodayArchiveRequested extends TodayEvent {
  const TodayArchiveRequested();
}

/// Leaves the current candidate unread but moves it out of today's pick.
class TodaySnoozeRequested extends TodayEvent {
  const TodaySnoozeRequested();
}
