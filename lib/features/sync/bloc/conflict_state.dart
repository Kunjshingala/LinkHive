import 'package:equatable/equatable.dart';

import '../../../core/models/conflict_record.dart';

sealed class ConflictState extends Equatable {
  const ConflictState();

  @override
  List<Object?> get props => [];
}

class ConflictInitial extends ConflictState {
  const ConflictInitial();
}

class ConflictLoading extends ConflictState {
  const ConflictLoading();
}

class ConflictLoaded extends ConflictState {
  final List<ConflictRecord> conflicts;

  const ConflictLoaded(this.conflicts);

  @override
  List<Object?> get props => [conflicts];
}

class ConflictError extends ConflictState {
  final String message;

  const ConflictError(this.message);

  @override
  List<Object?> get props => [message];
}
