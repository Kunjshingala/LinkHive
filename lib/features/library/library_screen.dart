import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/context_extension.dart';
import '../../core/services/sync_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/category_utils.dart';
import '../../core/utils/locator.dart';
import '../../core/utils/navigation/route.dart';
import '../../sharedWidgets/common_app_bar.dart';
import '../../sharedWidgets/custom_button.dart';
import '../../sharedWidgets/empty_state.dart';
import '../../sharedWidgets/options_bottom_sheet.dart';
import '../links/manager/link_manager.dart';
import 'bloc/library_bloc.dart';
import 'link_list/link_list_screen.dart';

/// The Library tab: counts, sources and categories, each one tap from a list.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LibraryBloc(
        manager: locator<LinkManager>(),
        syncEngine: locator<SyncEngine>(),
      )..add(const LibraryLoadRequested()),
      child: const _LibraryContent(),
    );
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent();

  /// Sources shown before "All N".
  static const _topSources = 4;

  void _openList(BuildContext context, LinkListArgs args) =>
      context.pushNamed(MyRouteName.linkList, extra: args);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _appBar(context),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () {
            final completer = Completer<void>();
            context.read<LibraryBloc>().add(
              LibrarySyncRequested(completer: completer),
            );
            return completer.future;
          },
          child: BlocBuilder<LibraryBloc, LibraryState>(
            builder: (context, state) => switch (state) {
              LibraryInitial() || LibraryLoading() => Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              LibraryError(:final message) => ListView(
                children: [
                  Padding(
                    padding: AppSpacing.pagePadding,
                    child: Text(message),
                  ),
                ],
              ),
              LibraryLoaded(:final stats) when stats.total == 0 => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  EmptyState(
                    icon: Icons.collections_bookmark_rounded,
                    title: context.l10n.homeEmptyStateTitle,
                    subtitle: context.l10n.homeEmptyStateSubtitle,
                    actionLabel: context.l10n.addLinkTitle,
                    onAction: () => context.pushNamed(MyRouteName.addLink),
                  ),
                ],
              ),
              LibraryLoaded() => _overview(context, state),
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    return CommonAppBar(
      leadingWidth: AppSpacing.appBarLeadingWidth,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpacing.pageH),
        child: NeoBrutalistButton(
          icon: Icons.person_outline_rounded,
          shape: BoxShape.circle,
          onPressed: () => context.pushNamed(MyRouteName.accountScreen),
        ),
      ),
      customTitle: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          final text = Theme.of(context).textTheme;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.libraryTitle, style: text.titleMedium),
              if (state is LibraryLoaded)
                Text(
                  context.l10n.libraryLinkCount(state.stats.total),
                  style: text.labelLarge,
                ),
            ],
          );
        },
      ),
      actions: [
        NeoBrutalistButton(
          icon: Icons.add_rounded,
          shadowColor: AppColors.success,
          shape: BoxShape.circle,
          onPressed: () => context.pushNamed(MyRouteName.addLink),
        ),
        const SizedBox(width: AppSpacing.pageH),
      ],
    );
  }

  Widget _overview(BuildContext context, LibraryLoaded state) {
    final l10n = context.l10n;
    final stats = state.stats;
    final allLinks = LinkListArgs(
      title: l10n.libraryAllLinks,
      query: const LinkQuery(),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.md,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      children: [
        _SearchRow(
          onSearch: () => _openList(
            context,
            LinkListArgs(
              title: l10n.libraryAllLinks,
              query: const LinkQuery(),
              searchMode: true,
            ),
          ),
          onFilters: () => _openList(
            context,
            LinkListArgs(
              title: l10n.libraryAllLinks,
              query: const LinkQuery(),
              openFilters: true,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _TileGrid(
          tiles: [
            _StatTile(
              icon: Icons.mark_email_unread_outlined,
              label: l10n.libraryUnread,
              count: stats.unread,
              shadow: AppColors.shadowMint,
              onTap: () => _openList(
                context,
                LinkListArgs(
                  title: l10n.libraryUnread,
                  query: const LinkQuery(readFilter: ReadFilter.unread),
                ),
              ),
            ),
            _StatTile(
              icon: Icons.flag_rounded,
              label: l10n.priorityHigh,
              count: stats.high,
              shadow: AppColors.shadowPeach,
              onTap: () => _openList(
                context,
                LinkListArgs(
                  title: l10n.priorityHigh,
                  query: const LinkQuery(priorities: {'High'}),
                ),
              ),
            ),
            _StatTile(
              icon: Icons.replay_rounded,
              label: l10n.librarySavedTwice,
              count: stats.savedTwicePlus,
              shadow: AppColors.shadowLemon,
              // Return purple is reserved for "it came back" (DESIGN.md).
              fill: AppColors.accentPurple,
              onTap: () => _openList(
                context,
                LinkListArgs(
                  title: l10n.librarySavedTwice,
                  query: const LinkQuery(
                    minShareCount: 2,
                    sort: LinkSort.mostSaved,
                  ),
                ),
              ),
            ),
            _StatTile(
              icon: Icons.done_all_rounded,
              label: l10n.libraryRead,
              count: stats.read,
              shadow: AppColors.shadowSky,
              onTap: () => _openList(
                context,
                LinkListArgs(
                  title: l10n.libraryRead,
                  query: const LinkQuery(readFilter: ReadFilter.read),
                ),
              ),
            ),
          ],
        ),
        if (state.sources.isNotEmpty) ...[
          _SectionHeader(
            label: l10n.librarySources,
            action: state.sources.length > _topSources
                ? l10n.librarySeeAll(state.sources.length)
                : null,
            onAction: () => _pickSource(context, state.sources),
          ),
          for (final source in state.sources.take(_topSources))
            _CountRow(
              label: source.name,
              count: source.count,
              onTap: () => _openSource(context, source.name),
            ),
        ],
        if (state.categories.isNotEmpty) ...[
          _SectionHeader(label: l10n.homeCategoriesLabel),
          for (final category in state.categories)
            _CountRow(
              label: CategoryUtils.getLocalizedCategory(
                context,
                category.name,
              ),
              count: category.count,
              onTap: () => _openList(
                context,
                LinkListArgs(
                  title: CategoryUtils.getLocalizedCategory(
                    context,
                    category.name,
                  ),
                  query: LinkQuery(categories: {category.name}),
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.md),
        _CountRow(
          label: l10n.libraryAllLinks,
          count: stats.total,
          muted: true,
          onTap: () => _openList(context, allLinks),
        ),
      ],
    );
  }

  void _openSource(BuildContext context, String host) => _openList(
    context,
    LinkListArgs(title: host, query: LinkQuery(host: host)),
  );

  Future<void> _pickSource(
    BuildContext context,
    List<NamedCount> sources,
  ) async {
    final host = await showOptionsBottomSheet<String>(
      context: context,
      title: context.l10n.librarySources,
      titleIcon: Icons.public_rounded,
      options: [
        for (final source in sources)
          BottomSheetOption(
            label: '${source.name} · ${source.count}',
            value: source.name,
          ),
      ],
    );
    if (host != null && context.mounted) _openSource(context, host);
  }
}

// ─── Pieces ───────────────────────────────────────────────────────────────────

/// A search field look-alike that opens the list in search mode, next to the
/// filter button.
class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.onSearch, required this.onFilters});

  final VoidCallback onSearch;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final cs = Theme.of(context).colorScheme;
    final hint = Theme.of(context).textTheme.bodyLarge!.copyWith(
      color: Theme.of(context).hintColor,
    );
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: context.l10n.searchHint,
            excludeSemantics: true,
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: neo.borderColor,
                    width: neo.borderWidth,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: hint.color, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(context.l10n.searchHint, style: hint),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
        Tooltip(
          message: context.l10n.listFilterTitle,
          child: NeoBrutalistButton(
            icon: Icons.tune_rounded,
            shadowColor: AppColors.shadowSky,
            onPressed: onFilters,
          ),
        ),
      ],
    );
  }
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    const gap = AppSpacing.md - 2;
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: gap),
                Expanded(
                  child: i + 1 < tiles.length
                      ? tiles[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A count tile: label with icon, big number, one hard pastel shadow.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.shadow,
    required this.onTap,
    this.fill,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color shadow;
  final VoidCallback onTap;

  /// A pastel fill; text on it stays ink in both themes.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final labelColor = fill != null ? AppColors.black : text.labelLarge!.color;
    final countColor = fill != null ? AppColors.black : cs.onSurface;
    final radius = BorderRadius.circular(AppSpacing.radiusLg);
    return Semantics(
      button: true,
      label: '$label, $count',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: fill ?? cs.surface,
          borderRadius: radius,
          border: Border.all(color: neo.borderColor, width: neo.borderWidth),
          boxShadow: [
            BoxShadow(
              color: shadow,
              offset: Offset(neo.shadowOffset, neo.shadowOffset),
              blurRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md - 2,
                vertical: AppSpacing.sm + AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: labelColor),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelLarge!.copyWith(color: labelColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$count',
                    style: text.headlineLarge!.copyWith(color: countColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.action, this.onAction});

  final String label;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label.toUpperCase(), style: text.labelSmall)),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action!,
                      style: text.labelLarge!.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A pill row: letter avatar, name, count, chevron.
class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.label,
    required this.count,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  /// Muted rows sit on the secondary surface (All links).
  final bool muted;

  static const _avatarFills = [
    AppColors.shadowRose,
    AppColors.accentOrange,
    AppColors.accentBlue,
    AppColors.shadowLemon,
    AppColors.accentGreen,
    AppColors.accentPurple,
  ];

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final letter = label.isEmpty ? '?' : label.characters.first.toUpperCase();
    final fill = _avatarFills[label.hashCode.abs() % _avatarFills.length];
    final radius = BorderRadius.circular(AppSpacing.radiusFull);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: muted ? cs.surfaceContainerHighest : cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: neo.borderColor, width: neo.borderWidth),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.sm,
                end: AppSpacing.sm + AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: fill,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.black,
                        width: neo.borderWidth,
                      ),
                    ),
                    child: Text(
                      letter,
                      style: text.labelLarge!.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                  ),
                  Text(
                    '$count',
                    style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: text.labelLarge!.color,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
