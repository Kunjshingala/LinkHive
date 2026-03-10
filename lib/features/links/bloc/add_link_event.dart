import 'package:equatable/equatable.dart';

import '../models/link_model.dart';

/// Base sealed class for all events that can be dispatched to [AddLinkBloc].
///
/// Using a sealed class ensures exhaustive handling in the BLoC — the
/// compiler will warn you if a new event subclass is added but not handled
/// in the corresponding `on<...>` registration inside [AddLinkBloc].
sealed class AddLinkEvent extends Equatable {
  const AddLinkEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the Add/Edit Link screen is first ready.
///
/// The BLoC uses this event to decide whether to start a **fresh form**
/// or to **pre-populate an existing link for editing**.
///
/// - If [existingLink] is provided → edit mode (pre-fills all form fields).
/// - If only [prefillUrl] is provided → new-link mode with the URL already
///   set (e.g. triggered from a share intent). Metadata is auto-fetched.
/// - If neither is provided → blank new-link form.
class AddLinkInitialized extends AddLinkEvent {
  /// A URL string pre-filled into the form, typically received from the
  /// Android/iOS share sheet when the user shares a link to LinkHive.
  /// Null when the screen is opened manually without a shared URL.
  final String? prefillUrl;

  /// The full [LinkModel] to edit. When non-null, the BLoC enters edit mode
  /// and pre-populates the form with this link's current data.
  /// Null when adding a brand-new link.
  final LinkModel? existingLink;

  const AddLinkInitialized({this.prefillUrl, this.existingLink});

  @override
  List<Object?> get props => [prefillUrl, existingLink];
}

/// Triggers an async request to fetch Open Graph / HTML metadata for the
/// given [url] (title, description, preview image).
///
/// Dispatched automatically by [AddLinkBloc._onInitialized] when a
/// [prefillUrl] is present, and can also be dispatched manually by the UI
/// when the user finishes typing a URL and presses "Fetch".
///
/// While the fetch is in progress, [AddLinkForm.isFetchingMetadata] is `true`,
/// which the UI can use to show a loading indicator.
class AddLinkFetchMetadata extends AddLinkEvent {
  /// The raw URL string whose metadata should be fetched.
  final String url;

  const AddLinkFetchMetadata(this.url);

  @override
  List<Object?> get props => [url];
}

/// Notifies the BLoC that the user has changed one or more form fields.
///
/// All parameters are optional — only pass the fields that actually changed.
/// The BLoC merges the changed values into the current [AddLinkForm] state
/// using `copyWith`, leaving unchanged fields intact.
///
/// Example — user changes only the title:
/// ```dart
/// context.read<AddLinkBloc>().add(AddLinkFieldChanged(title: 'My Link'));
/// ```
class AddLinkFieldChanged extends AddLinkEvent {
  /// Updated URL, or null if the URL field was not changed.
  final String? url;

  /// Updated title, or null if the title field was not changed.
  final String? title;

  /// Updated description, or null if the description field was not changed.
  final String? description;

  /// Updated priority string ('High' | 'Normal' | 'Low'), or null if unchanged.
  final String? priority;

  /// Updated list of category IDs/names, or null if unchanged.
  final List<String>? categories;

  const AddLinkFieldChanged({this.url, this.title, this.description, this.priority, this.categories});

  @override
  List<Object?> get props => [url, title, description, priority, categories];
}

/// Signals that the user has pressed the "Save" button.
///
/// The BLoC will:
/// 1. Validate that the URL is not empty.
/// 2. Emit [AddLinkSaving] while the repository call is in flight.
/// 3. Emit [AddLinkSuccess] on success, or [AddLinkError] on failure.
///
/// Whether the BLoC calls `addLink` or `updateLink` on the repository depends
/// on whether an [existingLink] was provided during [AddLinkInitialized].
class AddLinkSaveRequested extends AddLinkEvent {
  const AddLinkSaveRequested();
}
