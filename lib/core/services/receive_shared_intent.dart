import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../utils/navigation/route.dart';
import '../utils/utils.dart';

class ReceiveSharedIntent {
  final String _tag = 'ReceiveSharedIntent';

  StreamSubscription<dynamic>? _intentSubscription;
  StreamSubscription<dynamic>? _intentBackGroundSubscription;

  void initialize() {
    _startListen();
    _startBGListen();
  }

  void _startListen() {
    _intentSubscription ??= ReceiveSharingIntent.instance.getMediaStream().listen((event) {
      final url = _extractUrl(event);
      if (url != null) {
        printLog(tag: _tag, msg: 'Foreground shared URL: $url');
        _navigateToAddLink(url);
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
        _navigateToAddLink(url, resetToHome: true);
      } else if (_hasContent(event)) {
        printLog(tag: _tag, msg: 'Non-URL cold-start share ignored');
        showSnackBar('Only URL links can be saved to LinkHive');
      }
    });
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

  void _navigateToAddLink(String url, {bool resetToHome = false}) {
    // On a cold-start share the app is still on the splash screen. Put Home at
    // the base of the stack first, so the splash's timer can't replace the
    // AddLink screen (see SplashBloc) and closing AddLink returns to Home
    // rather than the splash. Foreground shares (app already on Home) just push.
    if (resetToHome) {
      router.goNamed(MyRouteName.homeScreen);
    }
    router.pushNamed(MyRouteName.addLink, extra: url);
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
