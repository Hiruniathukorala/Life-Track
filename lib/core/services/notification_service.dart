import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages all local notifications for LifeTrack.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  // ── Channel IDs ───────────────────────────────────────────────────────────
  // "v3": Android permanently locks channel settings (sound, importance) after
  // first creation.  Bumping the suffix forces a fresh channel with correct
  // audio routing.  Previous channels (v1, v2) used the ALARM volume stream
  // which is often 0 on Samsung — v3 uses the RINGTONE stream instead.
  static const _habitChannelId    = 'habit_alarms_v3';
  static const _habitChannelName  = 'Habit Alarms';
  static const _periodChannelId   = 'period_reminders';
  static const _periodChannelName = 'Period Reminders';

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      // ── Habit alarm channel ────────────────────────────────────────────────
      // audioAttributesUsage: notificationRingtone
      //   → routes through the RINGER volume (same as incoming calls).
      //   This is guaranteed to be audible because users always keep their
      //   ringer volume up.  The old v2 channel used AudioAttributesUsage.alarm
      //   which routes through the ALARM volume stream — on Samsung this is a
      //   separate slider that defaults to 0, causing silent notifications.
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          _habitChannelId,
          _habitChannelName,
          description: 'Daily habit reminders — rings with alarm tone',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          // notificationRingtone routes through RINGER volume (always audible).
          // Do NOT use AudioAttributesUsage.alarm — that uses the separate alarm
          // volume slider which is often 0 on Samsung devices.
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          // Explicitly set the system default alarm tone as the channel sound.
          // Without this, Samsung creates the channel with NO sound assigned,
          // causing silent notifications even with playSound: true.
          sound: const UriAndroidNotificationSound(
              'content://settings/system/alarm_alert'),
        ),
      );

      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _periodChannelId,
          _periodChannelName,
          description: 'Period cycle mood reminders',
          importance: Importance.defaultImportance,
          playSound: true,
        ),
      );
    }

    _initialised = true;
    debugPrint('[Notifications] initialised — habit channel v3 (ringtone stream)');
  }

  // ── Habit alarm ───────────────────────────────────────────────────────────

  Future<void> scheduleHabitAlarm({
    required String habitName,
    required TimeOfDay time,
  }) async {
    await init();

    final allowed = await requestPermission();
    if (!allowed) {
      debugPrint('[Notifications] permission denied — alarm not scheduled');
      return;
    }

    final id = _habitId(habitName);
    await _plugin.cancel(id);

    final now = DateTime.now();
    var localTarget = DateTime(
        now.year, now.month, now.day, time.hour, time.minute);
    if (!localTarget.isAfter(now)) {
      localTarget = localTarget.add(const Duration(days: 1));
    }

    final scheduled = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.local, localTarget.millisecondsSinceEpoch);

    await _plugin.zonedSchedule(
      id,
      '⏰ Time for $habitName',
      "Don't forget — log it after you're done! 💪",
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _habitChannelId,
          _habitChannelName,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          // Match the channel sound so Android 8+ uses the right tone
          sound: const UriAndroidNotificationSound(
              'content://settings/system/alarm_alert'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 700, 200, 700, 200, 700]),
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint(
        '[Notifications] scheduled "$habitName" at '
        '${time.hour}:${time.minute.toString().padLeft(2, '0')} '
        '→ next fire: $scheduled');
  }

  /// Cancel the alarm for a specific habit.
  Future<void> cancelHabitAlarm(String habitName) async {
    await init();
    await _plugin.cancel(_habitId(habitName));
    debugPrint('[Notifications] cancelled "$habitName"');
  }

  // ── Period reminder ───────────────────────────────────────────────────────

  Future<void> showPeriodMoodReminder(int cycleDay) async {
    await init();
    await _plugin.show(
      9000,
      '🌸 Day $cycleDay of your period',
      "Tap to log how you're feeling today",
      NotificationDetails(
        android: AndroidNotificationDetails(
          _periodChannelId,
          _periodChannelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Stable notification ID — hashCode avoids collisions that codeUnit sums have.
  int _habitId(String habitName) => habitName.hashCode.abs() % 9000;

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }
}
