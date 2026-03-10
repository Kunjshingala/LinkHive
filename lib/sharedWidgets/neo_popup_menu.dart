import 'package:flutter/material.dart';

import '../../core/extensions/context_extension.dart';
import '../core/theme/app_spacing.dart';

class NeoPopupMenuItem<T> {
  final String label;
  final T value;
  final IconData? icon;
  final bool isDestructive;

  const NeoPopupMenuItem({required this.label, required this.value, this.icon, this.isDestructive = false});
}

/// A stylised version of [PopupMenuButton] tailored for Neo-Brutalism.
///
/// Wraps the standard [PopupMenuButton] to provide a hard offset shadow and
/// strict border lines around the menu overlay.
class NeoPopupMenu<T> extends StatelessWidget {
  final Widget child;
  final List<NeoPopupMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final Offset offset;

  const NeoPopupMenu({
    super.key,
    required this.child,
    required this.items,
    required this.onSelected,
    this.offset = const Offset(0, 40),
  });

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: Theme.of(context).colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: BorderSide(color: neo.borderColor, width: neo.borderWidth),
          ),
        ),
      ),
      child: PopupMenuButton<T>(
        onSelected: onSelected,
        offset: offset,
        child: child,
        itemBuilder: (context) {
          return items.map((item) {
            final color = item.isDestructive
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurface;

            return PopupMenuItem<T>(
              value: item.value,
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, color: color, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: color, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }).toList();
        },
      ),
    );
  }
}
