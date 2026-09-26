import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models.dart';
import 'db.dart';

/// 기기 안에서 예약하는 알림. 서버 없이도 일정 시간에 휴대폰으로 알림이 옵니다.
class Notify {
  static final _p = FlutterLocalNotificationsPlugin();
  static const _briefingId = 1;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'planai_events',
      '일정 알림',
      channelDescription: '일정이 시작되기 전에 알려 줍니다',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _p.initialize(settings);
  }

  static Future<void> requestPermissions() async {
    await _p
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _p
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static int _idFor(String eventId) => (eventId.hashCode & 0x3fffffff) + 100;

  static Future<void> _zoned(int id, String title, String body, tz.TZDateTime at, {DateTimeComponents? match}) async {
    try {
      await _p.zonedSchedule(id, title, body, at, _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: match);
    } catch (_) {
      // 정확한 알람 권한이 없으면 약간 늦을 수 있는 방식으로 대체
      await _p.zonedSchedule(id, title, body, at, _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: match);
    }
  }

  /// 일정 시작 10분 전 알림
  static Future<void> scheduleEvent(PlanEvent e, {int minutesBefore = 10}) async {
    if (e.id == null || e.done) return;
    final when = e.start.subtract(Duration(minutes: minutesBefore));
    if (when.isBefore(DateTime.now())) return;
    final extra = e.isStudy ? ' · 학습 자료를 열어 보세요' : '';
    await _zoned(
      _idFor(e.id!),
      '⏰ ${e.title}',
      '${DateFormat('HH:mm').format(e.start)}에 시작해요$extra',
      tz.TZDateTime.from(when, tz.local),
    );
  }

  static Future<void> cancelEvent(String eventId) => _p.cancel(_idFor(eventId));

  /// 앞으로 30일 일정 알림을 다시 맞춤 (앱 시작 시 호출)
  static Future<void> resyncUpcoming() async {
    final now = DateTime.now();
    final events = await Db.eventsBetween(now, now.add(const Duration(days: 30)));
    for (final e in events) {
      await scheduleEvent(e);
    }
  }

  // ── 아침 브리핑 (매일 기상 시간) ──
  static Future<bool> briefingOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('briefing_on') ?? true;
  }

  static Future<void> setBriefing(bool on, int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('briefing_on', on);
    await _p.cancel(_briefingId);
    if (!on) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (at.isBefore(now)) at = at.add(const Duration(days: 1));
    await _zoned(_briefingId, '☀️ 좋은 아침이에요', '오늘 일정을 확인하고, AI에게 하루 계획을 부탁해 보세요', at,
        match: DateTimeComponents.time);
  }
}
