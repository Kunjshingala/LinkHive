import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/link_metadata_service.dart';
import '../../../core/utils/utils.dart';
import '../models/link_model.dart';
import '../repository/link_repository.dart';
import 'add_link_event.dart';
import 'add_link_state.dart';

/// BLoC that manages all business logic for the Add / Edit Link screen.
///
/// ## Responsibilities
/// - Determines whether the screen is in **add mode** (new link) or
///   **edit mode** (updating an existing [LinkModel]).
/// - Orchestrates async metadata fetching via [LinkMetadataService] so the UI
///   gets a title, description, and preview image without writing any async
///   code itself.
/// - Validates form data and delegates persistence to [LinkRepository].
///
/// ## Event → State Flow
/// ```
/// AddLinkInitialized   →  AddLinkForm (blank or pre-filled)
/// AddLinkFetchMetadata →  AddLinkForm (isFetchingMetadata: true → false)
/// AddLinkFieldChanged  →  AddLinkForm (updated field values)
/// AddLinkSaveRequested →  AddLinkSaving → AddLinkSuccess | AddLinkError
/// ```
///
/// ## Usage
/// Provide this BLoC above the Add/Edit Link route using `BlocProvider`:
/// ```dart
/// BlocProvider(
///   create: (_) => AddLinkBloc(
///     repository: sl<LinkRepository>(),
///     metadataService: sl<LinkMetadataService>(),
///   )..add(AddLinkInitialized(existingLink: linkToEdit)),
///   child: const AddLinkScreen(),
/// )
/// ```
class AddLinkBloc extends Bloc<AddLinkEvent, AddLinkState> {
  /// Repository responsible for local (Hive) and remote (Firestore) CRUD.
  final LinkRepository _repository;

  /// Service that fetches Open Graph metadata (title, description, image)
  /// for a given URL. Results are used to auto-populate form fields.
  final LinkMetadataService _metadataService;

  /// UUID generator used to create a unique, stable ID for new links.
  /// Declared as `static const` so a single instance is shared across all
  /// [AddLinkBloc] instances — UUIDs are stateless and safe to share.
  static const _uuid = Uuid();

  /// Holds the [LinkModel] being edited when in edit mode.
  /// Null when adding a new link. Set during [_onInitialized] and read
  /// by [_onSaveRequested] to choose between `addLink` and `updateLink`.
  LinkModel? _editingLink;

  AddLinkBloc({required LinkRepository repository, required LinkMetadataService metadataService})
    : _repository = repository,
      _metadataService = metadataService,
      super(const AddLinkInitial()) {
    // Register a handler for every event type. Using named handlers keeps
    // each piece of logic isolated and independently testable.
    on<AddLinkInitialized>(_onInitialized);
    on<AddLinkFetchMetadata>(_onFetchMetadata);
    on<AddLinkFieldChanged>(_onFieldChanged);
    on<AddLinkSaveRequested>(_onSaveRequested);
  }

  // ─── Event Handlers ────────────────────────────────────────────────────────

  /// Handles [AddLinkInitialized].
  ///
  /// Decides whether to enter **edit mode** or **add mode**:
  ///
  /// **Edit mode** — [event.existingLink] is non-null:
  ///   Stores the link in [_editingLink] and emits a pre-populated
  ///   [AddLinkForm] with all of its current field values.
  ///
  /// **Add mode** — [event.existingLink] is null:
  ///   Emits a blank [AddLinkForm], optionally pre-filling the URL from
  ///   [event.prefillUrl] (e.g. from a share intent). If a prefill URL is
  ///   present, immediately dispatches [AddLinkFetchMetadata] so the title
  ///   and description are auto-populated without any extra user action.
  void _onInitialized(AddLinkInitialized event, Emitter<AddLinkState> emit) {
    _editingLink = event.existingLink;

    if (_editingLink != null) {
      // Edit mode: populate every form field from the existing link.
      emit(
        AddLinkForm(
          url: _editingLink!.url,
          title: _editingLink!.title,
          description: _editingLink!.description,
          image: _editingLink!.image,
          priority: _editingLink!.priority,
          categories: _editingLink!.categories,
        ),
      );
    } else {
      // Add mode: start with a blank form, optionally seeded with a URL.
      emit(AddLinkForm(url: event.prefillUrl ?? ''));

      // Auto-fetch metadata when a prefill URL is already available so the
      // user doesn't have to trigger it manually.
      if (event.prefillUrl != null && event.prefillUrl!.isNotEmpty) {
        add(AddLinkFetchMetadata(event.prefillUrl!));
      }
    }
  }

  /// Handles [AddLinkFetchMetadata].
  ///
  /// Shows a loading indicator by setting [AddLinkForm.isFetchingMetadata]
  /// to `true`, then calls [LinkMetadataService.fetchMetadata]. Fetched
  /// values are merged into the form conservatively — existing user-typed
  /// content is **never overwritten** by fetched data (only empty fields
  /// are populated).
  ///
  /// The loading flag is always cleared (set back to `false`) after the
  /// fetch, regardless of success or failure.
  Future<void> _onFetchMetadata(AddLinkFetchMetadata event, Emitter<AddLinkState> emit) async {
    // Snapshot the current form state; fall back to a blank form if for some
    // reason the state isn't AddLinkForm yet (defensive guard).
    final current = state is AddLinkForm ? state as AddLinkForm : const AddLinkForm();

    // Signal the UI to show a loading indicator while the network call runs.
    emit(current.copyWith(isFetchingMetadata: true));

    final metadata = await _metadataService.fetchMetadata(event.url);

    // Merge fetched values: only overwrite a field if it was previously empty.
    // This preserves any content the user may have already typed manually.
    final updated = current.copyWith(
      url: event.url,
      title: metadata.title.isNotEmpty ? metadata.title : current.title,
      description: metadata.description.isNotEmpty ? metadata.description : current.description,
      image: metadata.image.isNotEmpty ? metadata.image : current.image,
      isFetchingMetadata: false, // Always clear the loading indicator.
    );

    emit(updated);
  }

  /// Handles [AddLinkFieldChanged].
  ///
  /// Merges the changed field(s) from the event into the current
  /// [AddLinkForm] via `copyWith`. Only the non-null fields in the event
  /// are applied — all others remain unchanged.
  ///
  /// This handler is synchronous and very lightweight — no async work here.
  void _onFieldChanged(AddLinkFieldChanged event, Emitter<AddLinkState> emit) {
    final current = state is AddLinkForm ? state as AddLinkForm : const AddLinkForm();

    emit(
      current.copyWith(
        url: event.url,
        title: event.title,
        description: event.description,
        priority: event.priority,
        categories: event.categories,
      ),
    );
  }

  /// Handles [AddLinkSaveRequested].
  ///
  /// Full lifecycle:
  /// 1. **Guard** — if the state is not [AddLinkForm], do nothing (should
  ///    never happen in normal use but protects against race conditions).
  /// 2. **Validate** — URL must not be blank. On failure, emits [AddLinkError]
  ///    followed by the original [AddLinkForm] so the user can correct it.
  /// 3. **Emit [AddLinkSaving]** — tells the UI to disable the button and
  ///    show a progress indicator.
  /// 4. **Persist** — depending on [_editingLink]:
  ///    - **Edit mode**: creates an updated copy of `_editingLink` preserving
  ///      its `id` and `createdAt`, then calls `repository.updateLink`.
  ///    - **Add mode**: constructs a brand-new [LinkModel] with a fresh UUID
  ///      and a UTC epoch `createdAt` timestamp, then calls `repository.addLink`.
  /// 5. **Emit [AddLinkSuccess]** on success, or **[AddLinkError]** if the
  ///    repository throws.
  Future<void> _onSaveRequested(AddLinkSaveRequested event, Emitter<AddLinkState> emit) async {
    final current = state;

    // Guard: this handler should only run while the form is active.
    if (current is! AddLinkForm) return;

    // Validation: a URL is the minimum required field.
    if (current.url.trim().isEmpty) {
      emit(const AddLinkError('URL cannot be empty'));
      emit(current); // Revert to the form so the user can fix the error.
      return;
    }

    emit(const AddLinkSaving());

    try {
      if (_editingLink != null) {
        // ── Edit mode ────────────────────────────────────────────────────────
        // Build an updated copy of the existing link, preserving its identity
        // (id, createdAt) and only replacing the user-editable fields.
        // Falls back to the URL as the title if the user left it empty.
        final updatedLink = _editingLink!.copyWith(
          url: current.url.trim(),
          title: current.title.trim().isEmpty ? current.url.trim() : current.title.trim(),
          description: current.description.trim(),
          image: current.image,
          categories: current.categories,
          priority: current.priority,
        );

        await _repository.updateLink(updatedLink);
        printLog(tag: 'AddLinkBloc', msg: 'Updated link: ${updatedLink.title}');
      } else {
        // ── Add mode ─────────────────────────────────────────────────────────
        // Create a brand-new LinkModel with:
        //   • A UUID v4 as the stable, globally unique identifier.
        //   • createdAt set to the current moment in UTC milliseconds.
        //     Using epoch ms (instead of DateTime) keeps Hive serialization
        //     simple and avoids timezone/precision issues across platforms.
        //   • isSynced defaults to false; the repository will flip it to true
        //     once the link is successfully pushed to Firestore.
        final link = LinkModel(
          id: _uuid.v4(),
          url: current.url.trim(),
          title: current.title.trim().isEmpty ? current.url.trim() : current.title.trim(),
          description: current.description.trim(),
          image: current.image,
          categories: current.categories,
          priority: current.priority,
          createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
        );

        await _repository.addLink(link);
        printLog(tag: 'AddLinkBloc', msg: 'Saved link: ${link.title}');
      }

      emit(const AddLinkSuccess());
    } catch (e) {
      // Surface the exception message to the UI. The repository already logs
      // the full stack trace so we don't need to repeat it here.
      emit(AddLinkError('Failed to save link: $e'));
    }
  }
}
