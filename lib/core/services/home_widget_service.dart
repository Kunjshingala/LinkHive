import 'dart:async';

import 'package:home_widget/home_widget.dart';

import '../../features/links/repository/link_repository.dart';
import '../utils/navigation/route.dart';
import '../utils/utils.dart';

/// Bridges live app data to the Android home-screen widget (Today's
/// resurface pick + Inbox/unread counts) and handles taps on it.
///
/// ## v1 scope
/// Android only — see `docs/setup/home_widget_setup.md` for the iOS
/// WidgetKit side, which needs a Widget Extension target created in Xcode
/// (a manual step, same category as the ShareExtension) before any of the
/// Swift code there can run.
///
/// No live preview image for the pick in v1 — matches [LinkCard]'s own
/// fallback: a plain title/host, no network fetch from the widget's data
/// pipeline. A real thumbnail is a deliberate v2 addition (would need
/// downloading + caching the image file for the native widget to read,
/// real but non-trivial extra work for what's a cosmetic improvement).
class HomeWidgetService {
  HomeWidgetService({required LinkRepository repository}) : _repository = repository;

  final LinkRepository _repository;
  final String _tag = 'HomeWidgetService';

  static const _androidWidgetName = 'TodayWidgetReceiver';

  StreamSubscription<void>? _boxSubscription;
  StreamSubscription<Uri?>? _clickSubscription;

  /// Pushes initial data, starts watching the repository for changes, and
  /// wires up widget-tap deep links. Safe to call once at app startup;
  /// failures are logged and swallowed — a broken widget bridge shouldn't
  /// block the app.
  Future<void> initialize() async {
    try {
      await _pushData();

      _boxSubscription ??= _repository.watchLinksBox().listen((_) => _pushData());

      // Cold start via a widget tap: the app wasn't running, so no stream
      // event fires for it — check explicitly once, same pattern as
      // ResurfaceNotificationService's getNotificationAppLaunchDetails.
      final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _handleUri(launchUri);

      _clickSubscription ??= HomeWidget.widgetClicked.listen(_handleUri);
    } catch (e) {
      printLog(tag: _tag, msg: 'Initialization failed (non-fatal): $e');
    }
  }

  Future<void> _pushData() async {
    try {
      final pick = _repository.getResurfaceCandidate();
      await HomeWidget.saveWidgetData<bool>('has_pick', pick != null);
      await HomeWidget.saveWidgetData<String>('pick_title', pick == null ? '' : _displayTitle(pick.title, pick.url));
      await HomeWidget.saveWidgetData<String>('pick_host', pick == null ? '' : _host(pick.url));
      await HomeWidget.saveWidgetData<int>('inbox_count', _repository.quickCount);
      await HomeWidget.saveWidgetData<int>('unread_count', _repository.unreadCount);
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      printLog(tag: _tag, msg: 'Failed to push widget data: $e');
    }
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;
    switch (uri.host) {
      case 'today':
        router.pushNamed(MyRouteName.today);
      case 'home':
        router.goNamed(MyRouteName.homeScreen);
    }
  }

  String _displayTitle(String title, String url) => title.isNotEmpty ? title : url;

  String _host(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  void dispose() {
    _boxSubscription?.cancel();
    _clickSubscription?.cancel();
  }
}
