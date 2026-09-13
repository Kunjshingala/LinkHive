import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/app_enums.dart';
import '../../core/models/conflict_record.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/locator.dart';
import '../links/repository/link_repository.dart';
import '../../sharedWidgets/common_app_bar.dart';
import '../../sharedWidgets/custom_button.dart';
import 'bloc/conflict_bloc.dart';
import 'bloc/conflict_event.dart';
import 'bloc/conflict_state.dart';

class ConflictScreen extends StatelessWidget {
  const ConflictScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConflictBloc(repository: locator<LinkRepository>()),
      child: const _ConflictScreenContent(),
    );
  }
}

class _ConflictScreenContent extends StatelessWidget {
  const _ConflictScreenContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(titleText: 'Resolve conflicts'),
      body: BlocBuilder<ConflictBloc, ConflictState>(
        builder: (context, state) {
          if (state is ConflictLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ConflictError) {
            return Center(child: Text(state.message));
          }
          if (state is! ConflictLoaded || state.conflicts.isEmpty) {
            return const Center(child: Text('No conflicts require attention.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.pageH),
            itemCount: state.conflicts.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
            itemBuilder: (context, index) =>
                _ConflictCard(state.conflicts[index]),
          );
        },
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  final ConflictRecord conflict;

  const _ConflictCard(this.conflict);

  @override
  Widget build(BuildContext context) {
    final localTitle =
        conflict.localVersion['title'] as String? ?? conflict.linkId;
    final cloudTitle =
        conflict.cloudVersion?['title'] as String? ?? 'Deleted in cloud';
    final bloc = context.read<ConflictBloc>();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(localTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('Local: $localTitle'),
          Text('Cloud: $cloudTitle'),
          Text('Fields: ${conflict.conflictingFields.join(', ')}'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: NeoBrutalistButton(
                  text: 'Keep local',
                  variant: ButtonVariant.outlined,
                  onPressed: () =>
                      bloc.add(ConflictKeepLocalRequested(conflict.conflictId)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: NeoBrutalistButton(
                  text: 'Keep cloud',
                  onPressed: () =>
                      bloc.add(ConflictKeepCloudRequested(conflict.conflictId)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
