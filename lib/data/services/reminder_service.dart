import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Daily study reminder notifications.
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  static const _reminderId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );
    _initialized = true;
  }

  @pragma('vm:entry-point')
  static void _onBackgroundResponse(NotificationResponse response) {}

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> scheduleDaily(int hour, int minute) async {
    await init();
    await _plugin.zonedSchedule(
      id: _reminderId,
      title: 'Study time!',
      body: 'Open StudyBuddy and review your flashcards and quiz.',
      scheduledDate: _nextInstance(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_reminders',
          'Study reminders',
          channelDescription: 'Daily reminder to study',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel() async {
    await _plugin.cancel(id: _reminderId);
  }

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day,
        hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}