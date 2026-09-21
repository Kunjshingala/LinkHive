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
                      final showUpNext = upNextLinks.isNotEmpty &&
                          state is LinksLoaded &&
                          !state.hasActiveFilter;
                      final upNextOffset = showUpNext ? 1 : 0;

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
                          itemCount: links.length +
                              upNextOffset +
                              (state is LinksLoaded && !state.hasReachedMax
                                  ? 1
                                  : 0),
                          separatorBuilder: (context, i) =>
                              SizedBox(height: AppSpacing.lg),
                          itemBuilder: (context, index) {
                            // ── Up Next strip ──
                            if (showUpNext && index == 0) {
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

                            final linkIndex = index - upNextOffset;

                            // ── Load-more indicator ──
                            if (linkIndex >= links.length) {
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

                            return Opacity(
                              opacity: links[linkIndex].isRead ? 0.55 : 1.0,
                              child: _NeoLinkCardWrapper(
                                child: LinkCard(
                                  link: links[linkIndex],
                                  searchQuery: searchQuery,
                                  onEdit: () => context.push(
                                    '/editLink',
                                    extra: links[linkIndex],
                                  ),
                                  onDelete: () => context.read<LinkBloc>().add(
                                    LinkDeleteRequested(links[linkIndex].id),
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
