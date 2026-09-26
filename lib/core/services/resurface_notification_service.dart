import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../utils/navigation/route.dart';
import '../utils/utils.dart';

/// Schedules and handles the Daily Resurface local notification — the pull
/// that brings the user back to a link they saved but haven't consumed yet.
///
/// Fires once a day at a fixed local time. Tapping it opens the "Today"
/// screen, which shows one resurfaced link at a time
/// ([LinkRepository.getResurfaceCandidate]).
///
/// ## v1 scope
/// The notification body is static — it doesn't show a live unread count.
/// Doing that would require rescheduling the notification's text daily from
/// a background task (e.g. `workmanager`), which is real added complexity
/// for a personal-use v1. Worth revisiting if a live count turns out to
/// matter for the pull.
class ResurfaceNotificationService {
  static const _notificationId = 1001;
  static const _channelId = 'daily_resurface';
  static const _channelName = 'Daily Resurface';
  static const _channelDescription = 'One daily reminder to look at a saved link';
  static const _payload = 'today';
  static const _tag = 'ResurfaceNotificationService';

  /// Local time the daily notification fires at. 9:00 AM is a reasonable
  /// default for a "check in on what you saved" nudge — not first thing on
  /// waking, not buried in the evening.
  static const _hour = 9;
  static const _minute = 0;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Initializes the plugin, requests permission, and schedules the daily
  /// notification. Safe to call once at app startup; no-ops silently on any
  /// failure (a missed notification setup shouldn't block app launch).
  Future<void> initialize() async {
    try {
      tz_data.initializeTimeZones();
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone.identifier));

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false, // requested explicitly below
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      await _requestPermissions();
      await _createAndroidChannel();
      await _scheduleDaily();

      // Cold start via notification tap: the app wasn't running when tapped,
      // so no callback fired — check explicitly once the plugin is ready.
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        _navigateToToday();
      }
    } catch (e) {
      printLog(tag: _tag, msg: 'Initialization failed (non-fatal): $e');
    }
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _scheduleDaily() async {
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Links waiting',
      body: 'You saved something worth another look — tap to see one.',
      scheduledDate: _nextInstanceOfDailyTime(),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact timing avoids needing Android 12+'s SCHEDULE_EXACT_ALARM
      // permission — a rough "around 9am" is fine for a daily habit nudge,
      // no need for to-the-minute precision.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: _payload,
    );
  }

  tz.TZDateTime _nextInstanceOfDailyTime() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, _hour, _minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == _payload) _navigateToToday();
  }

  void _navigateToToday() {
    router.pushNamed(MyRouteName.today);
  }
}
