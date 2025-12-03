import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ReceiveSharedIntent {
  ReceiveSharedIntent._();

  factory ReceiveSharedIntent() => _instance;
  static final ReceiveSharedIntent _instance = ReceiveSharedIntent._();

  StreamSubscription<dynamic>? intentSubscription;
  StreamSubscription<dynamic>? intentBackGroundSubscription;

  void initialize() {
    startListen();
    startBGListen();
  }

  void startListen() {
    intentSubscription ??= ReceiveSharingIntent.instance.getMediaStream().listen((event) {
      debugPrint("----------> getMediaStream onEvent type ${event.firstOrNull?.type}");
    });
  }

  void startBGListen() {
    intentBackGroundSubscription ??= ReceiveSharingIntent.instance.getInitialMedia().asStream().listen((event) {
      debugPrint("----------> getMediaStream getInitialMedia type ${event.firstOrNull?.type}");
    });
  }

  void stopListen() {
    intentSubscription?.cancel();
    intentSubscription = null;
  }

  void dispose() {
    stopListen();
  }
}
