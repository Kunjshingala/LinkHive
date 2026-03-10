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
      }
    });
  }

  void _startBGListen() {
    _intentBackGroundSubscription ??= ReceiveSharingIntent.instance.getInitialMedia().asStream().listen((event) {
      final url = _extractUrl(event);
      if (url != null) {
        printLog(tag: _tag, msg: 'Cold-start shared URL: $url');
        _navigateToAddLink(url);
      }
    });
  }

  String? _extractUrl(dynamic event) {
    if (event == null) return null;
    final list = event as List<dynamic>;
    if (list.isEmpty) return null;
    final first = list.first;
    final path = first?.path as String?;
    // receive_sharing_intent passes real URL in path for URL shares
    if (path != null && (path.startsWith('http://') || path.startsWith('https://'))) {
      return path;
    }
    return null;
  }

  void _navigateToAddLink(String url) {
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
