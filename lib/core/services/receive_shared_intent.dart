import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uuid/uuid.dart';

import '../../features/links/models/link_model.dart';
import '../../features/links/manager/link_manager.dart';
import '../../l10n/localization/app_localizations.dart';
import '../../my_app.dart';
import '../../sharedWidgets/saved_link_snackbar.dart';
import '../extensions/context_extension.dart';
import '../utils/navigation/route.dart';
import '../utils/utils.dart';
import '../utils/validator/validator.dart';
import 'link_metadata_service.dart';
import 'share_event.dart';
import 'share_feedback.dart';

/// Listens for URLs shared into the app from the OS share sheet and saves them
/// with zero friction.
///
/// ## Capture flow (Phase 1)
/// A shared URL is persisted **immediately** with no form and no required
/// input, exactly as shared (affiliate params survive). If the same link was
/// already saved, the share merges into it instead (see
/// [LinkManager.saveOrMerge]). The user then sees a lightweight confirmation
/// with two optional actions:
/// - **Add details** — opens the edit form on the saved link.
/// - **Undo** — deletes a new link, or reverts a merge (never deleting the
///   original).
///
/// Page metadata (title, image, description) is fetched in the background
/// *after* the save, so nothing blocks the capture. This is what lets sharing
/// to LinkHive compete with a native "save" button.
class ReceiveSharedIntent {
  ReceiveSharedIntent({
    required LinkManager manager,
    required LinkMetadataService metadataService,
  }) : _manager = manager,
       _metadataService = metadataService;

  final LinkManager _manager;
  final LinkMetadataService _metadataService;

  final String _tag = 'ReceiveSharedIntent';
  static const _uuid = Uuid();

  StreamSubscription<dynamic>? _intentSubscription;
  StreamSubscription<dynamic>? _intentBackGroundSubscription;

  void initialize() {
    // receive_sharing_intent only ships Android and iOS implementations (see
    // its pubspec's plugin.platforms). Calling getMediaStream()/getInitialMedia()
    // on web/Windows/macOS/Linux has no platform-channel backing and throws.
    // Desktop/web are out of scope for now (see CLAUDE.md); guard so a build
    // for those platforms doesn't crash on startup instead of silently no-op.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      printLog(
        tag: _tag,
        msg: 'Share intent unsupported on this platform — skipping',
      );
      return;
    }
    _startListen();
    _startBGListen();
  }

  void _startListen() {
    _intentSubscription ??= ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((event) {
          final url = _extractUrl(event);
          if (url != null) {
            printLog(tag: _tag, msg: 'Foreground shared URL: $url');
            _saveInstantly(url);
          } else if (_hasContent(event)) {
            printLog(tag: _tag, msg: 'Non-URL share ignored');
            _showLocalizedSnackBar((l10n) => l10n.sharedOnlyUrls);
          }
        });
  }

  void _startBGListen() {
    _intentBackGroundSubscription ??= ReceiveSharingIntent.instance
        .getInitialMedia()
        .asStream()
        .listen((event) {
          // The plugin hands the launch intent out again on every call until
          // it is reset (Android replays it when the task is restored), which
          // would count as another re-share of the same link.
          ReceiveSharingIntent.instance.reset();
          final url = _extractUrl(event);
          if (url != null) {
            printLog(tag: _tag, msg: 'Cold-start shared URL: $url');
            _saveInstantly(url, resetToHome: true);
          } else if (_hasContent(event)) {
            printLog(tag: _tag, msg: 'Non-URL cold-start share ignored');
            _showLocalizedSnackBar((l10n) => l10n.sharedOnlyUrls);
          }
        });
  }

  /// Saves [url] immediately (or merges it into the link it duplicates),
  /// shows the confirmation bar, and kicks off a background metadata fetch.
  /// Never opens the full form.
  ///
  /// [resetToHome] is set for cold-start shares: the app is still on the splash
  /// screen, so "Add details" first drops Home at the base of the stack (so
  /// closing the edit form returns to Home, not the splash).
  Future<void> _saveInstantly(String url, {bool resetToHome = false}) async {
    final normalizedUrl = normalizeUrl(url) ?? url;
    final candidate = LinkModel(
      id: _uuid.v4(),
      url: normalizedUrl,
      title: '',
      createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      // Lands in the Inbox until the user adds details (see AddLinkBloc).
      isQuickSaved: true,
    );

    final SaveResult result;
    try {
      result = await _manager.saveOrMerge(candidate);
    } catch (e) {
      // Rare: a Hive write failure. Don't show "saved" for something that
      // didn't save; tell the user to share again instead.
      printLog(tag: _tag, msg: 'Instant save failed: $e');
      _showLocalizedSnackBar(
        (l10n) =>
            shareOutcomeMessage(error: e, l10n: l10n, now: DateTime.now()),
      );
      return;
    }

    final saved = switch (result) {
      SaveCreated(:final link) => link,
      SaveMerged(:final merged) => merged,
    };
    printLog(
      tag: _tag,
      msg: 'Instant-saved (${result.runtimeType}): ${saved.url}',
    );

    showSavedLinkSnackBar(
      message: result is SaveMerged
          ? (context) => shareOutcomeMessage(
              result: result,
              l10n: context.l10n,
              now: DateTime.now(),
            )
          : null,
      onAddDetails: () {
        if (resetToHome) router.goNamed(MyRouteName.homeScreen);
        // Re-read from the repository rather than reusing the closure-captured
        // link: background enrichment may have already filled in the title
        // by the time this is tapped, and passing the stale (blank) snapshot
        // would show an empty form even though good data is already saved.
        router.pushNamed(
          MyRouteName.editLink,
          extra: _manager.linkById(saved.id) ?? saved,
        );
      },
      onUndo: () => switch (result) {
        SaveCreated() => _manager.deleteLink(saved.id),
        SaveMerged(:final previous) => _manager.undoMerge(previous),
      },
    );

    // A merge keeps the existing title; only fetch if it never got one.
    if (saved.title.isEmpty) unawaited(_enrichInBackground(saved));
  }

  /// Shows a plain localized snackbar, waiting for the first frame when the
  /// messenger isn't mounted yet (a cold-start share arrives before it is).
  void _showLocalizedSnackBar(
    String Function(AppLocalizations l10n) message, {
    bool retryAfterFirstFrame = true,
  }) {
    final context = scaffoldMessengerKey.currentContext;
    if (context == null) {
      if (retryAfterFirstFrame) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showLocalizedSnackBar(message, retryAfterFirstFrame: false),
        );
      }
      return;
    }
    showSnackBar(message(context.l10n));
  }

  /// Fetches page metadata after the save and fills any fields still empty.
  ///
  /// Only empty fields are written, so this never clobbers a title/description
  /// the user typed via "Add details", nor a link they undid (which is gone
  /// from the box and skipped here).
  Future<void> _enrichInBackground(LinkModel saved) async {
    try {
      final metadata = await _metadataService.fetchMetadata(saved.url);
      final current = _manager.linkById(saved.id);
      if (current == null) return; // undone or deleted meanwhile

      final needsTitle = current.title.isEmpty && metadata.title.isNotEmpty;
      final needsImage = current.image.isEmpty && metadata.image.isNotEmpty;
      final needsDesc =
          current.description.isEmpty && metadata.description.isNotEmpty;
      if (!needsTitle && !needsImage && !needsDesc) return;

      await _manager.updateLink(
        current.copyWith(
          title: needsTitle ? metadata.title : current.title,
          image: needsImage ? metadata.image : current.image,
          description: needsDesc ? metadata.description : current.description,
        ),
      );
      printLog(tag: _tag, msg: 'Enriched metadata for ${saved.url}');
    } catch (e) {
      printLog(tag: _tag, msg: 'Metadata enrich failed: $e');
    }
  }

  String? _extractUrl(dynamic event) => shareEventUrl(event);

  bool _hasContent(dynamic event) => shareEventHasContent(event);

  void _stopListen() {
    _intentSubscription?.cancel();
    _intentSubscription = null;
    _intentBackGroundSubscription?.cancel();
    _intentBackGroundSubscription = null;
  }

  void dispose() {
    _stopListen();
  }
}
