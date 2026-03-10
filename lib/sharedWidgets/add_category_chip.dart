import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/extensions/context_extension.dart';
import '../l10n/localization/app_localizations.dart';
import '../features/links/bloc/link_bloc.dart';
import '../features/links/bloc/link_event.dart';

/// A "＋ New" pill chip that opens a **bottom sheet** for the user to
/// create a custom category on the fly.
///
/// Uses [showModalBottomSheet] to comply with the project constraint that all
/// app popups must be presented as bottom sheets (not dialogs).
///
/// Used in both [AddLinkScreen] (category multi-select) and [HomeScreen]
/// (category filter row).
///
/// The [onAdd] callback is invoked with the trimmed, non-empty name the user
/// typed. The caller is responsible for dispatching [LinkCustomCategoryAdded]
/// to the [LinkBloc].
class AddCategoryChip extends StatelessWidget {
  final void Function(String name) onAdd;

  const AddCategoryChip({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final neo = context.neoBrutal;

    return GestureDetector(
      onTap: () => _showBottomSheet(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: neo.borderColor, width: neo.borderWidth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: cs.primary),
            const SizedBox(width: 4),
            Text(
              context.l10n.newCategoryTitle,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBottomSheet(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      // Use a StatefulWidget so the TextEditingController is owned and
      // disposed by the widget tree — not by us after the await returns.
      // Disposing after await causes a crash because the bottom sheet's
      // closing animation still runs one more frame after the Future resolves,
      // and Flutter tries to rebuild the TextField with the dead controller.
      builder: (_) => _AddCategorySheetContent(l10n: context.l10n),
    );

    if (result != null && result.isNotEmpty) {
      onAdd(result);
    }
  }
}

// ─── Bottom sheet content ─────────────────────────────────────────────────────

/// The actual bottom-sheet UI for creating a new custom category.
///
/// Owns its [TextEditingController] as a [StatefulWidget] so the controller
/// is disposed in [dispose()] — i.e., when Flutter removes the widget from the
/// tree after the closing animation finishes — rather than immediately when the
/// `await showModalBottomSheet(...)` call resolves.
class _AddCategorySheetContent extends StatefulWidget {
  final AppLocalizations l10n;

  const _AddCategorySheetContent({required this.l10n});

  @override
  State<_AddCategorySheetContent> createState() => _AddCategorySheetContentState();
}

class _AddCategorySheetContentState extends State<_AddCategorySheetContent> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose(); // safe: called after the widget leaves the tree
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    if (_ctrl.text.trim().isNotEmpty) {
      Navigator.of(ctx).pop(_ctrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pageH,
        right: AppSpacing.pageH,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),

          Text(
            widget.l10n.newCategoryTitle,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: widget.l10n.newCategoryHint, border: const OutlineInputBorder()),
            onSubmitted: (_) => _submit(context),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(widget.l10n.accountCancel)),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(onPressed: () => _submit(context), child: Text(widget.l10n.newCategoryAdd)),
            ],
          ),
        ],
      ),
    );
  }
}
