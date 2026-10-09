import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/extensions/context_extension.dart';
import '../../core/services/sync_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/category_utils.dart';
import '../../core/utils/locator.dart';
import '../../core/utils/navigation/route.dart';
import '../../core/utils/url_canonical.dart';
import '../../sharedWidgets/category_chip.dart';
import '../../sharedWidgets/category_suggestion_box.dart';
import '../../sharedWidgets/common_app_bar.dart';
import '../../sharedWidgets/confirmation_bottom_sheet.dart';
import '../../sharedWidgets/custom_button.dart';
import '../../sharedWidgets/custom_text_field.dart';
import '../../sharedWidgets/empty_state.dart';
import '../../sharedWidgets/link_card.dart';
import '../../sharedWidgets/options_bottom_sheet.dart';
import '../../sharedWidgets/swipeable_link_card.dart';
import '../links/manager/link_manager.dart';
import '../links/models/link_model.dart';
import '../shell/app_shell.dart';
import 'bloc/category_picker_cubit.dart';
import 'bloc/link_list_bloc.dart';

/// The Links tab: every saved link with search, quick chips and Source /
/// Category / Sort on top. The app opens here.
class LinkListScreen extends StatelessWidget {
  const LinkListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LinkListBloc(
        manager: locator<LinkManager>(),
        syncEngine: locator<SyncEngine>(),
      )..add(const LinkListLoadRequested()),
      child: const _LinkListContent(),
    );
  }
}

class _LinkListContent extends StatefulWidget {
  const _LinkListContent();

  @override
  State<_LinkListContent> createState() => _LinkListContentState();
}

class _LinkListContentState extends State<_LinkListContent> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    // Leaving mid-selection must not strand the nav hidden.
    AppShell.navVisible.value = true;
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      context.read<LinkListBloc>().add(const LinkListNextPageRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LinkListBloc, LinkListState>(
      listenWhen: (previous, current) =>
          _isSelecting(previous) != _isSelecting(current),
      listener: (context, state) {
        AppShell.navVisible.value = !_isSelecting(state);
      },
      builder: (context, state) {
        final loaded = state is LinkListLoaded ? state : null;
        final selecting = loaded?.isSelecting ?? false;
        final bloc = context.read<LinkListBloc>();
        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && selecting) bloc.add(const LinkListSelectionCleared());
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: selecting
                ? _selectionAppBar(context, loaded!)
                : _appBar(context),
            body: RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: () {
                final completer = Completer<void>();
                bloc.add(LinkListSyncRequested(completer: completer));
                return completer.future;
              },
              child: _body(context, state),
            ),
            floatingActionButton: selecting || loaded == null
                ? null
                : const _AddButton(),
            bottomNavigationBar: selecting
                ? _SelectionActionBar(selectedCount: loaded!.selectedIds.length)
                : null,
          ),
        );
      },
    );
  }

  static bool _isSelecting(LinkListState state) =>
      state is LinkListLoaded && state.isSelecting;

  PreferredSizeWidget _appBar(BuildContext context) {
    return CommonAppBar(
      titleText: context.l10n.homeTitle,
      leadingWidth: AppSpacing.appBarLeadingWidth,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpacing.pageH),
        child: NeoBrutalistButton(
          icon: Icons.person_outline_rounded,
          shape: BoxShape.circle,
          onPressed: () => context.pushNamed(MyRouteName.accountScreen),
        ),
      ),
      actions: [
        Tooltip(
          message: context.l10n.listSelect,
          child: NeoBrutalistButton(
            icon: Icons.checklist_rounded,
            shape: BoxShape.circle,
            onPressed: () => context.read<LinkListBloc>().add(
              const LinkListSelectionStarted(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.pageH),
      ],
    );
  }

  PreferredSizeWidget _selectionAppBar(
    BuildContext context,
    LinkListLoaded loaded,
  ) {
    final bloc = context.read<LinkListBloc>();
    final count = loaded.selectedIds.length;
    return CommonAppBar(
      leadingWidth: AppSpacing.appBarLeadingWidth,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpacing.pageH),
        child: Tooltip(
          message: context.l10n.listCancelSelection,
          child: NeoBrutalistButton(
            icon: Icons.close_rounded,
            shape: BoxShape.circle,
            onPressed: () => bloc.add(const LinkListSelectionCleared()),
          ),
        ),
      ),
      titleText: count == 0
          ? context.l10n.listSelectTitle
          : context.l10n.listSelectedCount(count),
      actions: [
        Tooltip(
          message: context.l10n.listSelectAll,
          child: NeoBrutalistButton(
            icon: Icons.select_all_rounded,
            shape: BoxShape.circle,
            onPressed: () => bloc.add(const LinkListSelectAllRequested()),
          ),
        ),
        const SizedBox(width: AppSpacing.pageH),
      ],
    );
  }

  Widget _body(BuildContext context, LinkListState state) {
    return switch (state) {
      LinkListInitial() || LinkListLoading() => Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      LinkListError(:final message) => ListView(
        children: [
          Padding(padding: AppSpacing.pagePadding, child: Text(message)),
        ],
      ),
      LinkListLoaded(:final stats, :final query)
          when stats.total == 0 && !query.hasFilters => ListView(
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
      LinkListLoaded() => _LinkRows(
        state: state,
        controller: _scrollController,
        header: _Controls(state: state, searchController: _searchController),
      ),
    };
  }
}

// ─── Controls above the list ──────────────────────────────────────────────────

/// Search, quick chips, Source / Category / Sort and the match count.
class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.searchController});

  final LinkListLoaded state;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LinkListBloc>();
    final query = state.query;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          controller: searchController,
          hintText: context.l10n.linksSearchHint(state.stats.total),
          prefixIcon: Icons.search_rounded,
          suffixIcon: query.search.isEmpty
              ? null
              : IconButton(
                  tooltip: context.l10n.searchClearTooltip,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    searchController.clear();
                    bloc.add(const LinkListSearchChanged(''));
                  },
                ),
          onChanged: (value) => bloc.add(LinkListSearchChanged(value)),
        ),
        const SizedBox(height: AppSpacing.md - 2),
        _QuickChips(state: state),
        const SizedBox(height: AppSpacing.sm + 2),
        _FilterButtons(state: state),
        if (query.hasFilters)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              context.l10n.libraryLinkCount(state.total),
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

/// All · Unread · High · Saved 2×+ · Read, each with its count. One at a time.
class _QuickChips extends StatelessWidget {
  const _QuickChips({required this.state});

  final LinkListLoaded state;

  String _label(BuildContext context, QuickFilter quick) => switch (quick) {
    QuickFilter.all => context.l10n.listTabAll,
    QuickFilter.unread => context.l10n.libraryUnread,
    QuickFilter.high => context.l10n.priorityHigh,
    QuickFilter.savedTwice => context.l10n.librarySavedTwice,
    QuickFilter.read => context.l10n.libraryRead,
  };

  @override
  Widget build(BuildContext context) {
    final current = state.query.quickFilter;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Let the row run to the screen edge while staying aligned at the start.
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final quick in QuickFilter.values) ...[
            if (quick != QuickFilter.all)
              const SizedBox(width: AppSpacing.sm),
            _QuickChip(
              label: _label(context, quick),
              count: state.stats.countFor(quick),
              selected: quick == current,
              returnColor: quick == QuickFilter.savedTwice,
              onTap: () => context.read<LinkListBloc>().add(
                LinkListQueryChanged(state.query.withQuickFilter(quick)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.returnColor = false,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  /// "Saved 2×+" uses the return purple for its count (DESIGN.md).
  final bool returnColor;

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = selected ? cs.onPrimary : cs.onSurface;
    final badgeFill = selected
        ? cs.onPrimary
        : (returnColor ? AppColors.accentPurple : cs.surfaceContainerHighest);
    final badgeText = selected
        ? cs.primary
        : (returnColor ? AppColors.black : cs.onSurface);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.md - 2,
            end: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(color: neo.borderColor, width: neo.borderWidth),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.shadowMint,
                      offset: const Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: text.labelLarge!.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm - 1,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: badgeFill,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '$count',
                  style: text.labelSmall!.copyWith(
                    color: badgeText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Source · Category · Sort. A chosen source or category turns green and
/// shows ✕ to clear it.
class _FilterButtons extends StatelessWidget {
  const _FilterButtons({required this.state});

  final LinkListLoaded state;

  String _sortLabel(BuildContext context) => switch (state.query.sort) {
    LinkSort.newest => context.l10n.sortNewest,
    LinkSort.oldest => context.l10n.sortOldest,
    LinkSort.priority => context.l10n.sortPriority,
    LinkSort.mostSaved => context.l10n.sortMostSaved,
    LinkSort.site => context.l10n.sortSite,
  };

  Future<void> _pickSource(BuildContext context) async {
    final bloc = context.read<LinkListBloc>();
    final pick = await _showSheet<_Pick<String?>>(
      context,
      _SourceSheet(sources: state.sources, selected: state.query.host),
    );
    if (pick == null) return;
    final host = pick.value;
    bloc.add(
      LinkListQueryChanged(
        host == null
            ? state.query.copyWith(clearHost: true)
            : state.query.copyWith(host: host),
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context) async {
    final bloc = context.read<LinkListBloc>();
    final pick = await _showSheet<_Pick<_CategoryChoice>>(
      context,
      _CategorySheet(
        categories: state.categories,
        stats: state.stats,
        query: state.query,
      ),
    );
    if (pick == null) return;
    bloc.add(LinkListQueryChanged(pick.value.applyTo(state.query)));
  }

  Future<void> _pickSort(BuildContext context) async {
    final bloc = context.read<LinkListBloc>();
    final l10n = context.l10n;
    final sort = await showOptionsBottomSheet<LinkSort>(
      context: context,
      title: l10n.listSortTitle,
      titleIcon: Icons.sort_rounded,
      selectedValue: state.query.sort,
      options: [
        BottomSheetOption(label: l10n.sortNewest, value: LinkSort.newest),
        BottomSheetOption(label: l10n.sortOldest, value: LinkSort.oldest),
        BottomSheetOption(label: l10n.sortSite, value: LinkSort.site),
        BottomSheetOption(label: l10n.sortPriority, value: LinkSort.priority),
        BottomSheetOption(label: l10n.sortMostSaved, value: LinkSort.mostSaved),
      ],
    );
    if (sort != null) {
      bloc.add(LinkListQueryChanged(state.query.copyWith(sort: sort)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = state.query;
    final bloc = context.read<LinkListBloc>();
    final categoryLabel = query.uncategorized
        ? context.l10n.categoryNone
        : query.categories.isEmpty
        ? null
        : CategoryUtils.getLocalizedCategory(context, query.categories.first);
    return Row(
      children: [
        Expanded(
          child: _FilterButton(
            label: query.host ?? context.l10n.listFilterSource,
            isSet: query.host != null,
            onTap: () => _pickSource(context),
            onClear: () => bloc.add(
              LinkListQueryChanged(query.copyWith(clearHost: true)),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _FilterButton(
            label: categoryLabel ?? context.l10n.bulkCategory,
            isSet: categoryLabel != null,
            onTap: () => _pickCategory(context),
            onClear: () => bloc.add(
              LinkListQueryChanged(
                query.copyWith(categories: {}, uncategorized: false),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _FilterButton(
            label: _sortLabel(context),
            isSet: false,
            trailingIcon: Icons.sort_rounded,
            onTap: () => _pickSort(context),
          ),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.isSet,
    required this.onTap,
    this.onClear,
    this.trailingIcon = Icons.expand_more_rounded,
  });

  final String label;
  final bool isSet;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final cs = Theme.of(context).colorScheme;
    final fg = isSet ? AppColors.black : cs.onSurface;
    final radius = BorderRadius.circular(AppSpacing.radiusMd);
    return Material(
      color: isSet ? AppColors.accentGreen : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: isSet ? AppColors.black : neo.borderColor,
          width: neo.borderWidth,
        ),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: radius),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isSet && onClear != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.l10n.searchClearTooltip,
                  icon: Icon(Icons.close_rounded, size: 18, color: fg),
                  onPressed: onClear,
                )
              else
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                  child: Icon(trailingIcon, size: 18, color: fg),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The round + button: a solid ink circle on a green hard shadow.
class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.addLinkTitle,
      child: NeoBrutalistButton(
        icon: Icons.add_rounded,
        shape: BoxShape.circle,
        width: 56,
        height: 56,
        backgroundColor: cs.primary,
        textColor: cs.onPrimary,
        shadowColor: AppColors.success,
        onPressed: () => context.pushNamed(MyRouteName.addLink),
      ),
    );
  }
}

// ─── Rows ─────────────────────────────────────────────────────────────────────

class _LinkRows extends StatelessWidget {
  const _LinkRows({
    required this.state,
    required this.controller,
    required this.header,
  });

  final LinkListLoaded state;
  final ScrollController controller;
  final Widget header;

  /// The group header for [link] under the current sort, or null for none.
  String? _groupOf(BuildContext context, LinkModel link, DateFormat months) {
    switch (state.query.sort) {
      case LinkSort.newest:
      case LinkSort.oldest:
        final saved = DateTime.fromMillisecondsSinceEpoch(
          link.createdAt,
          isUtc: true,
        ).toLocal();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final day = DateTime(saved.year, saved.month, saved.day);
        if (!day.isBefore(today)) return context.l10n.homeSectionToday;
        if (day.isAfter(today.subtract(const Duration(days: 7)))) {
          return context.l10n.homeSectionThisWeek;
        }
        return months.format(saved);
      case LinkSort.site:
        final host = sourceHost(link.url);
        final count = state.siteCounts[host];
        return count == null ? host : '$host · $count';
      case LinkSort.priority:
        return switch (link.priority.toLowerCase()) {
          'high' => context.l10n.priorityHigh,
          'low' => context.l10n.priorityLow,
          _ => context.l10n.priorityNormal,
        };
      case LinkSort.mostSaved:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final rows = <Object>[];
    String? lastGroup;
    for (final link in state.links) {
      final group = _groupOf(context, link, months);
      if (group != null && group != lastGroup) {
        rows.add(group);
        lastGroup = group;
      }
      rows.add(link);
    }

    final bloc = context.read<LinkListBloc>();
    // Room for the floating nav (in the padding) plus the + button.
    final bottom = MediaQuery.paddingOf(context).bottom + 88;
    final footer = state.hasReachedMax ? 0 : 1;
    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.sm,
        AppSpacing.pageH,
        bottom,
      ),
      itemCount: 1 + (rows.isEmpty ? 1 : rows.length) + footer,
      itemBuilder: (context, index) {
        if (index == 0) return header;
        if (rows.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: context.l10n.homeNoResultsTitle,
            subtitle: context.l10n.homeNoResultsSubtitle,
          );
        }
        final i = index - 1;
        if (i == rows.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final row = rows[i];
        if (row is String) return _GroupHeader(label: row);
        final link = row as LinkModel;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: state.isSelecting
              ? _SelectableLinkCard(
                  link: link,
                  selected: state.selectedIds.contains(link.id),
                  onTap: () => bloc.add(LinkListSelectionToggled(link.id)),
                )
              : SwipeableLinkCard(
                  key: ValueKey(link.id),
                  link: link,
                  searchQuery: state.query.search,
                  onToggleRead: () => bloc.add(LinkListReadToggled(link)),
                  onDelete: () => bloc.add(LinkListLinkDeleted(link.id)),
                  onLongPress: () =>
                      bloc.add(LinkListSelectionToggled(link.id)),
                ),
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm + AppSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// A [LinkCard] in selection mode: tap toggles it, a filled check and a green
/// hard shadow mark it as picked.
class _SelectableLinkCard extends StatelessWidget {
  const _SelectableLinkCard({
    required this.link,
    required this.selected,
    required this.onTap,
  });

  final LinkModel link;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? cs.primary : cs.surface,
                border: Border.all(
                  color: neo.borderColor,
                  width: neo.borderWidth,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 16, color: cs.onPrimary)
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: selected
                          ? AppColors.success
                          : AppColors.transparent,
                      offset: Offset(neo.shadowOffset - 1, neo.shadowOffset),
                      blurRadius: 0,
                    ),
                  ],
                ),
                // The card's own tap would open the link; selection wins.
                child: IgnorePointer(child: LinkCard(link: link)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Selection action bar ─────────────────────────────────────────────────────

/// Mark read · Category · Priority · Delete, in boxed cells. Replaces the
/// bottom nav while selecting. Actions need at least one link picked.
class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({required this.selectedCount});

  final int selectedCount;

  Future<void> _pickCategory(BuildContext context) async {
    final bloc = context.read<LinkListBloc>();
    final state = bloc.state;
    if (state is! LinkListLoaded) return;
    final category = await _showSheet<String>(
      context,
      BlocProvider(
        create: (_) => CategoryPickerCubit(
          manager: locator<LinkManager>(),
          selectedIds: state.selectedIds,
        ),
        child: _CategoryPickerSheet(linkCount: state.selectedIds.length),
      ),
    );
    if (category != null) bloc.add(LinkListBulkCategoryAdded(category));
  }

  Future<void> _pickPriority(BuildContext context) async {
    final bloc = context.read<LinkListBloc>();
    final l10n = context.l10n;
    final priority = await showOptionsBottomSheet<String>(
      context: context,
      title: l10n.addLinkPriorityLabel,
      titleIcon: Icons.flag_rounded,
      options: [
        BottomSheetOption(label: l10n.priorityHigh, value: 'High'),
        BottomSheetOption(label: l10n.priorityNormal, value: 'Normal'),
        BottomSheetOption(label: l10n.priorityLow, value: 'Low'),
      ],
    );
    if (priority != null) bloc.add(LinkListBulkPriorityChanged(priority));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<LinkListBloc>();
    final l10n = context.l10n;
    final confirm = await showConfirmationBottomSheet(
      context: context,
      title: l10n.bulkDeleteTitle(selectedCount),
      message: l10n.linkDeleteMessage,
      confirmLabel: l10n.linkDeleteLabel,
      cancelLabel: l10n.accountCancel,
      titleIcon: Icons.warning_amber_rounded,
      isDestructive: true,
    );
    if (confirm == true) bloc.add(const LinkListBulkDeleteRequested());
  }

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final bloc = context.read<LinkListBloc>();
    final enabled = selectedCount > 0;
    final divider = VerticalDivider(
      width: neo.borderWidth,
      thickness: neo.borderWidth,
      color: neo.borderColor,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: neo.borderColor, width: neo.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _ActionCell(
                icon: Icons.done_all_rounded,
                label: l10n.bulkMarkRead,
                onTap: enabled
                    ? () => bloc.add(const LinkListBulkMarkReadRequested())
                    : null,
              ),
              divider,
              _ActionCell(
                icon: Icons.label_outline_rounded,
                label: l10n.bulkCategory,
                onTap: enabled ? () => _pickCategory(context) : null,
              ),
              divider,
              _ActionCell(
                icon: Icons.flag_outlined,
                label: l10n.addLinkPriorityLabel,
                onTap: enabled ? () => _pickPriority(context) : null,
              ),
              divider,
              _ActionCell(
                icon: Icons.delete_outline_rounded,
                label: l10n.linkDeleteLabel,
                color: cs.error,
                onTap: enabled ? () => _confirmDelete(context) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = color ?? Theme.of(context).colorScheme.onSurface;
    final fg = onTap == null ? Theme.of(context).disabledColor : base;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sheets ───────────────────────────────────────────────────────────────────

/// A sheet's answer. Wrapping it tells "picked All" (null inside) apart from
/// "dismissed" (no pick at all).
class _Pick<T> {
  const _Pick(this.value);

  final T value;
}

Future<T?> _showSheet<T>(BuildContext context, Widget sheet) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (_) => sheet,
  );
}

/// Bottom sheet chrome: title, optional count on the right, content.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, this.trailing, required this.children});

  final String title;
  final String? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: text.headlineMedium)),
                  if (trailing != null) Text(trailing!, style: text.labelLarge),
                ],
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm + AppSpacing.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// A row in the Source and Category sheets: avatar, name, count, tick.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.avatar,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  /// Text in the round avatar; defaults to the label's first letter.
  final String? avatar;

  static const _fills = [
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
    final letter =
        avatar ?? (label.isEmpty ? '?' : label.characters.first.toUpperCase());
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cs.surfaceContainerHighest, width: 2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _fills[label.hashCode.abs() % _fills.length],
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
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall!.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$count',
                style: text.labelLarge!.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 24,
                child: selected
                    ? Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: cs.onPrimary,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pick one site, or All sites. Filters its own list as you type; the typed
/// text is UI-only state, so it lives here rather than in a bloc.
class _SourceSheet extends StatefulWidget {
  const _SourceSheet({required this.sources, required this.selected});

  final List<NamedCount> sources;
  final String? selected;

  @override
  State<_SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<_SourceSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = widget.sources.fold<int>(0, (sum, s) => sum + s.count);
    final shown = _filter.isEmpty
        ? widget.sources
        : widget.sources
              .where((s) => s.name.contains(_filter.toLowerCase()))
              .toList();
    return _SheetFrame(
      title: l10n.listFilterSource,
      trailing: l10n.sourceSheetCount(widget.sources.length),
      children: [
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          hintText: l10n.sourceSearchHint,
          prefixIcon: Icons.search_rounded,
          onChanged: (value) => setState(() => _filter = value.trim()),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_filter.isEmpty)
          _PickRow(
            label: l10n.sourceAll,
            avatar: '∗',
            count: total,
            selected: widget.selected == null,
            onTap: () => context.pop(const _Pick<String?>(null)),
          ),
        for (final source in shown)
          _PickRow(
            label: source.name,
            count: source.count,
            selected: widget.selected == source.name,
            onTap: () => context.pop(_Pick<String?>(source.name)),
          ),
      ],
    );
  }
}

/// What the Category sheet picked: every category, none, or one by name.
sealed class _CategoryChoice {
  const _CategoryChoice();

  LinkQuery applyTo(LinkQuery query);
}

class _AllCategories extends _CategoryChoice {
  const _AllCategories();

  @override
  LinkQuery applyTo(LinkQuery query) =>
      query.copyWith(categories: {}, uncategorized: false);
}

class _NoCategory extends _CategoryChoice {
  const _NoCategory();

  @override
  LinkQuery applyTo(LinkQuery query) =>
      query.copyWith(categories: {}, uncategorized: true);
}

class _NamedCategory extends _CategoryChoice {
  const _NamedCategory(this.name);

  final String name;

  @override
  LinkQuery applyTo(LinkQuery query) =>
      query.copyWith(categories: {name}, uncategorized: false);
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({
    required this.categories,
    required this.stats,
    required this.query,
  });

  final List<NamedCount> categories;
  final LibraryStats stats;
  final LinkQuery query;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final picked = query.categories.isEmpty ? null : query.categories.first;
    return _SheetFrame(
      title: l10n.bulkCategory,
      children: [
        const SizedBox(height: AppSpacing.sm),
        _PickRow(
          label: l10n.bulkCategoryAll,
          avatar: '∗',
          count: stats.total,
          selected: picked == null && !query.uncategorized,
          onTap: () => context.pop(const _Pick<_CategoryChoice>(_AllCategories())),
        ),
        _PickRow(
          label: l10n.categoryNone,
          avatar: '?',
          count: stats.uncategorized,
          selected: query.uncategorized,
          onTap: () => context.pop(const _Pick<_CategoryChoice>(_NoCategory())),
        ),
        for (final category in categories)
          _PickRow(
            label: CategoryUtils.getLocalizedCategory(context, category.name),
            count: category.count,
            selected: picked == category.name,
            onTap: () => context.pop(
              _Pick<_CategoryChoice>(_NamedCategory(category.name)),
            ),
          ),
      ],
    );
  }
}

/// Bulk "Add a category". State lives in [CategoryPickerCubit].
class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({required this.linkCount});

  final int linkCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CategoryPickerCubit>();
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<CategoryPickerCubit, CategoryPickerState>(
      builder: (context, state) => _SheetFrame(
        title: l10n.bulkCategoryTitle,
        children: [
          if (state.suggested.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            CategorySuggestionBox(
              host: state.host,
              suggestions: state.suggested,
              isSelected: (name) => state.picked == name,
              onTap: cubit.pick,
            ),
          ],
          _SheetLabel(l10n.bulkCategoryAll),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final name in state.others)
                CategoryChip(
                  label: CategoryUtils.getLocalizedCategory(context, name),
                  isSelected: state.picked == name,
                  onTap: () => cubit.pick(name),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          NeoBrutalistButton(
            text: l10n.bulkCategoryApply(linkCount),
            backgroundColor: cs.primary,
            textColor: cs.onPrimary,
            shadowColor: AppColors.success,
            onPressed: () {
              final picked = state.picked;
              if (picked != null) context.pop(picked);
            },
          ),
        ],
      ),
    );
  }
}
