import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// Regression coverage for the in-app browser switch.
///
/// `LaunchMode.inAppBrowserView` throws `ArgumentError` for any non-http(s)
/// URL (url_launcher_uri.dart:47-51). Non-http links reach the links box
/// because `normalizeUrl` returns null for them and the callers fall back to
/// the raw string, so opening one used to fail with "Could not open" — and in
/// the widget path it was marked read and resurfaced first, consuming the link
/// without ever showing it.
void main() {
  group('launchModeForUrl', () {
    test('uses the in-app browser for https', () {
      expect(
        launchModeForUrl(Uri.parse('https://wellfound.com/jobs')),
        LaunchMode.inAppBrowserView,
      );
    });

    test('uses the in-app browser for http', () {
      expect(
        launchModeForUrl(Uri.parse('http://example.com')),
        LaunchMode.inAppBrowserView,
      );
    });

    test('falls back to the external app for mailto', () {
      expect(
        launchModeForUrl(Uri.parse('mailto:someone@example.com')),
        LaunchMode.externalApplication,
      );
    });

    test('falls back to the external app for tel', () {
      expect(
        launchModeForUrl(Uri.parse('tel:+15551234567')),
        LaunchMode.externalApplication,
      );
    });

    test('falls back to the external app for a custom scheme', () {
      expect(
        launchModeForUrl(Uri.parse('linkhive://today')),
        LaunchMode.externalApplication,
      );
    });

    test('falls back to the external app for a scheme-less url', () {
      // Uri.parse('example.com') yields an empty scheme, not https.
      expect(
        launchModeForUrl(Uri.parse('example.com')),
        LaunchMode.externalApplication,
      );
    });
  });
}
