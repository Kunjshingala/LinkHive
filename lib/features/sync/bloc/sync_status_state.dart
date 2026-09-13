import 'package:equatable/equatable.dart';

import '../../../core/services/sync_status.dart';

class SyncStatusState extends Equatable {
  final SyncStatus status;

  const SyncStatusState(this.status);

  @override
  List<Object?> get props => [status];
}
