import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'custom_button.dart';

/// A reusable Neo-Brutalist App Bar.
/// Centered around the app's design language with a distinctive
/// soft-brutalist aesthetic.
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final String titleText;
  final Widget? customTitle;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final bool centerTitle;
  final double? elevation;
  final double? toolbarHeight;
  final SystemUiOverlayStyle? systemUiOverlayStyle;

  const CommonAppBar({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.titleText = '',
    this.customTitle,
    this.actions,
    this.backgroundColor,
    this.centerTitle = true,
    this.elevation = 0,
    this.toolbarHeight,
    this.systemUiOverlayStyle,
  });

  @override
  Widget build(BuildContext context) {
    final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
    final bool canPop = parentRoute?.canPop ?? false;

    Widget? leadingWidget = leading;
    bool usesAutoLeading = false;
    if (leadingWidget == null && automaticallyImplyLeading && canPop) {
      usesAutoLeading = true;
      leadingWidget = Padding(
        // Match the Home header buttons: pageH inset, default (44px) size.
        padding: const EdgeInsetsDirectional.only(start: AppSpacing.pageH),
        child: NeoBrutalistButton(
          icon: Icons.chevron_left_rounded,
          onPressed: () => context.pop(),
          shape: BoxShape.circle,
        ),
      );
    }

    return AppBar(
      toolbarHeight: toolbarHeight,
      backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      elevation: elevation,
      scrolledUnderElevation: 0,
      surfaceTintColor: AppColors.transparent,
      automaticallyImplyLeading: false, // Handled manually above
      leading: leadingWidget,
      // Widen the leading slot so the full-size button at pageH doesn't clip.
      leadingWidth: usesAutoLeading ? AppSpacing.appBarLeadingWidth : null,
      title: customTitle ?? Text(titleText, style: Theme.of(context).textTheme.titleMedium!),
      centerTitle: centerTitle,
      actions: actions,
      systemOverlayStyle: systemUiOverlayStyle ?? Theme.of(context).appBarTheme.systemOverlayStyle,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? kToolbarHeight);
}
