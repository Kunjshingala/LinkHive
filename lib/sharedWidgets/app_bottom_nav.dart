import 'package:flutter/material.dart';

import '../core/extensions/context_extension.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// One destination in [AppBottomNav].
class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// Shown as a small count bubble on the icon when above zero.
  final int badgeCount;
}

/// Floating pill navigation: a rounded bar with a 2px outline and a hard ink
/// shadow, floating above the content.
///
/// The active item is a solid `primary` pill with its icon and label; the
/// others show their icon only (screen readers still get the label). Put it
/// in a `Scaffold` with `extendBody: true` so content scrolls under it.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Height of the pill itself, without the outer margin.
  static const double barHeight = 64;

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Container(
        height: barHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: neo.borderColor, width: neo.borderWidth),
          boxShadow: [
            BoxShadow(
              color: neo.borderColor,
              offset: Offset(neo.shadowOffset, neo.shadowOffset),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < items.length; i++)
              _NavButton(
                item: items[i],
                selected: i == currentIndex,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final idleColor = Theme.of(context).textTheme.labelLarge!.color;
    final color = selected ? cs.onPrimary : idleColor;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 48,
          constraints: const BoxConstraints(minWidth: 56),
          padding: EdgeInsets.symmetric(
            horizontal: selected ? AppSpacing.md + 2 : AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? cs.primary : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconWithBadge(
                icon: item.icon,
                color: color,
                count: item.badgeCount,
              ),
              if (selected) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  item.label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({
    required this.icon,
    required this.color,
    required this.count,
  });

  final IconData icon;
  final Color? color;
  final int count;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: color, size: 24);
    if (count <= 0) return iconWidget;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        PositionedDirectional(
          top: -AppSpacing.sm,
          end: -AppSpacing.sm - 2,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentOrange,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(
                color: AppColors.black,
                width: context.neoBrutal.borderWidth,
              ),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: Theme.of(
                context,
              ).textTheme.labelSmall!.copyWith(color: AppColors.black),
            ),
          ),
        ),
      ],
    );
  }
}
