import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration loaded from `--dart-define-from-file=firebase_config.json`.
///
/// Usage:
///   fvm flutter run --dart-define-from-file=firebase_config.json
abstract class FirebaseConfig {
  // ─── Shared ────────────────────────────────────────────────────────
  static const projectId = String.fromEnvironment('FB_PROJECT_ID');
  static const messagingSenderId = String.fromEnvironment('FB_MESSAGING_SENDER_ID');
  static const storageBucket = String.fromEnvironment('FB_STORAGE_BUCKET');

  // ─── Android ───────────────────────────────────────────────────────
  static const androidApiKey = String.fromEnvironment('FB_API_KEY_ANDROID');
  static const androidAppId = String.fromEnvironment('FB_APP_ID_ANDROID');
  static const androidClientId = String.fromEnvironment('FB_ANDROID_CLIENT_ID');

  // ─── iOS ───────────────────────────────────────────────────────────
  static const iosApiKey = String.fromEnvironment('FB_API_KEY_IOS');
  static const iosAppId = String.fromEnvironment('FB_APP_ID_IOS');
  static const iosBundleId = String.fromEnvironment('FB_IOS_BUNDLE_ID');
  static const iosClientId = String.fromEnvironment('FB_IOS_CLIENT_ID');

  // ─── Platform options ──────────────────────────────────────────────
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('FirebaseConfig: unsupported platform $defaultTargetPlatform');
    }
  }

  static const android = FirebaseOptions(
    apiKey: androidApiKey,
    appId: androidAppId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket,
  );

  static const ios = FirebaseOptions(
    apiKey: iosApiKey,
    appId: iosAppId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket,
    iosBundleId: iosBundleId,
  );
}
