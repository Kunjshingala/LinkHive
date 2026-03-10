import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Amber banner shown when the user is not authenticated (local-only mode).
/// Prompts the user to sign in to back up their data.
class LocalModeBanner extends StatelessWidget {
  final VoidCallback onSignIn;

  const LocalModeBanner({super.key, required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.pageH, vertical: AppSpacing.sm),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.accentOrange,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.warning.withAlpha(80), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 16),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Saved locally only. Sign in to backup.',
              style: Theme.of(context).textTheme.labelLarge!.copyWith(color: AppColors.warning),
            ),
          ),
          GestureDetector(
            onTap: onSignIn,
            child: Text(
              'Sign in',
              style: Theme.of(
                context,
              ).textTheme.labelLarge!.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
