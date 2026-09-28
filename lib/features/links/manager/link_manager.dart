import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/extensions/context_extension.dart';
import '../../../core/utils/utils.dart';
import '../../../my_app.dart';
import '../models/link_model.dart';
import '../repository/link_repository.dart';

/// The single place that decides what happens to a link.
///
/// ## Why this exists
/// "Open a link" was implemented four times — TodayBloc, HomeWidgetService,
/// home.dart's Up Next strip, and LinkCard — and all four disagreed:
///
/// | Site        | Order              | Writes                  |
/// |-------------|--------------------|-------------------------|
/// | TodayBloc   | launch, then write | read + resurfaced       |
/// | widget      | write, then launch | read + resurfaced       |
/// | Up Next     | launch, then write | read only, via an event |
/// | LinkCard    | launch only        | **none**                |
///
/// That disagreement was not theoretical. LinkCard is the row on Home and in
/// the Inbox, so the most common way to open a link never marked it read and
/// it resurfaced forever. A separate ordering bug lost the write entirely on
/// a cold start from the widget.
///
/// [LinkRepository] stays the single source for *persistence*. This is the
/// single source for *actions*: the composites that combine a launch, the
/// two bookkeeping writes, and the user-facing failure message.
///
/// ## Ordering: record first, launch second
/// Opening the browser backgrounds the activity almost immediately. On a cold
/// start the engine is still warming up, and the continuation after
/// `await launchUrl` is not guaranteed to run before the process is suspended.
/// Writing first makes the durable part safe and leaves the launch
/// effectively fire-and-forget. Every path uses this order now, so there is
/// one answer rather than four.
class LinkManager {
  LinkManager({required LinkRepository repository}) : _repository = repository;

  final LinkRepository _repository;
  static const _tag = 'LinkManager';

  /// The link the Daily Resurface engine wants to show next, or null when
  /// everything saved has been read.
  LinkModel? currentPick() => _repository.getResurfaceCandidate();

  /// Fires whenever any link changes, so surfaces outside the widget tree
  /// (the home-screen widget) can refresh themselves.
  Stream<BoxEvent> watchLinks() => _repository.watchLinksBox();

  /// Quick-saved links awaiting triage.
  int get inboxCount => _repository.quickCount;

  /// Unread links in the managed reading queue, excluding the Inbox.
  int get unreadCount => _repository.unreadCount;

  /// Opens [link] and records it as consumed.
  ///
  /// Marks the link read and resurfaced *before* launching, so a backgrounded
  /// or reclaimed process cannot lose the write. A failed launch still leaves
  /// the link recorded, matching what TodayBloc always did (it marked read
  /// even when the launch threw).
  Future<void> openLink(LinkModel link) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null) {
      printLog(tag: _tag, msg: 'Unparseable url: ${link.url}');
      showSnackBar(_couldNotOpen(link.url));
      return;
    }
    await _recordConsumed(link.id);
    await _launch(uri, link.url);
  }

  /// Marks [link] consumed without opening it: already handled elsewhere, or
  /// decided it isn't worth revisiting.
  Future<void> archiveLink(LinkModel link) => _recordConsumed(link.id);

  /// Records that [link] was shown but leaves it unread, so the spaced pool
  /// moves on and offers it again later rather than immediately.
  Future<void> snoozeLink(LinkModel link) async {
    try {
      await _repository.markResurfaced(link.id);
    } catch (e) {
      printLog(tag: _tag, msg: 'Failed to snooze ${link.id}: $e');
    }
  }

  /// Read + resurfaced, the pair that takes a link out of the resurface pool.
  ///
  /// [LinkRepository.getResurfaceCandidate] filters on `!isRead`, so without
  /// [LinkRepository.markLinkAsRead] a link comes back forever. Errors are
  /// logged rather than thrown: callers are fire-and-forget (the widget path
  /// runs unawaited), so an exception here would vanish silently and look
  /// exactly like a tap that did nothing.
  Future<void> _recordConsumed(String id) async {
    try {
      await _repository.markLinkAsRead(id);
      await _repository.markResurfaced(id);
    } catch (e) {
      printLog(tag: _tag, msg: 'Failed to record $id as consumed: $e');
    }
  }

  Future<void> _launch(Uri uri, String url) async {
    try {
      final launched = await launchUrl(uri, mode: launchModeForUrl(uri));
      if (!launched) showSnackBar(_couldNotOpen(url));
    } catch (e) {
      printLog(tag: _tag, msg: 'Failed to launch $url: $e');
      showSnackBar(_couldNotOpen(url));
    }
  }

  /// Localized failure text.
  ///
  /// Three of the four old call sites hardcoded English, which the project's
  /// own workflow rules forbid. A service has no BuildContext, so this borrows
  /// the one behind the global messenger key — the same key [showSnackBar]
  /// already uses. Falls back to English only if no context is mounted, which
  /// in practice means no UI is up to show a snackbar anyway.
  String _couldNotOpen(String url) {
    final context = scaffoldMessengerKey.currentContext;
    if (context == null) return 'Could not open $url';
    return context.l10n.linkOpenFailed(url);
  }
}
