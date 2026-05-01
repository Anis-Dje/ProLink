import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around `flutter_local_notifications`.
///
/// Pro-Link uses local notifications (no Firebase / FCM) for the bonus
/// push-notification feature called out in the project document. Three
/// triggers are defined:
///
/// 1. New evaluation submitted → notify the intern (`notifyEvaluationReceived`)
/// 2. Pending evaluations remaining → remind the mentor (`notifyPendingEvaluations`)
/// 3. New schedule uploaded → notify all interns (`notifyScheduleChanged`)
///
/// All public APIs are no-ops on Flutter web (the underlying plugin
/// doesn't support browsers), so callers don't need to guard.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'prolink_general';
  static const _channelName = 'Pro-Link';
  static const _channelDescription =
      'General Pro-Link notifications (evaluations, schedules, reminders)';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) {
      _initialized = true;
      return;
    }
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );
    await _plugin.initialize(settings);

    // On Android 13+ we have to explicitly ask for the runtime POST_NOTIFICATIONS
    // permission. The plugin's helper handles older versions gracefully.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Sent to an intern after their mentor saves a new evaluation.
  Future<void> notifyEvaluationReceived({
    required String mentorName,
    required double score,
  }) {
    return _show(
      id: 1001,
      title: 'New evaluation',
      body:
          '$mentorName just submitted an evaluation for you (${score.toStringAsFixed(1)}/20).',
    );
  }

  /// Sent to a mentor reminding them of interns still missing an evaluation.
  Future<void> notifyPendingEvaluations({required int count}) {
    if (count <= 0) return Future.value();
    return _show(
      id: 1002,
      title: 'Pending evaluations',
      body: 'You still have $count intern(s) to evaluate this week.',
    );
  }

  /// Sent to interns when an admin uploads a new schedule.
  Future<void> notifyScheduleChanged({required String weekLabel}) {
    return _show(
      id: 1003,
      title: 'Schedule updated',
      body: 'A new schedule for $weekLabel is available.',
    );
  }

  /// Sent when a new training material is uploaded.
  Future<void> notifyTrainingAdded({required String title}) {
    return _show(
      id: 1004,
      title: 'New training material',
      body: '"$title" has been added to your training materials.',
    );
  }
}
