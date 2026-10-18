import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/extensions/context_extension.dart';
import '../../core/services/sync_engine.dart';
import '../../core/services/sync_service.dart';
import '../../core/utils/locator.dart';
import '../../core/utils/utils.dart';
import 'bloc/account_bloc.dart';
import 'bloc/account_event.dart';
import 'sync_result_sheet.dart';

/// The "Sync Data" action: sync now, then tell the user how it went.
///
/// The result sheet can ask to check everything again, which downloads all
/// links from the cloud rather than only what changed. A failure is read from
/// the sync state, so the sheet says the same thing as the status card.
Future<void> runSyncDataFlow(BuildContext context) async {
  var checkEverything = false;

  while (true) {
    final l10n = context.l10n;
    final sync = locator<SyncService>();
    showSnackBar(checkEverything ? l10n.accountSyncCheckingMsg : l10n.accountSyncingMsg);
    try {
      await (checkEverything ? sync.requestFullResync() : sync.requestSync(pull: true));
    } catch (error) {
      printLog(tag: 'SyncData', msg: 'Sync failed: $error');
    }
    if (!context.mounted) return;

    context.read<AccountBloc>().add(const AccountLoadRequested());
    final again = await showSyncResultSheet(context, locator<SyncEngine>().snapshot);
    if (again != true || !context.mounted) return;
    checkEverything = true;
  }
}
