import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_enums.dart';
import '../../core/extensions/context_extension.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/locator.dart';
import '../../core/utils/navigation/route.dart';
import '../../sharedWidgets/common_app_bar.dart';
import '../../sharedWidgets/confirmation_bottom_sheet.dart';
import '../../sharedWidgets/custom_button.dart';
import '../../sharedWidgets/empty_state.dart';
import '../../sharedWidgets/link_card.dart';
import '../links/models/link_model.dart';
import '../links/repository/link_repository.dart';
import 'bloc/inbox_bloc.dart';

/// The Inbox: quick-saved links waiting to be organized.
///
/// Each item can be **organized** (Add details → the edit form, which promotes
/// it out of the Inbox) or **deleted**. Reached from the Home app-bar Inbox
/// button.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          InboxBloc(repository: locator<LinkRepository>())..add(const InboxLoadRequested()),
      child: const _InboxContent(),
    );
  }
}

class _InboxContent extends StatelessWidget {
  const _InboxContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CommonAppBar(titleText: context.l10n.inboxTitle),
      body: SafeArea(
        top: false,
        child: BlocBuilder<InboxBloc, InboxState>(
          builder: (context, state) {
            return switch (state) {
              InboxInitial() || InboxLoading() => Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              InboxLoaded(:final links) => links.isEmpty
                  ? EmptyState(
                      icon: Icons.inbox_rounded,
                      title: context.l10n.inboxEmptyTitle,
                      subtitle: context.l10n.inboxEmptySubtitle,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageH,
                        AppSpacing.lg,
                        AppSpacing.pageH,
                        AppSpacing.xxl,
                      ),
                      itemCount: links.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
                      itemBuilder: (context, index) => _InboxItem(link: links[index]),
                    ),
              InboxError(:final message) => Center(child: Text(message)),
            };
          },
        ),
      ),
    );
  }
}

/// A single Inbox row: the standard link card plus the two first-class actions
/// an Inbox needs — organize (Add details) and delete.
class _InboxItem extends StatelessWidget {
  final LinkModel link;
  const _InboxItem({required this.link});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reuse the standard card visual. onEdit/onDelete are null so the card's
        // own 3-dot menu is hidden — the Inbox exposes those actions as the
        // explicit buttons below instead.
        LinkCard(link: link),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: NeoBrutalistButton(
                text: context.l10n.sharedAddDetails,
                icon: Icons.tune_rounded,
                height: 44,
                shadowColor: AppColors.success,
                onPressed: () => context.pushNamed(MyRouteName.editLink, extra: link),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            NeoBrutalistButton(
              icon: Icons.delete_outline_rounded,
              height: 44,
              variant: ButtonVariant.outlined,
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showConfirmationBottomSheet(
      context: context,
      title: context.l10n.linkDeleteTitle,
      message: context.l10n.linkDeleteMessage,
      confirmLabel: context.l10n.linkDeleteLabel,
      cancelLabel: context.l10n.accountCancel,
      titleIcon: Icons.warning_amber_rounded,
      isDestructive: true,
    );
    if (confirm == true && context.mounted) {
      context.read<InboxBloc>().add(InboxLinkDeleted(linkId: link.id));
    }
  }
}
