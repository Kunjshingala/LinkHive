import 'package:hive_flutter/hive_flutter.dart';
import 'package:synchronized/synchronized.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/extensions/context_extension.dart';
import '../../../core/utils/url_canonical.dart';
import '../../../core/utils/utils.dart';
import '../../../my_app.dart';
import '../models/category_model.dart';
import '../models/link_model.dart';
import '../repository/link_repository.dart';
import 'save_result.dart';

export 'save_result.dart';

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
  LinkManager({
    required LinkRepository repository,
    DateTime Function() clock = DateTime.now,
  }) : _repository = repository,
       _clock = clock;

  final LinkRepository _repository;
  final DateTime Function() _clock;
  static const _tag = 'LinkManager';

  /// How many alternate URLs a link keeps in [LinkModel.otherUrls].
  static const maxOtherUrls = 5;

  /// Serializes [saveOrMerge], [undoMerge] and [keepOnlyVersion]. Each is a
  /// read-then-write: without the lock, two quick shares of the same URL could
  /// both miss the match and create two records, or both read the same
  /// previous state and lose a count. The lock hands each caller its own
  /// result or error and stays usable after a failure.
  final _saveLock = Lock();

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

  // ─── Links ──────────────────────────────────────────────────────────────
  //
  // Straight delegation to [LinkRepository]. These carry no logic of their
  // own: they exist so a feature bloc has exactly one dependency and one
  // place to look, rather than reaching past the manager to the store.
  //
  // The sync layer (SyncEngine, SyncService, ConflictBloc) and AccountBloc
  // deliberately do NOT come through here. They are the persistence and sync
  // machinery itself, not user actions on a link, and forwarding
  // pullFromCloud or conflict resolution through an action manager would add
  // a hop without removing a decision.

  Future<void> addLink(LinkModel link) => _repository.addLink(link);

  Future<void> updateLink(LinkModel link) => _repository.updateLink(link);

  Future<void> deleteLink(String id) => _repository.deleteLink(id);

  LinkModel? linkById(String id) => _repository.getLinkById(id);

  List<LinkModel> queryLinks({
    String query = '',
    String category = 'All',
    String priority = 'All',
    int limit = 20,
    int offset = 0,
  }) => _repository.queryLinks(
    query: query,
    category: category,
    priority: priority,
    limit: limit,
    offset: offset,
  );

  /// Quick-saved links, the Inbox contents.
  List<LinkModel> queryQuickLinks() => _repository.queryQuickLinks();

  /// Oldest unread links for the Home "Up Next" strip.
  List<LinkModel> getUpNextLinks({int count = 3}) =>
      _repository.getUpNextLinks(count: count);

  Future<void> markAsRead(String id) => _repository.markLinkAsRead(id);

  Future<void> markAsUnread(String id) => _repository.markLinkAsUnread(id);

  // ─── Categories ─────────────────────────────────────────────────────────

  List<CategoryModel> getCategories() => _repository.getCategories();

  Future<void> addCategory(CategoryModel category) =>
      _repository.addCategory(category);

  Future<void> deleteCategory(String id) => _repository.deleteCategory(id);

  // ─── Sync triggers ──────────────────────────────────────────────────────
  //
  // The user-initiated ones only (pull to refresh). The scheduled and
  // connectivity-driven paths live in SyncService and talk to the repository
  // directly.

  Future<void> syncPendingLinks() => _repository.syncPendingLinks();

  Future<void> pullFromCloud() => _repository.pullFromCloud();

  /// Opens [link] and records it as consumed.
  ///
  /// Marks the link read and resurfaced *before* launching, so a backgrounded
  /// or reclaimed process cannot lose the write. A failed launch still leaves
  /// the link recorded, matching what TodayBloc always did (it marked read
  /// even when the launch threw).
  ///
  /// [url] opens one of the link's other versions ([LinkModel.otherUrls])
  /// picked in the version picker; it defaults to [LinkModel.url].
  Future<void> openLink(LinkModel link, {String? url}) async {
    final target = url ?? link.url;
    final uri = Uri.tryParse(target);
    if (uri == null) {
      printLog(tag: _tag, msg: 'Unparseable url: $target');
      showSnackBar(_couldNotOpen(target));
      return;
    }
    await _recordConsumed(link.id);
    await _launch(uri, target);
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

  /// Saves [candidate], or merges it into the link it duplicates.
  ///
  /// Duplicates are found by [LinkRepository.findByCanonicalUrl], so the same
  /// reel or video shared with different tracking params is one link.
  ///
  /// **Created:** [candidate] is stored with `shareCount = 1` and
  /// `lastSharedAt = createdAt`.
  ///
  /// **Merged:** the existing record keeps every field it had, including its
  /// URL, title and priority, and:
  /// - comes back unread (re-sharing an archived link means "I want this
  ///   again") and becomes due in Today;
  /// - counts the share (`shareCount + 1`, `lastSharedAt = now`);
  /// - unions in the candidate's categories;
  /// - keeps the candidate's URL in [LinkModel.otherUrls] if it isn't one it
  ///   already has (newest last, at most [maxOtherUrls]), so an affiliate
  ///   variant isn't lost.
  ///
  /// The schedule follows the "When should this come back?" convention used
  /// by `LinkModel.copyWith` and the Add form: [resurfaceAt] for Tonight /
  /// Weekend, [clearResurfaceAt] for Someday, neither for "no pick". No pick
  /// on a merge means due now. It applies to the new record on create too.
  Future<SaveResult> saveOrMerge(
    LinkModel candidate, {
    int? resurfaceAt,
    bool clearResurfaceAt = false,
  }) {
    return _saveLock.synchronized(() async {
      final existing = _repository.findByCanonicalUrl(candidate.url);
      if (existing == null) {
        final created = candidate.copyWith(
          shareCount: 1,
          lastSharedAt: candidate.createdAt,
          resurfaceAt: resurfaceAt,
          clearResurfaceAt: clearResurfaceAt,
        );
        await _repository.addLink(created);
        return SaveCreated(created);
      }

      final now = _clock().toUtc().millisecondsSinceEpoch;
      // A version is a URL that differs beyond per-share tokens: a fresh
      // igsh/si on every share must not fill the picker.
      final candidateKey = versionKey(candidate.url);
      final addedVersion =
          candidateKey != versionKey(existing.url) &&
          !existing.otherUrls.any((url) => versionKey(url) == candidateKey);
      final otherUrls = addedVersion
          ? _keepNewest([...existing.otherUrls, candidate.url])
          : existing.otherUrls;

      final merged = existing.copyWith(
        isRead: false,
        resurfaceAt: clearResurfaceAt ? null : (resurfaceAt ?? now),
        clearResurfaceAt: clearResurfaceAt,
        shareCount: existing.shareCount + 1,
        lastSharedAt: now,
        categories: {...existing.categories, ...candidate.categories}.toList(),
        otherUrls: otherUrls,
      );
      await _repository.updateLink(merged);
      return SaveMerged(
        merged: merged,
        previous: existing,
        addedVersion: addedVersion,
      );
    });
  }

  /// Reverts a merge done by [saveOrMerge].
  ///
  /// Only the fields the merge wrote are put back, onto the **current**
  /// record: metadata that arrived after the merge (a fetched title or image)
  /// is kept. Nulls are restored through the `clear*` flags, since `copyWith`
  /// can't write null otherwise; without that, an Undo would leave the link
  /// due. Does nothing if the link was deleted meanwhile.
  Future<void> undoMerge(LinkModel previous) {
    return _saveLock.synchronized(() async {
      final current = _repository.getLinkById(previous.id);
      if (current == null) return;
      await _repository.updateLink(
        current.copyWith(
          isRead: previous.isRead,
          resurfaceAt: previous.resurfaceAt,
          clearResurfaceAt: previous.resurfaceAt == null,
          shareCount: previous.shareCount,
          lastSharedAt: previous.lastSharedAt,
          clearLastSharedAt: previous.lastSharedAt == null,
          categories: previous.categories,
          otherUrls: previous.otherUrls,
        ),
      );
    });
  }

  /// Makes [url] the link's only URL, dropping the other versions.
  ///
  /// Backs "Keep only this one" in the version picker. Every version shares
  /// the same canonical key, so duplicate matching is unaffected.
  Future<void> keepOnlyVersion(LinkModel link, String url) {
    return _saveLock.synchronized(() async {
      final current = _repository.getLinkById(link.id) ?? link;
      await _repository.updateLink(
        current.copyWith(url: url, otherUrls: const []),
      );
    });
  }

  List<String> _keepNewest(List<String> urls) => urls.length <= maxOtherUrls
      ? urls
      : urls.sublist(urls.length - maxOtherUrls);

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
