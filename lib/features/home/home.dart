import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/extensions/context_extension.dart';
import '../../core/services/sync_engine.dart';
import '../../core/utils/category_utils.dart';
import '../../core/utils/navigation/route.dart';
import '../../core/utils/locator.dart';
import '../../core/utils/utils.dart';
import '../../features/links/bloc/link_bloc.dart';
import '../../features/links/bloc/link_event.dart';
import '../../features/links/bloc/link_state.dart';
import '../../features/links/models/link_model.dart';
import '../../features/links/repository/link_repository.dart';
import '../../sharedWidgets/category_chip.dart';
import '../../sharedWidgets/confirmation_bottom_sheet.dart';
import '../../sharedWidgets/custom_button.dart';
import '../../sharedWidgets/custom_text_field.dart';
import '../../sharedWidgets/link_card.dart';
import '../../sharedWidgets/app_logo.dart';
import 'bloc/home_bloc.dart';
import 'bloc/home_event.dart';
import 'bloc/home_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => HomeBloc()),
        BlocProvider(
          create: (_) => LinkBloc(
            repository: locator<LinkRepository>(),
            syncEngine: locator<SyncEngine>(),
          )..add(const LinkLoadRequested()),
        ),
      ],
      child: const _HomeScreenContent(),
    );
  }
}

// ─── Main Content ─────────────────────────────────────────────────────────────
class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final linkState = context.read<LinkBloc>().state;
    if (linkState is LinksLoaded &&
        !linkState.isLoadingMore &&
        !linkState.hasReachedMax &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      context.read<LinkBloc>().add(LinkLoadNextPageRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeBloc, HomeState>(
      listener: (context, state) {
        if (state is HomeBackPressedOnce) {
          showSnackBar(context.l10n.pressBackAgainToExit);
        } else if (state is HomeCanExit) {
          context.pop();
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.read<HomeBloc>().add(HomeBackPressed());
        },
        child: Scaffold(
          resizeToAvoidBottomInset:
              false, // Prevent keyboard from pushing content up
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: () async {
                final completer = Completer<void>();
                context.read<LinkBloc>().add(
                  LinkSyncRequested(completer: completer),
                );
                return completer.future;
              },
              child: BlocConsumer<LinkBloc, LinkState>(
                listener: (context, state) {
                  if (state is LinkError &&
                      state.code == LinkErrorCode.duplicateCategory) {
                    showSnackBar(context.l10n.categoryAlreadyExists);
                  }
                },
                builder: (context, state) {
                  return CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      _buildSliverAppBar(context, state),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _buildFiltersDelegate(context, state),
                      ),
                      ..._buildContentSlivers(context, state),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Sliver App Bar ─────────────────────────────────────────────────────
  /// Collapsing app bar: the logo + "Links" title sits low when expanded and
  /// rises to the centre of the toolbar as the list scrolls up. The account
  /// and add buttons stay pinned as leading/action.
  Widget _buildSliverAppBar(BuildContext context, LinkState state) {
    final unread = state is LinksLoaded ? state.unreadCount : 0;
    return SliverAppBar(
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: AppColors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      expandedHeight: 132,
      leadingWidth: AppSpacing.appBarLeadingWidth,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpacing.pageH),
        child: NeoBrutalistButton(
          icon: Icons.person_outline_rounded,
          onPressed: () => context.pushNamed(MyRouteName.accountScreen),
          shape: BoxShape.circle,
        ),
      ),
      actions: [
        NeoBrutalistButton(
          icon: Icons.add_rounded,
          shadowColor: AppColors.success,
          onPressed: () {
            context.pushNamed(MyRouteName.addLink).then((value) {
              // ignore: use_build_context_synchronously
              if (context.mounted) {
                context.read<LinkBloc>().add(LinkLoadRequested());
              }
            });
          },
          shape: BoxShape.circle,
        ),
        const SizedBox(width: AppSpacing.pageH),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final settings = context
              .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          final maxE = settings?.maxExtent ?? constraints.maxHeight;
          final minE = settings?.minExtent ?? kToolbarHeight;
          // Clamp the extent so a top overscroll (currentExtent > maxExtent)
          // can't stretch the flexible space and drag the title down — it
          // stays put at the fully-expanded position.
          final currentE = (settings?.currentExtent ?? maxE)
              .clamp(minE, maxE)
              .toDouble();
          final delta = maxE - minE;
          // t = 0 fully expanded, t = 1 fully collapsed.
          final t = delta > 0 ? (1 - (currentE - minE) / delta) : 0.0;
          // f = 1 expanded → 0 collapsed. The title/logo shrink and the row
          // moves from bottom-left (aligned with the list) to the toolbar
          // centre. Bottom padding fades to 0 when collapsed so the row lands
          // on the same vertical line as the leading/action buttons.
          final f = 1 - t;
          final fontSize = 22 + 12 * f; // 34 expanded → 22 collapsed
          final logoSize = 24 + 10 * f; // 34 expanded → 24 collapsed
          // A fixed-height box pinned to the top of the (possibly stretched)
          // app bar, so its contents never follow an overscroll stretch.
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: currentE,
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.pageH,
                  right: AppSpacing.pageH,
                  bottom: AppSpacing.sm * f,
                ),
                child: Align(
                  alignment: Alignment(-1 + t, 1 - t),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppLogo(size: logoSize),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.homeTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium!
                            .copyWith(fontSize: fontSize),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        _unreadBadge(context, unread),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _unreadBadge(BuildContext context, int unread) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentOrange,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: Text(
        '$unread',
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  // ─── Pinned Filters ─────────────────────────────────────────────────────
  /// The pinned search + category + priority header. When collapsed by scroll
  /// the "Categories"/"Priorities" labels fade out, leaving just the search bar
  /// and the two horizontal chip rows.
  _PinnedFiltersDelegate _buildFiltersDelegate(
    BuildContext context,
    LinkState state,
  ) {
    final activeCategory = state is LinksLoaded
        ? state.activeCategory
        : context.l10n.categoryAll;
    final activePriority = state is LinksLoaded ? state.activePriority : 'All';
    final builtInCategories = [
      context.l10n.categoryAll,
      ...CategoryUtils.suggestedCategories,
    ];
    final customCategories = state is LinksLoaded
        ? state.customCategories
        : <dynamic>[];

    return _PinnedFiltersDelegate(
      background: Theme.of(context).scaffoldBackgroundColor,
      builder: (context, t) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageH,
            vertical: _kFilterVPad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: _kSearchH, child: _buildSearchBar(context)),
              const SizedBox(height: _kFilterGap),
              _collapsibleFilterLabel(context, context.l10n.homeCategoriesLabel, t),
              SizedBox(
                height: _kChipsH,
                child: _categoryChipsRow(
                  context,
                  builtInCategories,
                  customCategories,
                  activeCategory,
                ),
              ),
              // Gap between the two chip rows tightens as the header collapses.
              SizedBox(
                height: _kFilterGapCollapsed +
                    (_kFilterGap - _kFilterGapCollapsed) * (1 - t),
              ),
              _collapsibleFilterLabel(context, context.l10n.homePrioritiesLabel, t),
              SizedBox(
                height: _kChipsH,
                child: _priorityChipsRow(context, activePriority),
              ),
            ],
          ),
        );
      },
    );
  }

  /// A filter section label that collapses its height and fades out as the
  /// pinned header shrinks ([t] goes 0 → 1).
  Widget _collapsibleFilterLabel(BuildContext context, String text, double t) {
    final f = (1 - t).clamp(0.0, 1.0);
    return ClipRect(
      child: Align(
        alignment: Alignment.topLeft,
        heightFactor: f,
        child: Opacity(
          opacity: f,
          child: SizedBox(
            height: _kFilterLabelH,
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Content Slivers ────────────────────────────────────────────────────
  List<Widget> _buildContentSlivers(BuildContext context, LinkState state) {
    if (state is LinkLoading) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ];
    }

    final links = state is LinksLoaded ? state.links : const <LinkModel>[];
    final searchQuery = state is LinksLoaded ? state.searchQuery : '';

    if (links.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(
            context,
            state is LinksLoaded && state.hasActiveFilter,
          ),
        ),
      ];
    }

    final upNextLinks = state is LinksLoaded
        ? state.upNextLinks
        : const <LinkModel>[];
    final unreadCount = state is LinksLoaded ? state.unreadCount : 0;
    final noFilter = state is LinksLoaded && !state.hasActiveFilter;
    final showUpNext = upNextLinks.isNotEmpty && noFilter;
    final showAllCaughtUp = noFilter && unreadCount == 0 && links.isNotEmpty;
    final grouped = searchQuery.trim().isEmpty;
    final rows = _buildHomeRows(
      context,
      List<LinkModel>.from(links),
      grouped: grouped,
    );
    final hasMore = state is LinksLoaded && !state.hasReachedMax;

    return [
      if (showUpNext)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.md,
              AppSpacing.pageH,
              AppSpacing.lg,
            ),
            child: _UpNextStrip(
              links: upNextLinks,
              onLinkTap: (link) => _openUpNextLink(context, link),
            ),
          ),
        )
      else if (showAllCaughtUp)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageH,
              AppSpacing.md,
              AppSpacing.pageH,
              AppSpacing.lg,
            ),
            child: _AllCaughtUpBanner(),
          ),
        )
      else
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageH,
          0,
          AppSpacing.pageH,
          AppSpacing.xxl + 20,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= rows.length) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return _buildListItem(context, rows[index], searchQuery, index == 0);
          }, childCount: rows.length + (hasMore ? 1 : 0)),
        ),
      ),
    ];
  }

  Widget _buildListItem(
    BuildContext context,
    _HomeRow row,
    String searchQuery,
    bool isFirst,
  ) {
    // ── Time-group section header ──
    if (row is _HeaderRow) {
      return Padding(
        padding: EdgeInsets.only(
          top: isFirst ? 0 : AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        child: Text(
          row.label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }

    final link = (row as _LinkRow).link;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: _SwipeableNeoCard(link: link, searchQuery: searchQuery),
    );
  }

  Future<void> _openUpNextLink(BuildContext context, LinkModel link) async {
    final uri = Uri.tryParse(link.url);
    if (uri != null) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        showSnackBar('Could not open link');
      }
    }
    if (context.mounted) {
      context.read<LinkBloc>().add(LinkMarkAsRead(link.id));
    }
  }

  Widget _buildSearchBar(BuildContext context) {
    return CustomTextField(
      controller: _searchController,
      onChanged: (val) {
        setState(() {});
        context.read<LinkBloc>().add(LinkSearchChanged(val));
      },
      hintText: context.l10n.searchHint,
      prefixIcon: Icons.search_rounded,
      suffixIcon: _searchController.text.isEmpty
          ? null
          : IconButton(
              tooltip: context.l10n.searchClearTooltip,
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _searchController.clear();
                setState(() {});
                context.read<LinkBloc>().add(const LinkSearchChanged(''));
              },
            ),
      borderRadius: AppSpacing.radiusLg,
    );
  }

  /// Horizontal row of category filter chips (built-in + custom + "New").
  Widget _categoryChipsRow(
    BuildContext context,
    List builtInCategories,
    List customCategories,
    String activeCategory,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Built-in chips (All + suggested)
          ...builtInCategories.map((cat) {
            return Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: CategoryChip(
                label: CategoryUtils.getLocalizedCategory(context, cat),
                isSelected: activeCategory == cat,
                onTap: () {
                  context.read<LinkBloc>().add(LinkCategoryFilterChanged(cat));
                },
              ),
            );
          }),

          // User-created custom category chips with long-press to delete
          ...customCategories.map((cat) {
            return Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: GestureDetector(
                onLongPress: () async {
                  // Uses the project-standard confirmation bottom sheet
                  // (not AlertDialog — all popups must be bottom sheets).
                  final confirm = await showConfirmationBottomSheet(
                    context: context,
                    title: cat.name,
                    message: context.l10n.deleteCategoryConfirm,
                    confirmLabel: context.l10n.accountDelete,
                    cancelLabel: context.l10n.accountCancel,
                    titleIcon: Icons.label_off_rounded,
                    isDestructive: true,
                  );
                  if (confirm == true) {
                    // ignore: use_build_context_synchronously
                    context.read<LinkBloc>().add(
                      LinkCustomCategoryDeleted(cat.id),
                    );
                  }
                },
                child: CategoryChip(
                  label: cat.name, // shown as-is; user typed it
                  isSelected: activeCategory == cat.name,
                  onTap: () {
                    context.read<LinkBloc>().add(
                      LinkCategoryFilterChanged(cat.name),
                    );
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Horizontal row of priority filter chips.
  Widget _priorityChipsRow(BuildContext context, String activePriority) {
    final priorities = ['All', 'High', 'Normal', 'Low'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: priorities.map((prio) {
          final label = switch (prio) {
            'All' => context.l10n.categoryAll,
            'High' => context.l10n.priorityHigh,
            'Normal' => context.l10n.priorityNormal,
            'Low' => context.l10n.priorityLow,
            _ => prio,
          };
          return Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: CategoryChip(
              label: label,
              isSelected: activePriority == prio,
              onTap: () {
                context.read<LinkBloc>().add(LinkPriorityFilterChanged(prio));
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool hasActiveFilter) {
    if (hasActiveFilter) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                color: AppColors.success,
                size: 48,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.homeNoResultsTitle,
                style: Theme.of(context).textTheme.titleLarge!,
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.homeNoResultsSubtitle,
                style: Theme.of(context).textTheme.bodySmall!,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_rounded, color: AppColors.success, size: 48),
          SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.homeEmptyStateTitle,
            style: Theme.of(context).textTheme.titleLarge!,
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.homeEmptyStateSubtitle,
            style: Theme.of(context).textTheme.bodySmall!,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xl),
          // Neo-brutalist Action Button
          NeoBrutalistButton(
            text: context.l10n.addLinkButton,
            onPressed: () async {
              await context.pushNamed(MyRouteName.addLink);
              // Reload the list when AddLinkScreen pops.
              // ignore: use_build_context_synchronously
              if (context.mounted) {
                context.read<LinkBloc>().add(LinkLoadRequested());
              }
            },
            shadowColor: AppColors.success,
            width: 200,
          ),
        ],
      ),
    );
  }
}

// ─── Time Grouping ────────────────────────────────────────────────────────────

/// A single row in the Home list — either a time-section header or a link.
sealed class _HomeRow {
  const _HomeRow();
}

class _HeaderRow extends _HomeRow {
  final String label;
  const _HeaderRow(this.label);
}

class _LinkRow extends _HomeRow {
  final LinkModel link;
  const _LinkRow(this.link);
}

/// Buckets a link by save time: 0 = today, 1 = this week (last 7 days),
/// 2 = older. Uses the same `syncedAt ?? createdAt` timestamp the list is
/// sorted by, so headers appear in order with no repeats.
int _timeBucket(LinkModel link) {
  final ts = link.syncedAt ?? link.createdAt;
  final dt = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final linkDay = DateTime(dt.year, dt.month, dt.day);
  if (!linkDay.isBefore(today)) return 0;
  final weekAgo = today.subtract(const Duration(days: 7));
  if (linkDay.isAfter(weekAgo)) return 1;
  return 2;
}

String _bucketLabel(BuildContext context, int bucket) {
  switch (bucket) {
    case 0:
      return context.l10n.homeSectionToday;
    case 1:
      return context.l10n.homeSectionThisWeek;
    default:
      return context.l10n.homeSectionOlder;
  }
}

/// Flattens [links] into header + link rows. When [grouped] is false, returns
/// plain link rows with no headers (used while searching).
List<_HomeRow> _buildHomeRows(
  BuildContext context,
  List<LinkModel> links, {
  required bool grouped,
}) {
  if (!grouped) {
    return links.map<_HomeRow>((l) => _LinkRow(l)).toList();
  }
  final rows = <_HomeRow>[];
  int? currentBucket;
  for (final link in links) {
    final bucket = _timeBucket(link);
    if (bucket != currentBucket) {
      currentBucket = bucket;
      rows.add(_HeaderRow(_bucketLabel(context, bucket)));
    }
    rows.add(_LinkRow(link));
  }
  return rows;
}

// ─── All Caught Up Banner ─────────────────────────────────────────────────────

/// Shown at the top of the Home list (in place of the Up Next strip) when the
/// user has links saved but has opened every one of them.
class _AllCaughtUpBanner extends StatelessWidget {
  const _AllCaughtUpBanner();

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    return Stack(
      children: [
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(neo.shadowOffset - 1, neo.shadowOffset),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: neo.borderColor, width: neo.borderWidth),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: neo.borderColor, width: neo.borderWidth),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 28,
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.homeAllCaughtUpTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall!
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      context.l10n.homeAllCaughtUpSubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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

// ─── Up Next Strip ────────────────────────────────────────────────────────────

class _UpNextStrip extends StatelessWidget {
  final List<LinkModel> links;
  final void Function(LinkModel) onLinkTap;

  const _UpNextStrip({required this.links, required this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: AppColors.accentOrange),
            SizedBox(width: AppSpacing.xs),
            Text(
              'Up Next',
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: links.length,
            separatorBuilder: (context, i) => SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _UpNextCard(link: links[index], onTap: () => onLinkTap(links[index])),
          ),
        ),
      ],
    );
  }
}

class _UpNextCard extends StatefulWidget {
  final LinkModel link;
  final VoidCallback onTap;

  const _UpNextCard({required this.link, required this.onTap});

  @override
  State<_UpNextCard> createState() => _UpNextCardState();
}

class _UpNextCardState extends State<_UpNextCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final host = _host(widget.link.url);
    final dx = neo.shadowOffset - 1;
    final dy = neo.shadowOffset;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap();
      },
      onTapCancel: () => _setPressed(false),
      child: Stack(
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Container(
                width: 160,
                decoration: BoxDecoration(
                  color: AppColors.shadowLemon,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: neo.borderColor, width: neo.borderWidth),
                ),
              ),
            ),
          ),
          // Slides onto the shadow when pressed, matching the link cards.
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            width: 160,
            padding: EdgeInsets.all(AppSpacing.sm),
            transform: _pressed
                ? Matrix4.translationValues(dx, dy, 0)
                : Matrix4.identity(),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: neo.borderColor, width: neo.borderWidth),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.link.title.isNotEmpty ? widget.link.title : widget.link.url,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _host(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}

// ─── Swipeable Neo Card ───────────────────────────────────────────────────────

/// A link card with the Neo-Brutalist two-box look plus swipe actions.
///
/// The back (offset) box is the mint shadow at rest; while swiping it turns
/// green (mark read/unread) or red (delete) and shows the action icon — so the
/// action exactly follows the background box's border/offset while the
/// foreground card slides over it. confirmDismiss always returns false: reads
/// toggle in place, deletes remove the row via the bloc (no self-dismiss).
class _SwipeableNeoCard extends StatefulWidget {
  final LinkModel link;
  final String searchQuery;

  const _SwipeableNeoCard({required this.link, required this.searchQuery});

  @override
  State<_SwipeableNeoCard> createState() => _SwipeableNeoCardState();
}

class _SwipeableNeoCardState extends State<_SwipeableNeoCard> {
  DismissDirection? _direction;

  void _setDirection(DismissDirection? value) {
    if (_direction != value) setState(() => _direction = value);
  }

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final cs = Theme.of(context).colorScheme;
    final link = widget.link;

    // The back (offset) box: mint shadow at rest, green/red while swiping.
    Color boxColor = neo.shadowColor;
    IconData? actionIcon;
    AlignmentGeometry iconAlignment = Alignment.center;
    if (_direction == DismissDirection.startToEnd) {
      boxColor = AppColors.success;
      actionIcon = link.isRead
          ? Icons.mark_email_unread_rounded
          : Icons.check_circle_rounded;
      iconAlignment = AlignmentDirectional.centerStart;
    } else if (_direction == DismissDirection.endToStart) {
      boxColor = cs.error;
      actionIcon = Icons.delete_outline_rounded;
      iconAlignment = AlignmentDirectional.centerEnd;
    }

    return Stack(
      children: [
        // Back box (offset): the shadow, or the colored action while swiping.
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(neo.shadowOffset - 1, neo.shadowOffset),
            child: Container(
              alignment: iconAlignment,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: neo.borderColor,
                  width: neo.borderWidth,
                ),
              ),
              child: actionIcon == null
                  ? null
                  : Icon(actionIcon, color: AppColors.black, size: 26),
            ),
          ),
        ),
        // Foreground card slides over the back box. The Dismissible's own
        // backgrounds are empty — the colored reveal is the back box behind it.
        Dismissible(
          key: ValueKey('dismiss_${link.id}'),
          onUpdate: (details) =>
              _setDirection(details.progress > 0 ? details.direction : null),
          background: const SizedBox.shrink(),
          secondaryBackground: const SizedBox.shrink(),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              context.read<LinkBloc>().add(
                link.isRead
                    ? LinkMarkAsUnread(link.id)
                    : LinkMarkAsRead(link.id),
              );
              _setDirection(null);
              return false;
            }
            final confirm = await showConfirmationBottomSheet(
              context: context,
              title: context.l10n.linkDeleteTitle,
              message: context.l10n.linkDeleteMessage,
              confirmLabel: context.l10n.linkDeleteLabel,
              cancelLabel: context.l10n.accountCancel,
              titleIcon: Icons.warning_amber_rounded,
              isDestructive: true,
            );
            if (confirm == true && context.mounted) {
              context.read<LinkBloc>().add(LinkDeleteRequested(link.id));
            }
            if (mounted) _setDirection(null);
            return false;
          },
          child: Opacity(
            opacity: link.isRead ? 0.55 : 1.0,
            child: _PressableCard(
              child: LinkCard(
                link: link,
                searchQuery: widget.searchQuery,
                onEdit: () => context.push('/editLink', extra: link),
                onDelete: () =>
                    context.read<LinkBloc>().add(LinkDeleteRequested(link.id)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Adds the same press effect as [NeoBrutalistButton]: on tap the card slides
/// down-right onto its shadow so the offset gap collapses. The shadow itself is
/// drawn by [_SwipeableNeoCard] behind it.
///
/// The press is driven by a [Listener] (pointer events) rather than a gesture
/// recognizer, so it doesn't steal taps from the card's inner InkWell / 3-dot
/// menu or the surrounding Dismissible swipe. Movement past a small threshold
/// cancels the press so scrolling and swiping don't trigger a false press.
class _PressableCard extends StatefulWidget {
  final Widget child;

  const _PressableCard({required this.child});

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;
  Offset? _downPosition;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final dx = neo.shadowOffset - 1;
    final dy = neo.shadowOffset;

    return Listener(
      onPointerDown: (event) {
        _downPosition = event.position;
        _setPressed(true);
      },
      onPointerMove: (event) {
        // Cancel the press once the finger moves (a scroll or swipe), so the
        // effect only fires on genuine taps.
        if (_pressed &&
            _downPosition != null &&
            (event.position - _downPosition!).distance > 12) {
          _setPressed(false);
        }
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: _pressed
            ? Matrix4.translationValues(dx, dy, 0)
            : Matrix4.identity(),
        child: widget.child,
      ),
    );
  }
}

// ─── Pinned Filters Delegate ──────────────────────────────────────────────────

// Fixed heights used to compute the pinned filter header's extents. Kept a bit
// generous so the search field and chip rows never overflow their slots.
const double _kSearchH = 60;
const double _kChipsH = 44;
const double _kFilterLabelH = 28; // label text + its bottom gap
const double _kFilterGap = 16;
const double _kFilterGapCollapsed = 8; // gap between the two chip rows, pinned
const double _kFilterVPad = 8;

// Expanded height (labels shown, full gaps) and collapsed height (labels hidden
// and the category↔priority gap tightened).
const double _kFiltersMaxExtent = _kFilterVPad * 2 +
    _kSearchH +
    _kFilterGap +
    _kFilterLabelH +
    _kChipsH +
    _kFilterGap +
    _kFilterLabelH +
    _kChipsH;
const double _kFiltersMinExtent = _kFiltersMaxExtent -
    2 * _kFilterLabelH -
    (_kFilterGap - _kFilterGapCollapsed);

/// Pinned header holding the search bar + category/priority chip rows. Shrinks
/// from [_kFiltersMaxExtent] to [_kFiltersMinExtent] as it scrolls, collapsing
/// the section labels (driven via the `t` progress passed to [builder]).
class _PinnedFiltersDelegate extends SliverPersistentHeaderDelegate {
  final Color background;
  final Widget Function(BuildContext context, double t) builder;

  _PinnedFiltersDelegate({required this.background, required this.builder});

  @override
  double get minExtent => _kFiltersMinExtent;

  @override
  double get maxExtent => _kFiltersMaxExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    const range = _kFiltersMaxExtent - _kFiltersMinExtent;
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    return Container(color: background, child: builder(context, t));
  }

  @override
  bool shouldRebuild(_PinnedFiltersDelegate oldDelegate) => true;
}

// Nav Pill functionality removed
