import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../../my_app.dart';

void showSnackBar(String message) {
  scaffoldMessengerKey.currentState?.clearSnackBars();

  scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      // Set backgroundColor on the SnackBar itself, not a nested Container —
      // otherwise the surrounding SnackBar chrome falls back to its own
      // theme-driven default and visibly mismatches the content's fill.
      // Fixed white/black in both themes, matching the splash screen's
      // "this surface never follows app theme" treatment.
      backgroundColor: AppColors.white,
      // White-on-white is the same as the light-mode scaffold background, so
      // a black border (the app's standard Neo-Brutalist signature) is what
      // actually separates the bar from the page, not the fill color alone.
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.black, width: 2),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      content: Text(message, style: const TextStyle(color: AppColors.black)),
    ),
  );
}

void printLog({String tag = "Utils", required String msg}) {
  debugPrint("$tag ----------> $msg");
}
