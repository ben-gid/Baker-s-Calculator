/// Schedules the bake-timeline reminders.
///
/// Permission is requested at "Start bake", never at launch — a calculator has
/// no business asking for notifications before the baker has asked for a timer.
/// If permission is refused, everything else still works; the timeline just
/// becomes a printed plan instead of an alarm clock.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/timeline.dart';

enum ScheduleOutcome {
  /// Reminders are set.
  scheduled,

  /// The baker said no. The plan is still on screen.
  permissionDenied,

  /// This platform has no local notifications (web, some desktops).
  unsupported,
}

class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'bake_timeline';

  /// Notification ids are allocated from this base so cancelling a bake does
  /// not have to know which steps were scheduled.
  static const _idBase = 1000;
  static const _maxSteps = 32;

  bool _initialised = false;

  Future<void> _ensureInitialised() async {
    if (_initialised) return;
    tz.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for explicitly at "Start bake" instead.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialised = true;
  }

  Future<bool> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final iOS = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iOS != null) {
      return await iOS.requestPermissions(alert: true, sound: true) ?? false;
    }

    final macOS = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macOS != null) {
      return await macOS.requestPermissions(alert: true, sound: true) ?? false;
    }

    return false;
  }

  /// Schedules a reminder at the END of every waiting step, because that is the
  /// moment something needs doing.
  Future<ScheduleOutcome> scheduleBake({
    required String recipeName,
    required List<ScheduledStep> steps,
  }) async {
    if (kIsWeb) return ScheduleOutcome.unsupported;

    try {
      await _ensureInitialised();
    } on Object catch (e) {
      debugPrint('Notifications unavailable: $e');
      return ScheduleOutcome.unsupported;
    }

    if (!await _requestPermission()) return ScheduleOutcome.permissionDenied;

    await cancelBake();

    final alarms = steps.where((s) => s.step.isAlarm).take(_maxSteps).toList();
    for (var i = 0; i < alarms.length; i++) {
      final scheduled = alarms[i];
      final when = tz.TZDateTime.from(scheduled.endsAt, tz.local);
      if (when.isBefore(tz.TZDateTime.now(tz.local))) continue;

      final next = _nextStepTitle(steps, scheduled);
      await _plugin.zonedSchedule(
        id: _idBase + i,
        title: recipeName,
        body: next == null
            ? '${scheduled.step.title} is done'
            : '${scheduled.step.title} is done — time to $next',
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Bake reminders',
            channelDescription: 'Tells you when a stage of your bake is done',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        // Fire at the right wall-clock time even if the clock or zone shifts,
        // which matters for an overnight cold proof across a DST change.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
    }

    return ScheduleOutcome.scheduled;
  }

  static String? _nextStepTitle(
    List<ScheduledStep> steps,
    ScheduledStep current,
  ) {
    final index = steps.indexOf(current);
    if (index < 0 || index + 1 >= steps.length) return null;
    return steps[index + 1].step.title.toLowerCase();
  }

  Future<void> cancelBake() async {
    if (kIsWeb) return;
    try {
      await _ensureInitialised();
      for (var i = 0; i < _maxSteps; i++) {
        await _plugin.cancel(id: _idBase + i);
      }
    } on Object catch (e) {
      debugPrint('Could not clear bake reminders: $e');
    }
  }
}
