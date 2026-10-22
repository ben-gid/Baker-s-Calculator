/// Schedules the bake reminders, and hears their Done and 15 more min buttons.
///
/// Permission is requested at "Start bake", never at launch — a calculator has
/// no business asking for notifications before the baker has asked for a timer.
/// The plugin is still initialised at launch, without asking, because iOS
/// needs the buttons' categories registered before any reminder arrives.
/// If permission is refused, everything else still works; the plan just
/// becomes a checklist instead of an alarm clock.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models/active_bake.dart';
import '../domain/timeline.dart';
import 'settings_repository.dart';

enum ScheduleOutcome {
  /// Reminders are set.
  scheduled,

  /// The baker said no. The plan is still on screen.
  permissionDenied,

  /// This platform has no local notifications (web, some desktops).
  unsupported,
}

/// A reminder's button, and the step the reminder was for.
typedef BakeResponse = ({BakeAction action, int step});

class NotificationService {
  /// [hearsButtons] is false only for the copy a background press makes to
  /// reschedule, which must not take the app's port.
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    this.hearsButtons = true,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final bool hearsButtons;

  static const _channelId = 'bake_timeline';
  static const _stepCategory = 'bake_step';
  static const _foldCategory = 'bake_fold';

  /// Where a button pressed while the app is alive is sent. Android runs every
  /// button in a background isolate, even with the app open, so that isolate
  /// hands the press to the app through this port rather than writing a bake
  /// the app is holding in memory.
  static const _portName = 'bake_actions';

  /// Notification ids are allocated from this base so cancelling a bake does
  /// not have to know which steps were scheduled.
  static const _idBase = 1000;
  static const _maxSteps = 32;

  final _actions = StreamController<BakeResponse>.broadcast();
  ReceivePort? _port;

  /// Buttons pressed while the app is running.
  Stream<BakeResponse> get actions => _actions.stream;

  bool _initialised = false;

  /// Called at launch. Never asks for permission.
  Future<void> initialise() async {
    if (kIsWeb) return;
    try {
      await _ensureInitialised();
    } on Object catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<void> _ensureInitialised() async {
    if (_initialised) return;
    tz.initializeTimeZones();
    final darwin = DarwinInitializationSettings(
      // Asked for explicitly at "Start bake" instead.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _stepCategory,
          actions: [
            DarwinNotificationAction.plain(BakeAction.done.name, 'Done'),
            DarwinNotificationAction.plain(
              BakeAction.extend.name,
              '15 more min',
            ),
          ],
        ),
        DarwinNotificationCategory(
          _foldCategory,
          actions: [
            DarwinNotificationAction.plain(BakeAction.done.name, 'Set done'),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
        macOS: darwin,
      ),
      onDidReceiveNotificationResponse: (response) {
        final parsed = parseResponse(response);
        if (parsed != null) _actions.add(parsed);
      },
      onDidReceiveBackgroundNotificationResponse: onBackgroundAction,
    );

    if (hearsButtons) {
      final port = ReceivePort();
      IsolateNameServer.removePortNameMapping(_portName);
      IsolateNameServer.registerPortWithName(port.sendPort, _portName);
      port.listen((message) {
        final [String action, int step] = message as List;
        _actions.add((action: BakeAction.values.byName(action), step: step));
      });
      _port = port;
    }
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

  /// Replaces every reminder with ones for what is left of [bake]: one at the
  /// END of each waiting step, because that is the moment something needs
  /// doing, and one for each set of folds still to come. [askPermission] is
  /// true only at "Start bake"; every later change reschedules quietly.
  Future<ScheduleOutcome> scheduleBake(
    ActiveBake bake, {
    bool askPermission = true,
  }) async {
    if (kIsWeb) return ScheduleOutcome.unsupported;

    try {
      await _ensureInitialised();
    } on Object catch (e) {
      debugPrint('Notifications unavailable: $e');
      return ScheduleOutcome.unsupported;
    }

    if (askPermission && !await _requestPermission()) {
      return ScheduleOutcome.permissionDenied;
    }

    await cancelBake();

    final now = tz.TZDateTime.now(tz.local);
    var id = _idBase;
    for (final reminder in _reminders(bake)) {
      if (id >= _idBase + _maxSteps) break;
      final when = tz.TZDateTime.from(reminder.at, tz.local);
      if (!when.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: id++,
        title: bake.recipeName,
        body: reminder.body,
        payload: '${reminder.step}',
        scheduledDate: when,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Bake reminders',
            channelDescription: 'Tells you when a stage of your bake is done',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            actions: [
              AndroidNotificationAction(
                BakeAction.done.name,
                reminder.fold ? 'Set done' : 'Done',
                cancelNotification: true,
              ),
              if (!reminder.fold)
                AndroidNotificationAction(
                  BakeAction.extend.name,
                  '15 more min',
                  cancelNotification: true,
                ),
            ],
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: reminder.fold ? _foldCategory : _stepCategory,
          ),
          macOS: DarwinNotificationDetails(
            categoryIdentifier: reminder.fold ? _foldCategory : _stepCategory,
          ),
        ),
        // Fire at the right wall-clock time even if the clock or zone shifts,
        // which matters for an overnight cold proof across a DST change.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
    }

    return ScheduleOutcome.scheduled;
  }

  static Iterable<({DateTime at, int step, String body, bool fold})> _reminders(
    ActiveBake bake,
  ) sync* {
    final schedule = bake.schedule;
    for (var i = 0; i < schedule.length; i++) {
      final s = schedule[i];
      if (bake.records[i].status != StepStatus.pending || !s.step.isAlarm) {
        continue;
      }
      final sets = s.step.sets;
      if (sets != null) {
        // The first set is due as the folds begin; the rest every interval.
        for (var set = bake.records[i].setsDone; set < sets; set++) {
          yield (
            at: s.startsAt.add(foldInterval * set),
            step: i,
            body: 'Stretch and fold: set ${set + 1} of $sets',
            fold: true,
          );
        }
        continue;
      }
      final next = bake.nextAfter(i);
      yield (
        at: s.endsAt,
        step: i,
        body: next == null
            ? '${s.step.title} is done'
            : '${s.step.title} is done — time to '
                  '${schedule[next].step.title.toLowerCase()}',
        fold: false,
      );
    }
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

  void dispose() {
    _port?.close();
    _actions.close();
  }
}

/// A button press, or null for a tap on the reminder itself.
BakeResponse? parseResponse(NotificationResponse response) {
  final step = int.tryParse(response.payload ?? '');
  final action = BakeAction.values
      .where((a) => a.name == response.actionId)
      .firstOrNull;
  return step == null || action == null ? null : (action: action, step: step);
}

/// A reminder's button pressed outside the app's own isolate. If the app is
/// alive, the press goes to it; otherwise the saved bake is updated here and
/// the reminders set again, so the next one is right when it arrives.
///
/// ponytail: if the app starts between the lookup and the write, its copy of
/// the bake is stale until it is reopened; add a version stamp if that bites.
@pragma('vm:entry-point')
Future<void> onBackgroundAction(NotificationResponse response) async {
  final parsed = parseResponse(response);
  if (parsed == null) return;

  final app = IsolateNameServer.lookupPortByName(NotificationService._portName);
  if (app != null) {
    app.send([parsed.action.name, parsed.step]);
    return;
  }

  DartPluginRegistrant.ensureInitialized();
  final settings = SettingsRepository(await SharedPreferences.getInstance());
  final bake = settings.readActiveBake();
  if (bake == null) return;
  final next = bake.apply(parsed.action, parsed.step, DateTime.now());
  await settings.writeActiveBake(next);
  await NotificationService(
    hearsButtons: false,
  ).scheduleBake(next, askPermission: false);
}
