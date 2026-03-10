import 'package:equatable/equatable.dart';

/// Base sealed class for all states emitted by [AddLinkBloc].
///
/// The state machine follows this lifecycle:
///
/// ```
///  AddLinkInitial
///       │
///       ▼
///  AddLinkForm  ◄──────────── (user edits fields / metadata fetched)
///       │
///       ▼  (save pressed)
///  AddLinkSaving
///       │
///   ┌───┴───┐
///   ▼       ▼
/// Success  Error ──► AddLinkForm  (reverted so user can correct and retry)
/// ```
///
/// The UI listens to this state stream via `BlocConsumer` / `BlocBuilder` and
/// renders different widgets depending on which subclass is active.
sealed class AddLinkState extends Equatable {
  const AddLinkState();

  @override
  List<Object?> get props => [];
}

/// The very first state before [AddLinkInitialized] has been processed.
///
/// Typically the UI shows a loading indicator or blank screen while in this
/// state. It transitions to [AddLinkForm] as soon as the BLoC handles
/// the [AddLinkInitialized] event.
class AddLinkInitial extends AddLinkState {
  const AddLinkInitial();
}

/// The primary interactive state — represents the current data in the form.
///
/// Emitted:
/// - After [AddLinkInitialized] to populate the form (blank or pre-filled).
/// - After every [AddLinkFieldChanged] to reflect user edits.
/// - After [AddLinkFetchMetadata] completes to inject fetched title/description/image.
/// - After a failed save, to allow the user to correct and re-submit.
///
/// The UI should render a form whose input controllers are wired to the
/// values in this state.
class AddLinkForm extends AddLinkState {
  /// The full URL the user wants to save (e.g. "https://flutter.dev").
  final String url;

  /// Human-readable title. Falls back to [url] if the user leaves it empty.
  final String title;

  /// Optional description or notes about the link.
  final String description;

  /// URL of the preview/thumbnail image fetched from Open Graph metadata.
  /// Empty string when no image is available.
  final String image;

  /// Priority level string: 'High', 'Normal', or 'Low'.
  /// Defaults to 'Normal'.
  final String priority;

  /// List of category names/IDs associated with this link.
  final List<String> categories;

  /// True while [LinkMetadataService] is fetching Open Graph data for the URL.
  /// The UI should show an inline loading indicator while this is true.
  final bool isFetchingMetadata;

  const AddLinkForm({
    this.url = '',
    this.title = '',
    this.description = '',
    this.image = '',
    this.priority = 'Normal',
    this.categories = const [],
    this.isFetchingMetadata = false,
  });

  /// Returns a copy of this state with the specified fields replaced.
  ///
  /// Only pass the fields you want to change — all other fields retain their
  /// current value. This pattern keeps the BLoC handlers concise.
  AddLinkForm copyWith({
    String? url,
    String? title,
    String? description,
    String? image,
    String? priority,
    List<String>? categories,
    bool? isFetchingMetadata,
  }) {
    return AddLinkForm(
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      image: image ?? this.image,
      priority: priority ?? this.priority,
      categories: categories ?? this.categories,
      isFetchingMetadata: isFetchingMetadata ?? this.isFetchingMetadata,
    );
  }

  @override
  List<Object?> get props => [url, title, description, image, priority, categories, isFetchingMetadata];
}

/// Emitted while the repository `addLink` / `updateLink` call is in-flight.
///
/// The UI should disable the save button and show a progress indicator to
/// prevent the user from submitting the form multiple times.
class AddLinkSaving extends AddLinkState {
  const AddLinkSaving();
}

/// Emitted once the link has been successfully persisted (locally + cloud).
///
/// The UI typically responds to this state by navigating away from the
/// Add/Edit screen (e.g. `context.pop()` via go_router).
class AddLinkSuccess extends AddLinkState {
  const AddLinkSuccess();
}

/// Emitted when validation fails or the repository throws an exception.
///
/// After emitting this state, [AddLinkBloc] immediately re-emits the previous
/// [AddLinkForm] state so the user can see the error, correct their input,
/// and try saving again.
class AddLinkError extends AddLinkState {
  /// Human-readable error message suitable for display in a snack bar or
  /// inline form error widget.
  final String message;

  const AddLinkError(this.message);

  @override
  List<Object?> get props => [message];
}
