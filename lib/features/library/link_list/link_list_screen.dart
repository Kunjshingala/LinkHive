import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/category_utils.dart';
import '../../../core/utils/locator.dart';
import '../../../sharedWidgets/category_chip.dart';
import '../../../sharedWidgets/category_suggestion_box.dart';
import '../../../sharedWidgets/common_app_bar.dart';
import '../../../sharedWidgets/confirmation_bottom_sheet.dart';
import '../../../sharedWidgets/custom_button.dart';
import '../../../sharedWidgets/custom_text_field.dart';
import '../../../sharedWidgets/empty_state.dart';
import '../../../sharedWidgets/link_card.dart';
import '../../../sharedWidgets/options_bottom_sheet.dart';
import '../../../sharedWidgets/swipeable_link_card.dart';
import '../../../core/constants/app_enums.dart';
import '../../links/manager/link_manager.dart';
import '../../links/models/link_model.dart';
import '../../shell/app_shell.dart';
import 'bloc/category_picker_cubit.dart';
import 'bloc/filter_sheet_cubit.dart';
import 'bloc/link_list_bloc.dart';

/// What a Library list shows: opened from a tile, a source, a category, All
/// links or search.
class LinkListArgs {
  const LinkListArgs({
    required this.title,
    required this.query,
    this.searchMode = false,
    this.openFilters = false,
  });

  /// Already localized: a host, a category label or a tile name.
  final String title;

  /// The scope this list was opened with. The user's filters build on it.
  final LinkQuery query;

  /// Shows a focused search field at the top.
  final bool searchMode;

  /// Opens the filter sheet as soon as the list appears.
  final bool openFilters;
}

class LinkListScreen extends StatelessWidget {
  const LinkListScreen({super.key, required this.args});

  final LinkListArgs args;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          LinkListBloc(manager: locator<LinkManager>(), query: args.query)
            ..add(const LinkListLoadRequested()),
      child: _LinkListContent(args: args),
    );
  }
}

class _LinkListContent extends StatefulWidget {
  const _LinkListContent({required this.args});

  final LinkListArgs args;

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
    if (widget.args.openFilters) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFilters();
      });
    }
  }

  @override
  void dispose() {
    // Leaving the list mid-selection must not strand the nav hidden.
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

  LinkQuery? get _query {
    final state = context.read<LinkListBloc>().state;
    return state is LinkListLoaded ? state.query : null;
  }

  Future<void> _openFilters() async {
    final query = _query ?? widget.args.query;
    final updated = await showModalBottomSheet<LinkQuery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => BlocProvider(
        create: (_) => FilterSheetCubit(
          manager: locator<LinkManager>(),
          initial: query,
          scope: widget.args.query,
        ),
        child: const _FilterSheet(),
      ),
    );
    if (updated != null && mounted) {
      context.read<LinkListBloc>().add(LinkListQueryChanged(updated));
    }
  }

  Future<void> _openSort() async {
    final query = _query;
    if (query == null) return;
    final l10n = context.l10n;
    final sort = await showOptionsBottomSheet<LinkSort>(
      context: context,
      title: l10n.listSortTitle,
      titleIcon: Icons.sort_rounded,
      selectedValue: query.sort,
      options: [
        BottomSheetOption(label: l10n.sortNewest, value: LinkSort.newest),
        BottomSheetOption(label: l10n.sortOldest, value: LinkSort.oldest),
        BottomSheetOption(label: l10n.sortPriority, value: LinkSort.priority),
        BottomSheetOption(label: l10n.sortMostSaved, value: LinkSort.mostSaved),
        BottomSheetOption(label: l10n.sortSite, value: LinkSort.site),
      ],
    );
    if (sort != null && mounted) {
      context.read<LinkListBloc>().add(
        LinkListQueryChanged(query.copyWith(sort: sort)),
      );
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
        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && selecting) {
              context.read<LinkListBloc>().add(
                const LinkListSelectionCleared(),
              );
            }
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: selecting
                ? _selectionAppBar(context, loaded!)
                : _appBar(context, loaded),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (widget.args.searchMode && !selecting)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageH,
                        AppSpacing.sm,
                        AppSpacing.pageH,
                        0,
                      ),
                      child: CustomTextField(
                        controller: _searchController,
                        hintText: context.l10n.searchHint,
                        prefixIcon: Icons.search_rounded,
                        autofocus: true,
                        onChanged: (value) => context.read<LinkListBloc>().add(
                          LinkListSearchChanged(value),
                        ),
                      ),
                    ),
                  if (loaded != null && !selecting) ...[
                    _ReadTabsRow(
                      query: loaded.query,
                      scope: widget.args.query,
                      onFilters: _openFilters,
                    ),
                    _ActiveFilters(
                      query: loaded.query,
                      scope: widget.args.query,
                    ),
                  ],
                  Expanded(child: _body(context, state)),
                ],
              ),
            ),
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

  PreferredSizeWidget _appBar(BuildContext context, LinkListLoaded? loaded) {
    return CommonAppBar(
      customTitle: _TitleWithCount(
        title: widget.args.title,
        count: loaded?.total,
      ),
      actions: [
        NeoBrutalistButton(
          icon: Icons.sort_rounded,
          shape: BoxShape.circle,
          onPressed: _openSort,
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
      titleText: context.l10n.listSelectedCount(loaded.selectedIds.length),
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
      LinkListError(:final message) => Center(child: Text(message)),
      LinkListLoaded(:final links) when links.isEmpty => EmptyState(
        icon: Icons.search_off_rounded,
        title: context.l10n.homeNoResultsTitle,
        subtitle: context.l10n.homeNoResultsSubtitle,
      ),
      LinkListLoaded() => _LinkRows(
        state: state,
        controller: _scrollController,
        searchQuery: state.query.search,
      ),
    };
  }
}

// ─── Header pieces ────────────────────────────────────────────────────────────

class _TitleWithCount extends StatelessWidget {
  const _TitleWithCount({required this.title, required this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium,
        ),
        if (count != null)
          Text(context.l10n.libraryLinkCount(count!), style: text.labelLarge),
      ],
    );
  }
}

/// All / Unread / Read tabs, plus the filter button with its count.
class _ReadTabsRow extends StatelessWidget {
  const _ReadTabsRow({
    required this.query,
    required this.scope,
    required this.onFilters,
  });

  final LinkQuery query;
  final LinkQuery scope;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filterCount = _userFilterCount(query, scope);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.md,
        AppSpacing.pageH,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentedTabs(
              labels: [l10n.listTabAll, l10n.libraryUnread, l10n.libraryRead],
              selectedIndex: query.readFilter.index,
              onSelected: (index) => context.read<LinkListBloc>().add(
                LinkListQueryChanged(
                  query.copyWith(readFilter: ReadFilter.values[index]),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Tooltip(
            message: l10n.listFilterTitle,
            child: Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              textColor: Theme.of(context).colorScheme.onPrimary,
              child: NeoBrutalistButton(
                icon: Icons.tune_rounded,
                shadowColor: AppColors.shadowSky,
                onPressed: onFilters,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filters the user added on top of the list's scope.
int _userFilterCount(LinkQuery query, LinkQuery scope) =>
    query.categories.difference(scope.categories).length +
    query.priorities.difference(scope.priorities).length +
    (query.host != null && query.host != scope.host ? 1 : 0);

/// Square segmented tabs: a 2px outlined bar with ink fill on the selected
/// segment (Litverse layout, DESIGN.md tokens).
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppSpacing.radiusMd);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: radius,
        border: Border.all(color: neo.borderColor, width: neo.borderWidth),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: neo.borderWidth,
                  thickness: neo.borderWidth,
                  color: neo.borderColor,
                ),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selectedIndex,
                  child: InkWell(
                    onTap: () => onSelected(i),
                    child: Container(
                      color: i == selectedIndex ? cs.primary : null,
                      alignment: Alignment.center,
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: i == selectedIndex
                              ? cs.onPrimary
                              : cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The user's filters as green chips; tapping one removes it.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.query, required this.scope});

  final LinkQuery query;
  final LinkQuery scope;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LinkListBloc>();
    final chips = <Widget>[
      for (final category in query.categories.difference(scope.categories))
        _RemovableChip(
          label: CategoryUtils.getLocalizedCategory(context, category),
          onRemove: () => bloc.add(
            LinkListQueryChanged(
              query.copyWith(
                categories: {...query.categories}..remove(category),
              ),
            ),
          ),
        ),
      for (final priority in query.priorities.difference(scope.priorities))
        _RemovableChip(
          label: _priorityLabel(context, priority),
          onRemove: () => bloc.add(
            LinkListQueryChanged(
              query.copyWith(
                priorities: {...query.priorities}..remove(priority),
              ),
            ),
          ),
        ),
      if (query.host != null && query.host != scope.host)
        _RemovableChip(
          label: query.host!,
          onRemove: () => bloc.add(
            LinkListQueryChanged(
              scope.host == null
                  ? query.copyWith(clearHost: true)
                  : query.copyWith(host: scope.host),
            ),
          ),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.sm + AppSpacing.xs,
        AppSpacing.pageH,
        0,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: chips,
        ),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onRemove,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md - AppSpacing.xs,
            AppSpacing.xs + 2,
            AppSpacing.sm,
            AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.accentGreen,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(color: AppColors.black, width: neo.borderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.close_rounded, size: 16, color: AppColors.black),
            ],
          ),
        ),
      ),
    );
  }
}

String _priorityLabel(BuildContext context, String priority) =>
    switch (priority.toLowerCase()) {
      'high' => context.l10n.priorityHigh,
      'low' => context.l10n.priorityLow,
      _ => context.l10n.priorityNormal,
    };

// ─── Rows ─────────────────────────────────────────────────────────────────────

class _LinkRows extends StatelessWidget {
  const _LinkRows({
    required this.state,
    required this.controller,
    required this.searchQuery,
  });

  final LinkListLoaded state;
  final ScrollController controller;
  final String searchQuery;

  bool get _byDate =>
      state.query.sort == LinkSort.newest || state.query.sort == LinkSort.oldest;

  @override
  Widget build(BuildContext context) {
    final rows = <Object>[];
    String? lastMonth;
    final monthFormat = DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    );
    for (final link in state.links) {
      if (_byDate) {
        final month = monthFormat.format(
          DateTime.fromMillisecondsSinceEpoch(
            link.createdAt,
            isUtc: true,
          ).toLocal(),
        );
        if (month != lastMonth) {
          rows.add(month);
          lastMonth = month;
        }
      }
      rows.add(link);
    }

    final bloc = context.read<LinkListBloc>();
    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.sm,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      itemCount: rows.length + (state.hasReachedMax ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == rows.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final row = rows[index];
        if (row is String) return _MonthHeader(label: row);
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
                  searchQuery: searchQuery,
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

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
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
/// bottom nav while selecting.
class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({required this.selectedCount});

  final int selectedCount;

  Future<void> _pickCategory(BuildContext context) async {
    final bloc = context.read<LinkListBloc>();
    final state = bloc.state;
    if (state is! LinkListLoaded) return;
    final category = await _showCategoryPicker(
      context,
      selectedIds: state.selectedIds,
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
                onTap: () => bloc.add(const LinkListBulkMarkReadRequested()),
              ),
              divider,
              _ActionCell(
                icon: Icons.label_outline_rounded,
                label: l10n.bulkCategory,
                onTap: () => _pickCategory(context),
              ),
              divider,
              _ActionCell(
                icon: Icons.flag_outlined,
                label: l10n.addLinkPriorityLabel,
                onTap: () => _pickPriority(context),
              ),
              divider,
              _ActionCell(
                icon: Icons.delete_outline_rounded,
                label: l10n.linkDeleteLabel,
                color: cs.error,
                onTap: () => _confirmDelete(context),
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
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.onSurface;
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

/// Bottom sheet chrome shared by the filter and category sheets.
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
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

/// Multi-select categories and priorities, and one source. Pops the new
/// [LinkQuery], or null when dismissed. State lives in [FilterSheetCubit].
class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  static const _priorities = ['High', 'Normal', 'Low'];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<FilterSheetCubit>();
    return BlocBuilder<FilterSheetCubit, FilterSheetState>(
      builder: (context, state) {
        final query = state.query;
        return _SheetFrame(
          title: l10n.listFilterTitle,
          trailing: l10n.listFilterMatches(state.matchCount),
          children: [
            _SheetLabel(l10n.homeCategoriesLabel),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final name in state.categories)
                  CategoryChip(
                    label: CategoryUtils.getLocalizedCategory(context, name),
                    isSelected: query.categories.contains(name),
                    onTap: () => cubit.toggleCategory(name),
                  ),
              ],
            ),
            _SheetLabel(l10n.homePrioritiesLabel),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final priority in _priorities)
                  CategoryChip(
                    label: _priorityLabel(context, priority),
                    isSelected: query.priorities.contains(priority),
                    onTap: () => cubit.togglePriority(priority),
                  ),
              ],
            ),
            if (state.sources.isNotEmpty) ...[
              _SheetLabel(l10n.listFilterSource),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final host in state.sources)
                    CategoryChip(
                      label: host,
                      isSelected: query.host == host,
                      onTap: () => cubit.toggleSource(host),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: NeoBrutalistButton(
                    text: l10n.listFilterReset,
                    variant: ButtonVariant.outlined,
                    onPressed: cubit.reset,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Expanded(
                  child: NeoBrutalistButton(
                    text: l10n.listFilterApply(state.matchCount),
                    onPressed: () => context.pop(query),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Picks one category to add to the selected links. Suggests categories from
/// the site when every selected link comes from the same one. State lives in
/// [CategoryPickerCubit].
Future<String?> _showCategoryPicker(
  BuildContext context, {
  required Set<String> selectedIds,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (_) => BlocProvider(
      create: (_) => CategoryPickerCubit(
        manager: locator<LinkManager>(),
        selectedIds: selectedIds,
      ),
      child: _CategoryPickerSheet(linkCount: selectedIds.length),
    ),
  );
}

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({required this.linkCount});

  final int linkCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CategoryPickerCubit>();
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
