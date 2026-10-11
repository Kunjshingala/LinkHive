import 'package:equatable/equatable.dart';

import '../../../core/services/sync_status.dart';

class SyncStatusState extends Equatable {
  final SyncSnapshot snapshot;

  const SyncStatusState(this.snapshot);

  SyncStatus get status => snapshot.status;

  @override
  List<Object?> get props => [snapshot];
}
