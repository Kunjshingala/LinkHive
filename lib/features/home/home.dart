import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/extensions/context_extension.dart';
import '../../core/utils/category_utils.dart';
import '../../core/utils/navigation/route.dart';
import '../../core/utils/locator.dart';
import '../../core/utils/utils.dart';
import '../../features/links/bloc/link_bloc.dart';
import '../../features/links/bloc/link_event.dart';
import '../../features/links/bloc/link_state.dart';
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
        BlocProvider(create: (_) => LinkBloc(repository: locator<LinkRepository>())..add(LinkLoadRequested())),
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
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
          resizeToAvoidBottomInset: false, // Prevent keyboard from pushing content up
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ─── Header ─────────────────────────────────────────────
                _buildHeader(context),

                // ─── Body List ──────────────────────────────────────────
                Expanded(
                  child: BlocBuilder<LinkBloc, LinkState>(
                    builder: (context, state) {
                      if (state is LinkLoading) {
                        return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
                      }

                      final links = state is LinksLoaded ? state.links : [];

                      if (links.isEmpty) {
                        return _buildEmptyState(context);
                      }

                      return RefreshIndicator(
                        color: Theme.of(context).colorScheme.primary,
                        onRefresh: () async {
                          final completer = Completer<void>();
                          context.read<LinkBloc>().add(LinkSyncRequested(completer: completer));
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
                          itemCount: state is LinksLoaded && !state.hasReachedMax ? links.length + 1 : links.length,
                          separatorBuilder: (context, i) => SizedBox(height: AppSpacing.lg),
                          itemBuilder: (context, index) {
                            if (index >= links.length) {
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
                            return _NeoLinkCardWrapper(
                              child: LinkCard(
                                link: links[index],
                                onDelete: () => context.read<LinkBloc>().add(LinkDeleteRequested(links[index].id)),
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
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageH, vertical: AppSpacing.md),
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
          Row(
            children: [
              const AppLogo(size: 36),
              const SizedBox(width: 12),
              Text(context.l10n.homeTitle, style: Theme.of(context).textTheme.displayLarge!),
            ],
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
      onChanged: (val) => context.read<LinkBloc>().add(LinkSearchChanged(val)),
      hintText: context.l10n.searchHint,
      prefixIcon: Icons.search_rounded,
      borderRadius: AppSpacing.radiusLg,
    );
  }

  Widget _buildCategoryFilters(BuildContext context) {
    return BlocBuilder<LinkBloc, LinkState>(
      builder: (context, state) {
        final activeCategory = state is LinksLoaded ? state.activeCategory : context.l10n.categoryAll;
        final activePriority = state is LinksLoaded ? state.activePriority : 'All';

        // Build the category list: "All" + built-ins + user-created custom ones.
        // Reading customCategories from state (not repository directly) so the
        // row rebuilds reactively after every add/delete.
        final builtInCategories = [context.l10n.categoryAll, ...CategoryUtils.suggestedCategories];
        final customCategories = state is LinksLoaded ? state.customCategories : <dynamic>[];

        final priorities = ['All', 'High', 'Normal', 'Low'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Categories Label ---
            Text(
              context.l10n.homeCategoriesLabel,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600),
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
                            context.read<LinkBloc>().add(LinkCustomCategoryDeleted(cat.id));
                          }
                        },
                        child: CategoryChip(
                          label: cat.name, // shown as-is; user typed it
                          isSelected: activeCategory == cat.name,
                          onTap: () {
                            context.read<LinkBloc>().add(LinkCategoryFilterChanged(cat.name));
                          },
                        ),
                      ),
                    );
                  }),

                  // "+ New" chip — opens dialog to create a custom category
                  AddCategoryChip(onAdd: (name) => context.read<LinkBloc>().add(LinkCustomCategoryAdded(name))),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.md),
            // --- Priorities Label ---
            Text(
              context.l10n.homePrioritiesLabel,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600),
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
                        context.read<LinkBloc>().add(LinkPriorityFilterChanged(prio));
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_rounded, color: AppColors.success, size: 48),
          SizedBox(height: AppSpacing.md),
          Text(context.l10n.homeEmptyStateTitle, style: Theme.of(context).textTheme.titleLarge!),
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
                border: Border.all(color: neo.borderColor, width: neo.borderWidth),
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
