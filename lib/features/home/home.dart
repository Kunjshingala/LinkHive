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
import '../../sharedWidgets/add_category_chip.dart';
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
            child: Column(
              children: [
                // ─── Header ─────────────────────────────────────────────
                _buildHeader(context),

                // ─── Body List ──────────────────────────────────────────
                Expanded(
                  child: BlocConsumer<LinkBloc, LinkState>(
                    listener: (context, state) {
                      if (state is LinkError &&
                          state.code == LinkErrorCode.duplicateCategory) {
                        showSnackBar(context.l10n.categoryAlreadyExists);
                      }
                    },
                    builder: (context, state) {
                      if (state is LinkLoading) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      }

                      final links = state is LinksLoaded ? state.links : [];
                      final searchQuery = state is LinksLoaded
                          ? state.searchQuery
                          : '';

                      if (links.isEmpty) {
                        return _buildEmptyState(
                          context,
                          state is LinksLoaded && state.hasActiveFilter,
                        );
                      }

                      final upNextLinks = state is LinksLoaded
                          ? state.upNextLinks
                          : <LinkModel>[];
                      final unreadCount =
                          state is LinksLoaded ? state.unreadCount : 0;
                      final noFilter =
                          state is LinksLoaded && !state.hasActiveFilter;
                      final showUpNext = upNextLinks.isNotEmpty && noFilter;
                      // When there are links but none are unread, the Up Next
                      // strip is replaced by an "All caught up" banner.
                      final showAllCaughtUp =
                          noFilter && unreadCount == 0 && links.isNotEmpty;
                      final topOffset = (showUpNext || showAllCaughtUp) ? 1 : 0;

                      // Group the list under Today / This week / Older headers.
                      // Disabled during an active search so short result sets
                      // aren't cluttered with section labels.
                      final grouped = searchQuery.trim().isEmpty;
                      final rows = _buildHomeRows(
                        context,
                        List<LinkModel>.from(links),
                        grouped: grouped,
                      );

                      return RefreshIndicator(
                        color: Theme.of(context).colorScheme.primary,
                        onRefresh: () async {
                          final completer = Completer<void>();
                          context.read<LinkBloc>().add(
                            LinkSyncRequested(completer: completer),
                          );
                          return completer.future;
                        },
                        child: ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.pageH,
                            AppSpacing.md,
                            AppSpacing.pageH,
                            AppSpacing.xxl + 20,
                          ),
                          itemCount: rows.length +
                              topOffset +
                              (state is LinksLoaded && !state.hasReachedMax
                                  ? 1
                                  : 0),
                          separatorBuilder: (context, i) =>
                              SizedBox(height: AppSpacing.lg),
                          itemBuilder: (context, index) {
                            // ── Top slot: Up Next strip or All caught up ──
                            if (topOffset == 1 && index == 0) {
                              if (showUpNext) {
                                return _UpNextStrip(
                                  links: upNextLinks,
                                  onLinkTap: (link) async {
                                    final uri = Uri.tryParse(link.url);
                                    if (uri != null) {
                                      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      if (!launched && context.mounted) {
                                        showSnackBar('Could not open link');
                                      }
                                    }
                                    if (context.mounted) {
                                      context.read<LinkBloc>().add(LinkMarkAsRead(link.id));
                                    }
                                  },
                                );
                              }
                              return const _AllCaughtUpBanner();
                            }

                            final rowIndex = index - topOffset;

                            // ── Load-more indicator ──
                            if (rowIndex >= rows.length) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.all(AppSpacing.md),
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Theme.of(context).colorScheme.primary,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final row = rows[rowIndex];

                            // ── Time-group section header ──
                            if (row is _HeaderRow) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  top: rowIndex == 0 ? 0 : AppSpacing.sm,
                                  bottom: AppSpacing.xs,
                                ),
                                child: Text(
                                  row.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge!
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                              );
                            }

                            final link = (row as _LinkRow).link;
                            return Dismissible(
                              key: ValueKey('dismiss_${link.id}'),
                              // Right swipe (startToEnd): toggle read/unread.
                              background: _SwipeActionBackground(
                                alignment: AlignmentDirectional.centerStart,
                                color: AppColors.success,
                                icon: link.isRead
                                    ? Icons.mark_email_unread_rounded
                                    : Icons.check_circle_rounded,
                              ),
                              // Left swipe (endToStart): delete.
                              secondaryBackground: _SwipeActionBackground(
                                alignment: AlignmentDirectional.centerEnd,
                                color: Theme.of(context).colorScheme.error,
                                icon: Icons.delete_outline_rounded,
                              ),
                              // Return false in every branch: the card never
                              // dismisses itself. Read toggles rebuild in place;
                              // delete removes the row via the bloc's list update,
                              // avoiding Flutter's "dismissed widget still in tree".
                              confirmDismiss: (direction) async {
                                if (direction ==
                                    DismissDirection.startToEnd) {
                                  context.read<LinkBloc>().add(
                                    link.isRead
                                        ? LinkMarkAsUnread(link.id)
                                        : LinkMarkAsRead(link.id),
                                  );
                                  return false;
                                }
                                final confirm =
                                    await showConfirmationBottomSheet(
                                  context: context,
                                  title: context.l10n.linkDeleteTitle,
                                  message: context.l10n.linkDeleteMessage,
                                  confirmLabel: context.l10n.linkDeleteLabel,
                                  cancelLabel: context.l10n.accountCancel,
                                  titleIcon: Icons.warning_amber_rounded,
                                  isDestructive: true,
                                );
                                if (confirm == true && context.mounted) {
                                  context.read<LinkBloc>().add(
                                    LinkDeleteRequested(link.id),
                                  );
                                }
                                return false;
                              },
                              child: Opacity(
                                opacity: link.isRead ? 0.55 : 1.0,
                                child: _NeoLinkCardWrapper(
                                  child: LinkCard(
                                    link: link,
                                    searchQuery: searchQuery,
                                    onEdit: () => context.push(
                                      '/editLink',
                                      extra: link,
                                    ),
                                    onDelete: () => context.read<LinkBloc>().add(
                                      LinkDeleteRequested(link.id),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pageH,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Account Button
              NeoBrutalistButton(
                icon: Icons.person_outline_rounded,
                onPressed: () => context.pushNamed(MyRouteName.accountScreen),
                shape: BoxShape.circle,
              ),
              // Plus icon
              NeoBrutalistButton(
                icon: Icons.add_rounded,
                shadowColor: AppColors.success,
                onPressed: () {
                  context.pushNamed(MyRouteName.addLink).then((value) {
                    // Reload the list when AddLinkScreen pops (save or cancel).
                    // ignore: use_build_context_synchronously
                    if (context.mounted) {
                      context.read<LinkBloc>().add(LinkLoadRequested());
                    }
                  });
                },
                shape: BoxShape.circle,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          BlocBuilder<LinkBloc, LinkState>(
            buildWhen: (prev, next) {
              final p = prev is LinksLoaded ? prev.unreadCount : 0;
              final n = next is LinksLoaded ? next.unreadCount : 0;
              return p != n;
            },
            builder: (context, state) {
              final unread = state is LinksLoaded ? state.unreadCount : 0;
              return Row(
                children: [
                  const AppLogo(size: 36),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.homeTitle,
                    style: Theme.of(context).textTheme.displayLarge!,
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
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
                    ),
                  ],
                ],
              );
            },
          ),
          SizedBox(height: AppSpacing.md),
          _buildSearchBar(context),
          SizedBox(height: AppSpacing.md),
          _buildCategoryFilters(context),
        ],
      ),
    );
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

  Widget _buildCategoryFilters(BuildContext context) {
    return BlocBuilder<LinkBloc, LinkState>(
      builder: (context, state) {
        final activeCategory = state is LinksLoaded
            ? state.activeCategory
            : context.l10n.categoryAll;
        final activePriority = state is LinksLoaded
            ? state.activePriority
            : 'All';

        // Build the category list: "All" + built-ins + user-created custom ones.
        // Reading customCategories from state (not repository directly) so the
        // row rebuilds reactively after every add/delete.
        final builtInCategories = [
          context.l10n.categoryAll,
          ...CategoryUtils.suggestedCategories,
        ];
        final customCategories = state is LinksLoaded
            ? state.customCategories
            : <dynamic>[];

        final priorities = ['All', 'High', 'Normal', 'Low'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Categories Label ---
            Text(
              context.l10n.homeCategoriesLabel,
              style: Theme.of(
                context,
              ).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
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
                          context.read<LinkBloc>().add(
                            LinkCategoryFilterChanged(cat),
                          );
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

                  // "+ New" chip — opens dialog to create a custom category
                  AddCategoryChip(
                    onAdd: (name) => context.read<LinkBloc>().add(
                      LinkCustomCategoryAdded(name),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.md),
            // --- Priorities Label ---
            Text(
              context.l10n.homePrioritiesLabel,
              style: Theme.of(
                context,
              ).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
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
                        context.read<LinkBloc>().add(
                          LinkPriorityFilterChanged(prio),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
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

class _UpNextCard extends StatelessWidget {
  final LinkModel link;
  final VoidCallback onTap;

  const _UpNextCard({required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final host = _host(link.url);

    return Stack(
      children: [
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(neo.shadowOffset - 1, neo.shadowOffset),
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              width: 160,
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: neo.borderColor, width: neo.borderWidth),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.title.isNotEmpty ? link.title : link.url,
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
          ),
        ),
      ],
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

// ─── Swipe Action Background ──────────────────────────────────────────────────

/// The colored panel revealed behind a link card during a swipe. [alignment]
/// controls which edge the icon hugs so it appears from the swiped side.
class _SwipeActionBackground extends StatelessWidget {
  final AlignmentGeometry alignment;
  final Color color;
  final IconData icon;

  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    return Container(
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: neo.borderColor, width: neo.borderWidth),
      ),
      child: Icon(icon, color: AppColors.black, size: 26),
    );
  }
}

// ─── Neo Brutalist Card Wrapper ───────────────────────────────────────
class _NeoLinkCardWrapper extends StatelessWidget {
  final Widget child;

  const _NeoLinkCardWrapper({required this.child});

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
                color: neo.shadowColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: neo.borderColor,
                  width: neo.borderWidth,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// Nav Pill functionality removed
