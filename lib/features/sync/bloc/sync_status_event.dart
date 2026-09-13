import 'package:equatable/equatable.dart';

import '../../../core/services/sync_status.dart';

sealed class SyncStatusEvent extends Equatable {
  const SyncStatusEvent();

  @override
  List<Object?> get props => [];
}

class SyncStatusChanged extends SyncStatusEvent {
  final SyncStatus status;

  const SyncStatusChanged(this.status);

  @override
  List<Object?> get props => [status];
}
