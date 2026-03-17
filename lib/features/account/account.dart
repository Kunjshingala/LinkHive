import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_enums.dart';
import '../../core/extensions/context_extension.dart';
import '../../core/localization/locale_cubit.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_cubit.dart';
import '../../core/utils/locator.dart';
import '../../core/utils/navigation/route.dart';
import '../../core/utils/utils.dart';
import '../../features/links/repository/link_repository.dart';
import '../../l10n/localization/app_localizations.dart';
import '../../sharedWidgets/common_app_bar.dart';
import '../../sharedWidgets/confirmation_bottom_sheet.dart';
import '../../sharedWidgets/custom_button.dart';
import '../../sharedWidgets/logout_bottom_sheet.dart';
import '../../sharedWidgets/options_bottom_sheet.dart';
import 'bloc/account_bloc.dart';
import 'bloc/account_event.dart';
import 'bloc/account_state.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AccountBloc(authService: locator<AuthService>(), linkRepository: locator<LinkRepository>()),
      child: const _AccountScreenContent(),
    );
  }
}

class _AccountScreenContent extends StatelessWidget {
  const _AccountScreenContent();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountBloc, AccountState>(
      listener: (context, state) {
        if (state is AccountError) {
          showSnackBar(state.message);
        } else if (state is AccountSignedOut) {
          showSnackBar(context.l10n.accountSignedOutSuccess);
          context.goNamed(MyRouteName.homeScreen);
        }
      },
      builder: (context, state) {
        if (state is AccountLoading) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CommonAppBar(titleText: context.l10n.accountTitle),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Profile Header ─────────────────────────────────────
                _ProfileHeader(state: state),
                SizedBox(height: AppSpacing.xl),

                // ─── Stats Row ────────────────────────────────────────
                _StatsRow(state: state),
                SizedBox(height: AppSpacing.xl),

                // ─── Settings Section ─────────────────────────────────
                Text(context.l10n.accountSettings, style: Theme.of(context).textTheme.titleLarge!),
                SizedBox(height: AppSpacing.md),
                _SettingsList(state: state),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final AccountState state;

  const _ProfileHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final isAuth = state is AccountAuthenticated;
    final user = isAuth ? (state as AccountAuthenticated).user : null;

    final displayName = user?.displayName ?? context.l10n.accountLocalUser;
    final email = user?.email ?? context.l10n.accountSignInDesc;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Stack(
      children: [
        // Offset Shadow
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(4, 5),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.shadowMint,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
              ),
            ),
          ),
        ),
        // Main Card
        Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge!.copyWith(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: Theme.of(context).textTheme.titleLarge!),
                    SizedBox(height: AppSpacing.xs),
                    Text(email, style: Theme.of(context).textTheme.bodySmall!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Stats Row (Neo brutalist mini cards) ─────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final AccountState state;

  const _StatsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    int total = 0;
    int synced = 0;
    int unsynced = 0;

    if (state is AccountAuthenticated) {
      final authState = state as AccountAuthenticated;
      total = authState.totalLinks;
      synced = authState.syncedLinks;
      unsynced = authState.unsyncedLinks;
    } else if (state is AccountGuest) {
      final guestState = state as AccountGuest;
      total = guestState.totalLinks;
      synced = guestState.syncedLinks;
      unsynced = guestState.unsyncedLinks;
    }

    String syncStatus = '';
    Color syncShadowColor = AppColors.shadowMint;

    if (total == 0) {
      syncStatus = '-';
      syncShadowColor = AppColors.secondarySurface;
    } else if (unsynced == 0) {
      syncStatus = context.l10n.accountStatSynced; // Fully synced
      syncShadowColor = AppColors.shadowMint;
    } else if (synced == 0) {
      syncStatus = context.l10n.accountStatLocal; // Fully local
      syncShadowColor = AppColors.shadowPeach;
    } else {
      syncStatus = '$unsynced Pending'; // Mixed
      syncShadowColor = AppColors.shadowLemon;
    }

    return Row(
      children: [
        Expanded(
          child: _StatCard(label: context.l10n.navLinks, value: total.toString(), shadowColor: AppColors.shadowSky),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            label: 'Sync Status',
            value: syncStatus,
            shadowColor: syncShadowColor,
            isSmallValue: total > 0, // Make text smaller if it's a long status
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color shadowColor;
  final bool isSmallValue;

  const _StatCard({required this.label, required this.value, required this.shadowColor, this.isSmallValue = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(3, 4),
            child: Container(
              decoration: BoxDecoration(
                color: shadowColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: isSmallValue
                    ? Theme.of(context).textTheme.titleLarge!
                    : Theme.of(context).textTheme.headlineMedium!,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.xs),
              Text(label, style: Theme.of(context).textTheme.labelLarge!, textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Settings List ────────────────────────────────────────────────────────────
class _SettingsList extends StatelessWidget {
  final AccountState state;

  const _SettingsList({required this.state});

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = state is AccountAuthenticated;

    final currentTheme = context.watch<ThemeCubit>().state;
    String themeSubtitle = context.l10n.accountThemeSystem;
    if (currentTheme == ThemeMode.light) themeSubtitle = context.l10n.accountThemeLight;
    if (currentTheme == ThemeMode.dark) themeSubtitle = context.l10n.accountThemeDark;

    final currentLocale = context.watch<LocaleCubit>().state.languageCode;

    final items = [
      (Icons.language_rounded, context.l10n.accountLanguage, currentLocale, AccountItem.language),
      (Icons.palette_outlined, context.l10n.accountTheme, themeSubtitle, AccountItem.theme),
      (Icons.sync_rounded, context.l10n.accountSyncData, '', AccountItem.syncData),
      (Icons.delete_forever_rounded, context.l10n.accountDeleteLocalData, '', AccountItem.deleteLocalData),
      // (Icons.help_outline_rounded, context.l10n.accountHelpFeedback, '', AccountItem.helpFeedback),
      if (isAuthenticated)
        (Icons.logout_rounded, context.l10n.accountSignOut, '', AccountItem.auth)
      else
        (Icons.login_rounded, context.l10n.accountSignInPromo, '', AccountItem.auth),
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(4, 5),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.shadowLemon,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, i) => Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline, // Thick black dividers inside the card
              thickness: 2,
            ),
            itemBuilder: (context, index) {
              final (icon, label, subtitle, item) = items[index];
              final isSignAction = item == AccountItem.auth;
              final isSignOut = isSignAction && isAuthenticated;

              final leadingColor = isSignOut
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.surfaceContainerHighest;
              final leadingIconColor = isSignOut
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface;
              final titleColor = isSignOut
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface;

              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                leading: IgnorePointer(
                  child: NeoBrutalistButton(
                    icon: icon,
                    backgroundColor: leadingColor,
                    textColor: leadingIconColor,
                    onPressed: () {},
                    shape: BoxShape.circle,
                    height: 36,
                  ),
                ),
                title: Text(label, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: titleColor)),
                trailing: subtitle.isEmpty
                    ? Icon(Icons.chevron_right_rounded, size: 24, color: Theme.of(context).colorScheme.onSurface)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(subtitle, style: Theme.of(context).textTheme.labelLarge!),
                          SizedBox(width: AppSpacing.xs),
                          Icon(Icons.chevron_right_rounded, size: 24, color: Theme.of(context).colorScheme.onSurface),
                        ],
                      ),
                onTap: () => _onAccountItemTap(context, item, isAuthenticated),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _onAccountItemTap(BuildContext context, AccountItem item, bool isAuthenticated) async {
    switch (item) {
      case AccountItem.language:
        final cubit = context.read<LocaleCubit>();
        final currentLocale = cubit.state.languageCode;
        final newLocale = await showOptionsBottomSheet<String>(
          context: context,
          title: context.l10n.accountSelectLanguage,
          titleIcon: Icons.language_rounded,
          selectedValue: currentLocale,
          options: AppLocalizations.supportedLocales.map((locale) {
            return BottomSheetOption(label: _getLanguageName(context, locale.languageCode), value: locale.languageCode);
          }).toList(),
        );
        if (newLocale != null) {
          if (!context.mounted) return;
          cubit.changeLocale(newLocale);
        }
        break;

      case AccountItem.theme:
        final cubit = context.read<ThemeCubit>();
        final currentTheme = cubit.state;
        final newTheme = await showOptionsBottomSheet<ThemeMode>(
          context: context,
          title: context.l10n.accountSelectTheme,
          titleIcon: Icons.palette_outlined,
          selectedValue: currentTheme,
          options: [
            BottomSheetOption(label: context.l10n.accountThemeSystem, value: ThemeMode.system),
            BottomSheetOption(label: context.l10n.accountThemeLight, value: ThemeMode.light),
            BottomSheetOption(label: context.l10n.accountThemeDark, value: ThemeMode.dark),
          ],
        );
        if (newTheme != null) {
          if (!context.mounted) return;
          cubit.changeTheme(newTheme);
        }
        break;

      case AccountItem.syncData:
        if (!isAuthenticated) {
          showSnackBar(context.l10n.accountSyncSignInMsg);
          return;
        }
        final l10n = context.l10n;
        showSnackBar(l10n.accountSyncingMsg);
        await locator<LinkRepository>().syncPendingLinks();
        await locator<LinkRepository>().pullFromCloud();
        if (context.mounted) {
          context.read<AccountBloc>().add(const AccountLoadRequested());
        }
        showSnackBar(l10n.accountSyncSuccess);
        break;

      case AccountItem.deleteLocalData:
        final confirm = await showConfirmationBottomSheet(
          context: context,
          title: context.l10n.accountDeleteTitle,
          message: context.l10n.accountDeleteConfirm,
          confirmLabel: context.l10n.accountDelete,
          cancelLabel: context.l10n.accountCancel,
          titleIcon: Icons.warning_amber_rounded,
          isDestructive: true,
        );
        if (confirm == true) {
          if (!context.mounted) return;
          final l10n = context.l10n;
          final repo = locator<LinkRepository>();
          try {
            await repo.clearLocalData();
            if (context.mounted) {
              showSnackBar(l10n.accountDeleteSuccess);
            }
          } catch (e) {
            if (context.mounted) {
              showSnackBar(l10n.accountDeleteFail);
            }
          }
        }
        break;

      case AccountItem.auth:
        if (isAuthenticated) {
          final result = await showLogoutBottomSheet(
            context: context,
            title: context.l10n.accountSignOut,
            message: context.l10n.accountSignOutDesc,
            confirmLabel: context.l10n.accountSignOut,
            clearLocalLabel: context.l10n.accountDeleteLocalData,
            clearRemoteLabel: context.l10n.accountDeleteRemoteData,
            titleIcon: Icons.logout_rounded,
          );
          if (result != null && result.$1 && context.mounted) {
            context.read<AccountBloc>().add(
                  AccountSignOutRequested(
                    clearLocal: result.$2,
                    clearRemote: result.$3,
                  ),
                );
          }
        } else {
          // Route the user to the dedicated auth screen so they can choose the sign-in method.
          context.pushNamed(MyRouteName.login);
        }
        break;

      case AccountItem.helpFeedback:
        // Handle help/feedback if needed, or simply do nothing for now
        break;
    }
  }

  String _getLanguageName(BuildContext context, String code) {
    switch (code) {
      case 'en':
        return context.l10n.langEnglish;
      case 'hi':
        return context.l10n.langHindi;
      case 'gu':
        return context.l10n.langGujarati;
      case 'ar':
        return context.l10n.langArabic;
      default:
        return code.toUpperCase();
    }
  }
}
