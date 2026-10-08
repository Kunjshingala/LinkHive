import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/link_metadata_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/category_utils.dart';
import '../../../core/utils/locator.dart';
import '../../../core/utils/navigation/route.dart';
import '../../../core/utils/saved_date.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/validator/validator.dart';
import '../../../core/extensions/context_extension.dart';
import '../../../sharedWidgets/add_category_chip.dart';
import '../../../sharedWidgets/category_chip.dart';
import '../../../sharedWidgets/common_app_bar.dart';
import '../../../sharedWidgets/custom_button.dart';
import '../../../sharedWidgets/custom_text_field.dart';
import '../../../sharedWidgets/saved_link_snackbar.dart';
import '../models/category_model.dart';
import '../models/link_model.dart';
import '../manager/link_manager.dart';
import '../models/link_exceptions.dart';
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
          AddLinkBloc(
            manager: locator<LinkManager>(),
            metadataService: locator<LinkMetadataService>(),
          )..add(
            AddLinkInitialized(
              prefillUrl: prefillUrl,
              existingLink: existingLink,
            ),
          ),
      child: _AddLinkContent(
        isEditing: existingLink != null,
        isRead: existingLink?.isRead ?? false,
      ),
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────
class _AddLinkContent extends StatefulWidget {
  final bool isEditing;

  /// Whether the link being edited has already been read/archived. Always
  /// `false` in add mode — a brand-new link is unread by definition.
  final bool isRead;

  const _AddLinkContent({required this.isEditing, required this.isRead});

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

  // "When should this come back?" — deliberately never pre-populated from an
  // existing link's resurfaceAt (see AddLinkForm.resurfaceAt doc): a raw
  // timestamp can't be reverse-mapped to one of these buckets, and starting
  // unselected means leaving it untouched preserves whatever schedule (if
  // any) the link already had, rather than silently guessing or clearing it.
  _ResurfaceChoice? _resurfaceChoice;

  // Custom categories loaded directly from the Hive repository.
  // We do NOT use LinkBloc here because AddLinkScreen is pushed as its own
  // GoRouter route and runs outside the HomeScreen widget tree where LinkBloc
  // is provided. Reading from the repository directly avoids a
  // ProviderNotFoundException at runtime.
  List<CategoryModel> _customCategories = [];

  @override
  void initState() {
    super.initState();
    _customCategories = locator<LinkManager>().getCategories();
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

  /// The URL was already saved: close the form and say the existing details
  /// were kept, with Edit (to change them) and Undo.
  ///
  /// The bar outlives this screen, and the AddLinkBloc closes with it, so both
  /// actions go to LinkManager and the global router captured here, never
  /// through the bloc. Edit re-reads the link so it never opens a stale copy.
  void _onMerged(BuildContext context, AddLinkMerged state) {
    final manager = locator<LinkManager>();
    final previous = state.previous;
    context.pop();
    showSavedLinkSnackBar(
      message: (context) => context.l10n.addAlreadySavedKept(
        formatSavedDate(
          DateTime.fromMillisecondsSinceEpoch(previous.createdAt),
          DateTime.now(),
          context.l10n,
        ),
      ),
      onEdit: () => router.pushNamed(
        MyRouteName.editLink,
        extra: manager.linkById(previous.id) ?? state.merged,
      ),
      onUndo: () => manager.undoMerge(previous),
    );
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
        if (state is AddLinkMerged) _onMerged(context, state);
        if (state is AddLinkError) {
          final message = switch (state.code) {
            AddLinkErrorCode.emptyUrl => context.l10n.addLinkUrlEmptyError,
            AddLinkErrorCode.invalidUrl => context.l10n.addLinkInvalidUrlError,
            null => state.message,
          };
          showSnackBar(message);
        }
      },
      builder: (context, state) {
        final isSaving = state is AddLinkSaving;
        final isFetching = state is AddLinkForm && state.isFetchingMetadata;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CommonAppBar(
            titleText: widget.isEditing
                ? 'Update Link'
                : context.l10n.addLinkTitle,
          ),
          body: SingleChildScrollView(
            padding: AppSpacing.pagePadding,
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
                        // Every URL edit invalidates the previous metadata
                        // request. The BLoC debounces these events and starts
                        // one fetch for the latest valid URL after typing
                        // pauses.
                        onChanged: (value) => context.read<AddLinkBloc>().add(
                          AddLinkFieldChanged(url: value),
                        ),
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : NeoBrutalistButton(
                              icon: Icons.auto_fix_high_rounded,
                              shadowColor: AppColors.accentBlue,
                              onPressed: () {
                                final normalizedUrl = normalizeUrl(
                                  _urlCtrl.text,
                                );
                                if (normalizedUrl != null) {
                                  _urlCtrl.text = normalizedUrl;
                                  context.read<AddLinkBloc>().add(
                                    AddLinkFetchMetadata(normalizedUrl),
                                  );
                                } else {
                                  showSnackBar(
                                    context.l10n.addLinkInvalidUrlError,
                                  );
                                }
                              },
                            ),
                    ),
                  ],
                ),

                SizedBox(height: AppSpacing.lg),

                // ─── Image Preview ─────────────────────────────────
                if (state is AddLinkForm &&
                    state.image.isNotEmpty &&
                    !_isSvgUrl(state.image)) ...[
                  _ImagePreview(imageUrl: state.image),
                  SizedBox(height: AppSpacing.lg),
                ],

                // ─── Title ─────────────────────────────────────────
                _SectionLabel(context.l10n.addLinkPageTitleLabel),
                SizedBox(height: AppSpacing.xs),
                CustomTextField(
                  controller: _titleCtrl,
                  hintText: context.l10n.addLinkPageTitleHint,
                ),

                SizedBox(height: AppSpacing.lg),

                // ─── Description ───────────────────────────────────
                _SectionLabel(context.l10n.addLinkDescLabel),
                SizedBox(height: AppSpacing.xs),
                CustomTextField(
                  controller: _descCtrl,
                  hintText: context.l10n.addLinkDescHint,
                  maxLines: 3,
                ),

                SizedBox(height: AppSpacing.lg),

                // ─── Priority ──────────────────────────────────────
                _SectionLabel(context.l10n.addLinkPriorityLabel),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children:
                      [
                        context.l10n.priorityHigh,
                        context.l10n.priorityNormal,
                        context.l10n.priorityLow,
                      ].map((p) {
                        final isNormalKey = p == context.l10n.priorityNormal;
                        final selected =
                            _priority == p ||
                            (isNormalKey && _priority == 'Normal');
                        return Padding(
                          padding: EdgeInsets.only(right: AppSpacing.sm),
                          // Reuse CategoryChip so priority chips share the exact
                          // Neo-Brutalist border/shadow as the category chips below
                          // and the Home filter chips.
                          child: CategoryChip(
                            label: p,
                            isSelected: selected,
                            onTap: () => setState(() => _priority = p),
                          ),
                        );
                      }).toList(),
                ),

                SizedBox(height: AppSpacing.lg),

                // ─── When should this come back? ───────────────────
                // Hidden once a link is already read/archived: the Daily
                // Resurface engine only ever considers unread links, so
                // scheduling one here would be a control with no effect.
                if (!widget.isRead) ...[
                  _SectionLabel(context.l10n.addLinkWhenLabel),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children:
                        [
                          (
                            _ResurfaceChoice.tonight,
                            context.l10n.addLinkWhenTonight,
                          ),
                          (
                            _ResurfaceChoice.weekend,
                            context.l10n.addLinkWhenWeekend,
                          ),
                          (
                            _ResurfaceChoice.someday,
                            context.l10n.addLinkWhenSomeday,
                          ),
                        ].map((entry) {
                          final (choice, label) = entry;
                          final selected = _resurfaceChoice == choice;
                          return Padding(
                            padding: EdgeInsets.only(right: AppSpacing.sm),
                            child: CategoryChip(
                              label: label,
                              isSelected: selected,
                              // Tapping the already-selected chip deselects it —
                              // back to "untouched" (leave any existing schedule
                              // alone), matching the category chips' toggle feel.
                              onTap: () => setState(
                                () =>
                                    _resurfaceChoice = selected ? null : choice,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  SizedBox(height: AppSpacing.lg),
                ],

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
                            selected
                                ? _selectedCategories.remove(cat)
                                : _selectedCategories.add(cat);
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
                            selected
                                ? _selectedCategories.remove(cat.name)
                                : _selectedCategories.add(cat.name);
                          });
                        },
                      );
                    }),

                    // ── "+ New" chip ──
                    AddCategoryChip(
                      onAdd: (name) async {
                        // Persist directly via repository — no LinkBloc needed.
                        final newCat = CategoryModel(id: '', name: name);
                        try {
                          await locator<LinkManager>().addCategory(newCat);
                          if (!context.mounted) return;
                          // Refresh the local list and pre-select the new category.
                          setState(() {
                            _customCategories = locator<LinkManager>()
                                .getCategories();
                            _selectedCategories.add(name);
                          });
                        } on CategoryAlreadyExistsException {
                          if (!context.mounted) return;
                          showSnackBar(context.l10n.categoryAlreadyExists);
                        }
                      },
                    ),
                  ],
                ),

                SizedBox(height: AppSpacing.xl),

                // ─── Save Button ───────────────────────────────────
                NeoBrutalistButton(
                  text: widget.isEditing
                      ? 'Update Link'
                      : context.l10n.saveLinkButton,
                  isLoading: isSaving,
                  onPressed: () {
                    final rawUrl = _urlCtrl.text.trim();
                    if (rawUrl.isEmpty) {
                      showSnackBar(context.l10n.addLinkUrlEmptyError);
                      return;
                    }

                    final normalizedUrl = normalizeUrl(rawUrl);
                    if (normalizedUrl == null) {
                      showSnackBar(context.l10n.addLinkInvalidUrlError);
                      return;
                    }
                    _urlCtrl.text = normalizedUrl;

                    context.read<AddLinkBloc>()
                      ..add(
                        AddLinkFieldChanged(
                          url: normalizedUrl,
                          title: _titleCtrl.text,
                          description: _descCtrl.text,
                          priority: _priority,
                          categories: List.from(_selectedCategories),
                          resurfaceAt: switch (_resurfaceChoice) {
                            _ResurfaceChoice.tonight => _resurfaceTonight(),
                            _ResurfaceChoice.weekend => _resurfaceWeekend(),
                            _ResurfaceChoice.someday || null => null,
                          },
                          clearResurfaceAt:
                              _resurfaceChoice == _ResurfaceChoice.someday,
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

// ─── Image Preview ───────────────────────────────────────────────────────────
class _ImagePreview extends StatelessWidget {
  final String imageUrl;
  const _ImagePreview({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final neo = context.neoBrutal;
    // Single border on all sides (matching the text fields). The border lives
    // in `decoration`, which insets the child by its width, and the image is
    // clipped to the inner radius (outer - borderWidth) so it nests inside the
    // border and never spills over the rounded corners.
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: neo.borderColor, width: neo.borderWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          AppSpacing.radiusMd - neo.borderWidth,
        ),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          // Fill the inner box so BoxFit.cover has bounds to cover — without
          // explicit sizing the image lays out at its intrinsic size.
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (context, url, error) => Center(
            child: Icon(Icons.broken_image_outlined, color: neo.borderColor),
          ),
        ),
      ),
    );
  }
}

bool _isSvgUrl(String url) {
  final path = url.toLowerCase().split('?').first;
  return path.endsWith('.svg');
}

/// The three "when should this come back?" choices. `someday` is an
/// affirmative "not urgent" pick — it behaves identically to leaving the
/// picker untouched (both fall into the general spaced resurface pool) but
/// exists so choosing "no specific time" doesn't feel like skipping.
enum _ResurfaceChoice { tonight, weekend, someday }

/// "Tonight" → today at 8pm local, or tomorrow 8pm if that's already passed.
int _resurfaceTonight() {
  final now = DateTime.now();
  var target = DateTime(now.year, now.month, now.day, 20, 0);
  if (target.isBefore(now)) target = target.add(const Duration(days: 1));
  return target.toUtc().millisecondsSinceEpoch;
}

/// "Weekend" → the coming Saturday at 10am local (today, if it's already
/// Saturday and still before 10am; otherwise the next one).
int _resurfaceWeekend() {
  final now = DateTime.now();
  final daysUntilSaturday = (DateTime.saturday - now.weekday) % 7;
  var target = DateTime(
    now.year,
    now.month,
    now.day,
    10,
    0,
  ).add(Duration(days: daysUntilSaturday));
  if (target.isBefore(now)) target = target.add(const Duration(days: 7));
  return target.toUtc().millisecondsSinceEpoch;
}

// ─── Section Label ───────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
