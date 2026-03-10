import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/link_metadata_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/category_utils.dart';
import '../../../core/utils/locator.dart';
import '../../../core/utils/utils.dart';
import '../../../core/extensions/context_extension.dart';
import '../../../sharedWidgets/add_category_chip.dart';
import '../../../sharedWidgets/category_chip.dart';
import '../../../sharedWidgets/common_app_bar.dart';
import '../../../sharedWidgets/custom_button.dart';
import '../../../sharedWidgets/custom_text_field.dart';
import '../models/category_model.dart';
import '../models/link_model.dart';
import '../repository/link_repository.dart';
import '../bloc/add_link_bloc.dart';
import '../bloc/add_link_event.dart';
import '../bloc/add_link_state.dart';

class AddLinkScreen extends StatelessWidget {
  /// Optional URL pre-filled from share intent.
  final String? prefillUrl;
  final LinkModel? existingLink;

  const AddLinkScreen({super.key, this.prefillUrl, this.existingLink});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AddLinkBloc(repository: locator<LinkRepository>(), metadataService: locator<LinkMetadataService>())
            ..add(AddLinkInitialized(prefillUrl: prefillUrl, existingLink: existingLink)),
      child: _AddLinkContent(isEditing: existingLink != null),
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────
class _AddLinkContent extends StatefulWidget {
  final bool isEditing;
  const _AddLinkContent({required this.isEditing});

  @override
  State<_AddLinkContent> createState() => _AddLinkContentState();
}

class _AddLinkContentState extends State<_AddLinkContent> {
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _priority = 'Normal';
  final List<String> _selectedCategories = [];
  bool _didPopulate = false;

  // Custom categories loaded directly from the Hive repository.
  // We do NOT use LinkBloc here because AddLinkScreen is pushed as its own
  // GoRouter route and runs outside the HomeScreen widget tree where LinkBloc
  // is provided. Reading from the repository directly avoids a
  // ProviderNotFoundException at runtime.
  List<CategoryModel> _customCategories = [];

  @override
  void initState() {
    super.initState();
    _customCategories = locator<LinkRepository>().getCategories();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _populateFromState(AddLinkForm form) {
    if (!_didPopulate) {
      _urlCtrl.text = form.url;
      if (widget.isEditing) {
        _priority = form.priority;
        _selectedCategories.addAll(form.categories);
      }
      _didPopulate = true;
    }
    if (form.title.isNotEmpty && _titleCtrl.text.isEmpty) {
      _titleCtrl.text = form.title;
    }
    if (form.description.isNotEmpty && _descCtrl.text.isEmpty) {
      _descCtrl.text = form.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddLinkBloc, AddLinkState>(
      listener: (context, state) {
        if (state is AddLinkForm) _populateFromState(state);
        if (state is AddLinkSuccess) {
          showSnackBar(context.l10n.linkSavedSuccess);
          context.pop();
        }
        if (state is AddLinkError) {
          showSnackBar(state.message);
        }
      },
      builder: (context, state) {
        final isSaving = state is AddLinkSaving;
        final isFetching = state is AddLinkForm && state.isFetchingMetadata;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CommonAppBar(titleText: widget.isEditing ? 'Update Link' : context.l10n.addLinkTitle),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── URL Field ─────────────────────────────────────
                _SectionLabel(context.l10n.addLinkUrlLabel),
                SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _urlCtrl,
                        hintText: context.l10n.addLinkUrlHint,
                        keyboardType: TextInputType.url,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 200),
                      child: isFetching
                          ? SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Theme.of(context).colorScheme.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : NeoBrutalistButton(
                              icon: Icons.auto_fix_high_rounded,
                              shadowColor: AppColors.accentBlue,
                              onPressed: () {
                                final url = _urlCtrl.text.trim();
                                if (url.isNotEmpty) {
                                  context.read<AddLinkBloc>().add(AddLinkFetchMetadata(url));
                                }
                              },
                            ),
                    ),
                  ],
                ),

                SizedBox(height: AppSpacing.lg),

                // ─── Title ─────────────────────────────────────────
                _SectionLabel(context.l10n.addLinkPageTitleLabel),
                SizedBox(height: AppSpacing.xs),
                CustomTextField(controller: _titleCtrl, hintText: context.l10n.addLinkPageTitleHint),

                SizedBox(height: AppSpacing.lg),

                // ─── Description ───────────────────────────────────
                _SectionLabel(context.l10n.addLinkDescLabel),
                SizedBox(height: AppSpacing.xs),
                CustomTextField(controller: _descCtrl, hintText: context.l10n.addLinkDescHint, maxLines: 3),

                SizedBox(height: AppSpacing.lg),

                // ─── Priority ──────────────────────────────────────
                _SectionLabel(context.l10n.addLinkPriorityLabel),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [context.l10n.priorityHigh, context.l10n.priorityNormal, context.l10n.priorityLow].map((p) {
                    final isNormalKey = p == context.l10n.priorityNormal;
                    final selected = _priority == p || (isNormalKey && _priority == 'Normal');
                    return Padding(
                      padding: EdgeInsets.only(right: AppSpacing.sm),
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = p),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            border: Border.all(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          child: Text(
                            p,
                            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                              color: selected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : (Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                SizedBox(height: AppSpacing.lg),

                // ─── Categories ────────────────────────────────────
                _SectionLabel(context.l10n.addLinkCategoriesLabel),
                SizedBox(height: AppSpacing.sm),
                // No BlocBuilder here — AddLinkScreen is a standalone GoRouter
                // route with its own context; LinkBloc is not in scope.
                // Custom categories are loaded from the repository at initState
                // and updated locally via setState when the user adds one.
                Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs,
                  children: [
                    // ── Built-in suggested categories ──
                    ...CategoryUtils.suggestedCategories.map((cat) {
                      final selected = _selectedCategories.contains(cat);
                      return CategoryChip(
                        label: CategoryUtils.getLocalizedCategory(context, cat),
                        isSelected: selected,
                        onTap: () {
                          setState(() {
                            selected ? _selectedCategories.remove(cat) : _selectedCategories.add(cat);
                          });
                        },
                      );
                    }),

                    // ── User-created custom categories ──
                    ..._customCategories.map((cat) {
                      final selected = _selectedCategories.contains(cat.name);
                      return CategoryChip(
                        label: cat.name, // shown as-is; user authored it
                        isSelected: selected,
                        onTap: () {
                          setState(() {
                            selected ? _selectedCategories.remove(cat.name) : _selectedCategories.add(cat.name);
                          });
                        },
                      );
                    }),

                    // ── "+ New" chip ──
                    AddCategoryChip(
                      onAdd: (name) async {
                        // Persist directly via repository — no LinkBloc needed.
                        final newCat = CategoryModel(id: '', name: name);
                        await locator<LinkRepository>().addCategory(newCat);
                        // Refresh the local list and pre-select the new category.
                        setState(() {
                          _customCategories = locator<LinkRepository>().getCategories();
                          _selectedCategories.add(name);
                        });
                      },
                    ),
                  ],
                ),

                SizedBox(height: AppSpacing.xl),

                // ─── Save Button ───────────────────────────────────
                NeoBrutalistButton(
                  text: widget.isEditing ? 'Update Link' : context.l10n.saveLinkButton,
                  isLoading: isSaving,
                  onPressed: () {
                    context.read<AddLinkBloc>()
                      ..add(
                        AddLinkFieldChanged(
                          url: _urlCtrl.text,
                          title: _titleCtrl.text,
                          description: _descCtrl.text,
                          priority: _priority,
                          categories: List.from(_selectedCategories),
                        ),
                      )
                      ..add(AddLinkSaveRequested());
                  },
                ),

                SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Section Label ───────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600));
  }
}
