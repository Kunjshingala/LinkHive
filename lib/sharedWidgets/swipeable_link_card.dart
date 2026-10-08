import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/extensions/context_extension.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/navigation/route.dart';
import '../features/links/models/link_model.dart';
import 'confirmation_bottom_sheet.dart';
import 'link_card.dart';

/// A [LinkCard] on a hard pastel shadow that you can swipe.
///
/// - Swipe right toggles read / unread ([onToggleRead]).
/// - Swipe left asks to confirm, then deletes ([onDelete]).
/// - Long-press starts bulk selection ([onLongPress]).
///
/// The shadow is a back box behind the card. While swiping it turns green
/// (read) or red (delete) and shows the action's icon, so the swipe reveals
/// what it will do.
class SwipeableLinkCard extends StatefulWidget {
  const SwipeableLinkCard({
    super.key,
    required this.link,
    required this.onToggleRead,
    required this.onDelete,
    this.onLongPress,
    this.searchQuery = '',
  });

  final LinkModel link;
  final VoidCallback onToggleRead;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;

  /// Highlighted in the card's title and host while searching.
  final String searchQuery;

  @override
  State<SwipeableLinkCard> createState() => _SwipeableLinkCardState();
}

class _SwipeableLinkCardState extends State<SwipeableLinkCard> {
  DismissDirection? _direction;

  void _setDirection(DismissDirection? value) {
    if (mounted && _direction != value) setState(() => _direction = value);
  }

  Future<bool> _confirmDelete() async {
    final confirm = await showConfirmationBottomSheet(
      context: context,
      title: context.l10n.linkDeleteTitle,
      message: context.l10n.linkDeleteMessage,
      confirmLabel: context.l10n.linkDeleteLabel,
      cancelLabel: context.l10n.accountCancel,
      titleIcon: Icons.warning_amber_rounded,
      isDestructive: true,
    );
    return confirm == true;
  }

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final cs = Theme.of(context).colorScheme;
    final link = widget.link;

    // The back (offset) box: mint shadow at rest, green/red while swiping.
    Color boxColor = neo.shadowColor;
    IconData? actionIcon;
    AlignmentGeometry iconAlignment = Alignment.center;
    if (_direction == DismissDirection.startToEnd) {
      boxColor = AppColors.success;
      actionIcon = link.isRead
          ? Icons.mark_email_unread_rounded
          : Icons.check_circle_rounded;
      iconAlignment = AlignmentDirectional.centerStart;
    } else if (_direction == DismissDirection.endToStart) {
      boxColor = cs.error;
      actionIcon = Icons.delete_outline_rounded;
      iconAlignment = AlignmentDirectional.centerEnd;
    }

    return Stack(
      children: [
        // Back box (offset): the shadow, or the colored action while swiping.
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(neo.shadowOffset - 1, neo.shadowOffset),
            child: Container(
              alignment: iconAlignment,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: neo.borderColor,
                  width: neo.borderWidth,
                ),
              ),
              child: actionIcon == null
                  ? null
                  : Icon(actionIcon, color: AppColors.black, size: 26),
            ),
          ),
        ),
        // Foreground card slides over the back box. The Dismissible's own
        // backgrounds are empty: the colored reveal is the back box behind it.
        Dismissible(
          key: ValueKey('dismiss_${link.id}'),
          onUpdate: (details) =>
              _setDirection(details.progress > 0 ? details.direction : null),
          background: const SizedBox.shrink(),
          secondaryBackground: const SizedBox.shrink(),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              widget.onToggleRead();
              _setDirection(null);
              return false;
            }
            final confirmed = await _confirmDelete();
            if (confirmed) widget.onDelete();
            if (mounted) _setDirection(null);
            return false;
          },
          child: GestureDetector(
            onLongPress: widget.onLongPress,
            child: _PressableCard(
              child: Stack(
                children: [
                  // Opaque base so a read (dimmed) card fades against the
                  // scaffold, not the colored back box behind it.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: link.isRead ? 0.55 : 1.0,
                    child: LinkCard(
                      link: link,
                      searchQuery: widget.searchQuery,
                      onEdit: () =>
                          context.pushNamed(MyRouteName.editLink, extra: link),
                      onDelete: widget.onDelete,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Adds the same press effect as `NeoBrutalistButton`: on tap the card slides
/// down-right onto its shadow so the offset gap collapses. The shadow itself is
/// drawn by [SwipeableLinkCard] behind it.
///
/// The press is driven by a [Listener] (pointer events) rather than a gesture
/// recognizer, so it doesn't steal taps from the card's inner InkWell / 3-dot
/// menu or the surrounding Dismissible swipe. Movement past a small threshold
/// cancels the press so scrolling and swiping don't trigger a false press.
class _PressableCard extends StatefulWidget {
  const _PressableCard({required this.child});

  final Widget child;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;
  Offset? _downPosition;

  void _setPressed(bool value) {
    // A long-press can replace this card before the finger lifts.
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final dx = neo.shadowOffset - 1;
    final dy = neo.shadowOffset;

    return Listener(
      onPointerDown: (event) {
        _downPosition = event.position;
        _setPressed(true);
      },
      onPointerMove: (event) {
        // Cancel the press once the finger moves (a scroll or swipe), so the
        // effect only fires on genuine taps.
        if (_pressed &&
            _downPosition != null &&
            (event.position - _downPosition!).distance > 12) {
          _setPressed(false);
        }
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: _pressed
            ? Matrix4.translationValues(dx, dy, 0)
            : Matrix4.identity(),
        child: widget.child,
      ),
    );
  }
}
