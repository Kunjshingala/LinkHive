part of 'inbox_bloc.dart';

sealed class InboxEvent extends Equatable {
  const InboxEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the quick-saved links. [silent] skips the loading spinner for
/// background refreshes triggered by the box subscription.
class InboxLoadRequested extends InboxEvent {
  const InboxLoadRequested({this.silent = false});

  final bool silent;

  @override
  List<Object?> get props => [silent];
}

/// Deletes a quick-saved link straight from the Inbox.
class InboxLinkDeleted extends InboxEvent {
  const InboxLinkDeleted({required this.linkId});

  final String linkId;

  @override
  List<Object?> get props => [linkId];
}
