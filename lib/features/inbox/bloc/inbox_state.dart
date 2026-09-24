part of 'inbox_bloc.dart';

sealed class InboxState extends Equatable {
  const InboxState();

  @override
  List<Object?> get props => [];
}

class InboxInitial extends InboxState {
  const InboxInitial();
}

class InboxLoading extends InboxState {
  const InboxLoading();
}

class InboxLoaded extends InboxState {
  const InboxLoaded({required this.links});

  final List<LinkModel> links;

  @override
  List<Object?> get props => [links];
}

class InboxError extends InboxState {
  const InboxError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
