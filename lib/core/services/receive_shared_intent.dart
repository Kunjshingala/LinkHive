import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uuid/uuid.dart';

import '../../features/links/models/link_model.dart';
import '../../features/links/repository/link_repository.dart';
import '../../sharedWidgets/saved_link_snackbar.dart';
import '../utils/navigation/route.dart';
import '../utils/utils.dart';
import '../utils/validator/validator.dart';
import 'link_metadata_service.dart';

/// Listens for URLs shared into the app from the OS share sheet and saves them
/// with zero friction.
///
/// ## Capture flow (Phase 1)
/// A shared URL is persisted **immediately** with no form and no required
/// input. The user then sees a lightweight "Saved to LinkHive" confirmation
/// with two optional actions:
/// - **Add details** — opens the edit form on the just-saved link.
/// - **Undo** — deletes it.
///
/// Page metadata (title, image, description) is fetched in the background
/// *after* the save, so nothing blocks the capture. This is what lets sharing
/// to LinkHive compete with a native "save" button.
class ReceiveSharedIntent {
  ReceiveSharedIntent({
    required LinkRepository repository,
    required LinkMetadataService metadataService,
  }) : _repository = repository,
       _metadataService = metadataService;

  final LinkRepository _repository;
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
        (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      printLog(tag: _tag, msg: 'Share intent unsupported on this platform — skipping');
      return;
    }
    _startListen();
    _startBGListen();
  }

  void _startListen() {
    _intentSubscription ??= ReceiveSharingIntent.instance.getMediaStream().listen((event) {
      final url = _extractUrl(event);
      if (url != null) {
        printLog(tag: _tag, msg: 'Foreground shared URL: $url');
        _saveInstantly(url);
      } else if (_hasContent(event)) {
        printLog(tag: _tag, msg: 'Non-URL share ignored');
        showSnackBar('Only URL links can be saved to LinkHive');
      }
    });
  }

  void _startBGListen() {
    _intentBackGroundSubscription ??= ReceiveSharingIntent.instance.getInitialMedia().asStream().listen((event) {
      final url = _extractUrl(event);
      if (url != null) {
        printLog(tag: _tag, msg: 'Cold-start shared URL: $url');
        _saveInstantly(url, resetToHome: true);
      } else if (_hasContent(event)) {
        printLog(tag: _tag, msg: 'Non-URL cold-start share ignored');
        showSnackBar('Only URL links can be saved to LinkHive');
      }
    });
  }

  /// Persists [url] immediately, shows the confirmation bar, and kicks off a
  /// background metadata fetch. Never opens the full form.
  ///
  /// [resetToHome] is set for cold-start shares: the app is still on the splash
  /// screen, so "Add details" first drops Home at the base of the stack (so
  /// closing the edit form returns to Home, not the splash).
  Future<void> _saveInstantly(String url, {bool resetToHome = false}) async {
    final normalizedUrl = normalizeUrl(url) ?? url;
    final link = LinkModel(
      id: _uuid.v4(),
      url: normalizedUrl,
      title: '',
      createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      // Lands in the Inbox until the user adds details (see AddLinkBloc).
      isQuickSaved: true,
    );

    try {
      await _repository.addLink(link);
    } catch (e) {
      // Rare: a Hive write failure. Log it and bail rather than showing a
      // "saved" confirmation for something that didn't save.
      printLog(tag: _tag, msg: 'Instant save failed: $e');
      return;
    }

    printLog(tag: _tag, msg: 'Instant-saved link: ${link.url}');
    showSavedLinkSnackBar(
      onAddDetails: () {
        if (resetToHome) router.goNamed(MyRouteName.homeScreen);
        // Re-read from the repository rather than reusing the closure-captured
        // `link`: background enrichment may have already filled in the title
        // by the time this is tapped, and passing the stale (blank) snapshot
        // would show an empty form even though good data is already saved.
        router.pushNamed(MyRouteName.editLink, extra: _repository.getLinkById(link.id) ?? link);
      },
      onUndo: () => _repository.deleteLink(link.id),
    );

    unawaited(_enrichInBackground(link));
  }

  /// Fetches page metadata after the save and fills any fields still empty.
  ///
  /// Only empty fields are written, so this never clobbers a title/description
  /// the user typed via "Add details", nor a link they undid (which is gone
  /// from the box and skipped here).
  Future<void> _enrichInBackground(LinkModel saved) async {
    try {
      final metadata = await _metadataService.fetchMetadata(saved.url);
      final current = _repository.getLinkById(saved.id);
      if (current == null) return; // undone or deleted meanwhile

      final needsTitle = current.title.isEmpty && metadata.title.isNotEmpty;
      final needsImage = current.image.isEmpty && metadata.image.isNotEmpty;
      final needsDesc = current.description.isEmpty && metadata.description.isNotEmpty;
      if (!needsTitle && !needsImage && !needsDesc) return;

      await _repository.updateLink(
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

  String? _extractUrl(dynamic event) {
    if (event == null) return null;
    final list = event as List<dynamic>;
    if (list.isEmpty) return null;
    final first = list.first;
    final path = first?.path as String?;
    // receive_sharing_intent passes the real URL in path for URL shares
    if (path != null && (path.startsWith('http://') || path.startsWith('https://'))) {
      return path;
    }
    return null;
  }

  bool _hasContent(dynamic event) {
    if (event == null) return false;
    final list = event as List<dynamic>;
    return list.isNotEmpty && list.first?.path != null;
  }

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
