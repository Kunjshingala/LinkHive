import 'package:equatable/equatable.dart';

import '../../../core/services/sync_status.dart';

sealed class SyncStatusEvent extends Equatable {
  const SyncStatusEvent();

  @override
  List<Object?> get props => [];
}

class SyncStatusChanged extends SyncStatusEvent {
  final SyncSnapshot snapshot;

  const SyncStatusChanged(this.snapshot);

  @override
  List<Object?> get props => [snapshot];
}
