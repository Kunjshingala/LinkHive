import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../links/manager/link_manager.dart';

/// How many quick-saved links wait in the Inbox, for the tab's badge.
///
/// Emits only when the number changes, so other link edits don't rebuild the
/// bottom nav.
class InboxBadgeCubit extends Cubit<int> {
  InboxBadgeCubit({required LinkManager manager})
    : _manager = manager,
      super(manager.inboxCount) {
    _subscription = _manager.watchLinks().listen(
      (_) => emit(_manager.inboxCount),
    );
  }

  final LinkManager _manager;
  late final StreamSubscription<void> _subscription;

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
