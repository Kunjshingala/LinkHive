import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/extensions/context_extension.dart';
import '../../core/services/sync_status.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../sharedWidgets/custom_button.dart';
import '../sync/bloc/sync_status_bloc.dart';
import '../sync/bloc/sync_status_state.dart';
import 'sync_description.dart';

/// The one place the Account screen tells the user how sync is going.
///
/// Signed in, it follows the sync engine: what is happening, why a sync
/// failed, how many changes are still on this phone, and when the last sync
/// finished. As a guest nothing syncs, so it says the links are only here.
class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({
    super.key,
    required this.isSignedIn,
    required this.onRetry,
  });

  final bool isSignedIn;

  /// Called by the Retry button, shown only after a failed sync.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!isSignedIn) {
      return _CardShell(
        icon: Icons.phone_android_rounded,
        title: context.l10n.accountStatLocal,
      );
    }

    return BlocBuilder<SyncStatusBloc, SyncStatusState>(
      builder: (context, state) {
        final snapshot = state.snapshot;
        final description = describeSync(context, snapshot);
        return _CardShell(
          icon: description.icon,
          title: description.title,
          details: description.details,
          onRetry: snapshot.status == SyncStatus.failed ? onRetry : null,
        );
      },
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.icon,
    required this.title,
    this.details = const [],
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final List<String> details;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline, width: 2),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.titleSmall),
                    for (final line in details) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        line,
                        style: AppTypography.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            NeoBrutalistButton(
              text: context.l10n.accountRetry,
              icon: Icons.refresh_rounded,
              height: 44,
              onPressed: onRetry!,
            ),
          ],
        ],
      ),
    );
  }
}
