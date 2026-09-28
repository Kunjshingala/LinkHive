import 'dart:async';

import 'package:home_widget/home_widget.dart';

import '../../features/links/manager/link_manager.dart';
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
  HomeWidgetService({required LinkManager manager})
    : _manager = manager;

  final LinkManager _manager;
  final String _tag = 'HomeWidgetService';

  /// Fully qualified, and passed as `qualifiedAndroidName` rather than
  /// `androidName`, because the receiver lives in a sub-package.
  ///
  /// `androidName` is resolved by the plugin as
  /// `"${context.packageName}.$name"` — which would look for
  /// `com.link.hive.TodayWidgetReceiver` and throw ClassNotFoundException,
  /// failing every update silently (the error surfaces as a PlatformException
  /// that _pushData's catch used to swallow).
  static const _androidWidgetName = 'com.link.hive.widget.TodayWidgetReceiver';

  StreamSubscription<void>? _boxSubscription;
  StreamSubscription<Uri?>? _clickSubscription;

  /// Pushes initial data, starts watching the repository for changes, and
  /// wires up widget-tap deep links. Safe to call once at app startup;
  /// failures are logged and swallowed — a broken widget bridge shouldn't
  /// block the app.
  Future<void> initialize() async {
    try {
      await _pushData();

      _boxSubscription ??= _manager.watchLinks().listen(
        (_) => _pushData(),
      );

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

  /// Forces a redraw of the widget with current data.
  ///
  /// Android doesn't re-render a widget when the system theme flips, and the
  /// fallback tick is 30 minutes — so without this, switching light/dark
  /// leaves the widget showing its previously-rendered colors until
  /// something else happens to update it. [MyApp] calls this from
  /// `didChangePlatformBrightness`.
  Future<void> refresh() => _pushData();

  Future<void> _pushData() async {
    try {
      final pick = _manager.currentPick();
      await HomeWidget.saveWidgetData<bool>('has_pick', pick != null);
      await HomeWidget.saveWidgetData<String>(
        'pick_title',
        pick == null ? '' : _displayTitle(pick.title, pick.url),
      );
      await HomeWidget.saveWidgetData<String>(
        'pick_host',
        pick == null ? '' : _host(pick.url),
      );
      await HomeWidget.saveWidgetData<int>(
        'inbox_count',
        _manager.inboxCount,
      );
      await HomeWidget.saveWidgetData<int>(
        'unread_count',
        _manager.unreadCount,
      );
      await HomeWidget.updateWidget(qualifiedAndroidName: _androidWidgetName);
    } catch (e) {
      // Deliberately loud: a silent catch here hid a broken widget-class
      // lookup that made every update a no-op while the widget kept showing
      // stale data.
      printLog(
        tag: _tag,
        msg: 'WIDGET UPDATE FAILED — widget will show stale data: $e',
      );
    }
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;
    // Logged because a widget tap that quietly does nothing is
    // indistinguishable from one that opened the app on purpose — which is
    // exactly how the first version of this shipped broken.
    printLog(tag: _tag, msg: 'Widget tap: $uri');
    switch (uri.host) {
      case 'open':
        unawaited(_openPick());
      case 'today':
        router.pushNamed(MyRouteName.today);
      case 'home':
        router.goNamed(MyRouteName.homeScreen);
      default:
        printLog(tag: _tag, msg: 'Unhandled widget deep link: $uri');
    }
  }

  /// Opens the tapped pick through [LinkManager], so a widget tap behaves
  /// exactly like Open on the Today screen or a tap on a link card.
  ///
  /// The manager records the link before launching, which is what the widget
  /// needs: the app has to run for those writes to happen at all (hence no
  /// direct ACTION_VIEW from the widget), and on a cold start the browser
  /// backgrounds the activity before the launch's continuation is guaranteed
  /// to run.
  ///
  /// Resolves the pick here rather than trusting an id passed in from the
  /// widget — see the comment in TodayGlanceWidget for why.
  ///
  /// No navigation afterwards — the in-app browser opens over whatever screen
  /// the app landed on, and closing it leaves the user in LinkHive. The box
  /// write triggers [_pushData] through the watch, so the widget has already
  /// moved to the next pick by the time they get back.
  Future<void> _openPick() async {
    final link = _manager.currentPick();
    if (link == null) {
      // The widget drew a pick but there's nothing to resurface now — it was
      // read, archived or deleted since the last draw. Show the user
      // something rather than appearing to do nothing, and re-sync the widget.
      printLog(
        tag: _tag,
        msg: 'Widget tap had no candidate — widget was stale',
      );
      router.goNamed(MyRouteName.homeScreen);
      unawaited(_pushData());
      return;
    }
    await _manager.openLink(link);
  }

  String _displayTitle(String title, String url) =>
      title.isNotEmpty ? title : url;

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
