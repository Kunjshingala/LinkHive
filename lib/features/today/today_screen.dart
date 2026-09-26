import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/app_enums.dart';
import '../../core/extensions/context_extension.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/locator.dart';
import '../../core/utils/utils.dart';
import '../../sharedWidgets/common_app_bar.dart';
import '../../sharedWidgets/custom_button.dart';
import '../../sharedWidgets/empty_state.dart';
import '../links/models/link_model.dart';
import '../links/repository/link_repository.dart';
import 'bloc/today_bloc.dart';

/// The Daily Resurface focus screen: one link at a time, big preview.
///
/// Reached by tapping the daily notification, or manually from Home. Shows
/// [LinkRepository.getResurfaceCandidate] with three actions — Open, Archive,
/// Snooze — each advancing to the next candidate.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TodayBloc(repository: locator<LinkRepository>())..add(const TodayLoadRequested()),
      child: const _TodayContent(),
    );
  }
}

class _TodayContent extends StatelessWidget {
  const _TodayContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CommonAppBar(titleText: context.l10n.todayTitle),
      body: SafeArea(
        top: false,
        child: BlocBuilder<TodayBloc, TodayState>(
          builder: (context, state) {
            return switch (state) {
              TodayInitial() || TodayLoading() => Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              ),
              TodayEmpty() => EmptyState(
                icon: Icons.check_circle_outline_rounded,
                title: context.l10n.todayEmptyTitle,
                subtitle: context.l10n.todayEmptySubtitle,
              ),
              TodayLoaded(:final link) => _ResurfaceCard(link: link),
            };
          },
        ),
      ),
    );
  }
}

class _ResurfaceCard extends StatelessWidget {
  final LinkModel link;
  const _ResurfaceCard({required this.link});

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    final host = _host(link.url);

    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: neo.borderColor, width: neo.borderWidth),
              ),
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (link.image.isNotEmpty && !_isSvgUrl(link.image))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg - neo.borderWidth),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: link.image,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  SizedBox(height: AppSpacing.lg),
                  Text(
                    link.title.isNotEmpty ? link.title : link.url,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                  if (link.description.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.md),
                    Text(
                      link.description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: NeoBrutalistButton(
                  text: context.l10n.todaySnooze,
                  icon: Icons.snooze_rounded,
                  variant: ButtonVariant.outlined,
                  onPressed: () {
                    // Fired at the tap itself, not via a state listener — Snooze
                    // can leave the visible card unchanged (e.g. it's the only
                    // unread link left), so a state-based confirmation could
                    // silently never show in exactly the case it matters most.
                    showSnackBar(context.l10n.todaySnoozedConfirm);
                    context.read<TodayBloc>().add(const TodaySnoozeRequested());
                  },
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: NeoBrutalistButton(
                  text: context.l10n.todayArchive,
                  icon: Icons.inventory_2_outlined,
                  variant: ButtonVariant.outlined,
                  onPressed: () {
                    showSnackBar(context.l10n.todayArchivedConfirm);
                    context.read<TodayBloc>().add(const TodayArchiveRequested());
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          NeoBrutalistButton(
            text: context.l10n.todayOpen,
            icon: Icons.open_in_new_rounded,
            shadowColor: AppColors.success,
            onPressed: () => context.read<TodayBloc>().add(const TodayOpenRequested()),
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

bool _isSvgUrl(String url) {
  final path = url.toLowerCase().split('?').first;
  return path.endsWith('.svg');
}
