import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Picks the launch mode for [uri]. Use this for every link the app opens.
///
/// `LaunchMode.inAppBrowserView` throws `ArgumentError` for anything that
/// isn't http(s) — see url_launcher's own guard in
/// `url_launcher_uri.dart:47-51`. That matters because non-http links really
/// do get saved: [normalizeUrl] returns null for them, and both
/// `ReceiveSharedIntent` and `AddLinkBloc` fall back to the raw string
/// (`receive_shared_intent.dart:92`). The previous `externalApplication` had
/// no such guard, so switching to the in-app browser silently turned those
/// links into "Could not open".
///
/// Falling back to the external app is also the right destination for them:
/// `mailto:` belongs in a mail client, `tel:` in the dialer. Neither has any
/// business in a browser tab.
LaunchMode launchModeForUrl(Uri uri) =>
    uri.scheme == 'http' || uri.scheme == 'https'
    ? LaunchMode.inAppBrowserView
    : LaunchMode.externalApplication;
