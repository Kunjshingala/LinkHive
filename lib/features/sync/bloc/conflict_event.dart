import 'package:equatable/equatable.dart';

sealed class ConflictEvent extends Equatable {
  const ConflictEvent();

  @override
  List<Object?> get props => [];
}

class ConflictLoadRequested extends ConflictEvent {
  const ConflictLoadRequested();
}

class ConflictKeepLocalRequested extends ConflictEvent {
  final String conflictId;

  const ConflictKeepLocalRequested(this.conflictId);

  @override
  List<Object?> get props => [conflictId];
}

class ConflictKeepCloudRequested extends ConflictEvent {
  final String conflictId;

  const ConflictKeepCloudRequested(this.conflictId);

  @override
  List<Object?> get props => [conflictId];
}
