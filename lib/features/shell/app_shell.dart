import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/context_extension.dart';
import '../../core/utils/locator.dart';
import '../../core/utils/utils.dart';
import '../../sharedWidgets/app_bottom_nav.dart';
import '../links/manager/link_manager.dart';
import 'bloc/inbox_badge_cubit.dart';
import 'bloc/shell_bloc.dart';
import 'bloc/shell_event.dart';
import 'bloc/shell_state.dart';

/// The Today / Library / Inbox tab shell.
///
/// Each tab keeps its own navigation stack and state
/// (`StatefulShellRoute.indexedStack`), so switching tabs never reloads a
/// list or loses its scroll position.
///
/// Back at a tab's first screen goes to Today; on Today it needs a second
/// press within a few seconds to leave the app.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Hides the bottom nav while a screen shows its own bottom bar in its
  /// place, such as the Library's bulk-selection actions.
  static final navVisible = ValueNotifier<bool>(true);

  /// Branch index of the Today tab, the app's home.
  static const _todayIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ShellBloc()),
        BlocProvider(
          create: (_) => InboxBadgeCubit(manager: locator<LinkManager>()),
        ),
      ],
      child: BlocListener<ShellBloc, ShellState>(
        listener: (context, state) {
          if (state is ShellBackPressedOnce) {
            showSnackBar(context.l10n.pressBackAgainToExit);
          } else if (state is ShellCanExit) {
            SystemNavigator.pop();
          }
        },
        child: Builder(
          builder: (context) => PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (navigationShell.currentIndex != _todayIndex) {
                navigationShell.goBranch(_todayIndex);
                return;
              }
              context.read<ShellBloc>().add(const ShellBackPressed());
            },
            child: Scaffold(
              body: navigationShell,
              bottomNavigationBar: _bottomNav(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomNav(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: navVisible,
      builder: (context, visible, _) {
        if (!visible) return const SizedBox.shrink();
        return BlocBuilder<InboxBadgeCubit, int>(
          builder: (context, inboxCount) => AppBottomNav(
            currentIndex: navigationShell.currentIndex,
            // Tapping the current tab again returns it to its first screen.
            onTap: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            items: [
              AppBottomNavItem(
                icon: Icons.today_rounded,
                label: context.l10n.todayTitle,
              ),
              AppBottomNavItem(
                icon: Icons.collections_bookmark_rounded,
                label: context.l10n.libraryTitle,
              ),
              AppBottomNavItem(
                icon: Icons.inbox_rounded,
                label: context.l10n.inboxTitle,
                badgeCount: inboxCount,
              ),
            ],
          ),
        );
      },
    );
  }
}
