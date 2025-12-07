// lib/medication_alarm_notifications.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import 'models/user_health_models.dart';

class MedicationAlarmNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// 앱 시작 시 한 번 호출 (main.dart 등에서)
  static Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
    InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);

    tzdata.initializeTimeZones();

    _initialized = true;
  }

  /// 알람 id + 요일(옵션)에 따른 고유 notification id 생성
  static int _idFor(String alarmId, {int weekday = 0}) {
    // weekday 0 = one-shot / daily, 1~7 = 요일별
    return alarmId.hashCode ^ weekday;
  }

  /// 특정 알람 관련 모든 예약 취소 (one-shot + 요일 반복 포함)
  static Future<void> cancelForAlarm(MedicationAlarm alarm) async {
    await init();
    // 기본 id
    await _plugin.cancel(_idFor(alarm.id ?? ''));
    // 요일별 id
    for (int w = 1; w <= 7; w++) {
      await _plugin.cancel(_idFor(alarm.id ?? '', weekday: w));
    }
  }

  /// 모든 알람 다시 스케줄링
  static Future<void> rescheduleAll(List<MedicationAlarm> alarms) async {
    await init();
    for (final alarm in alarms) {
      await cancelForAlarm(alarm);
      if (!alarm.isActive) continue;

      if (alarm.repeatDays.isEmpty) {
        await _scheduleOneShot(alarm);
      } else {
        await _scheduleWeekly(alarm);
      }
    }
  }

  /// 반복 없음: 가장 가까운 한 번만 울리기
  static Future<void> _scheduleOneShot(MedicationAlarm alarm) async {
    if (alarm.id == null) return;

    final now = DateTime.now();
    var scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.time.hour,
      alarm.time.minute,
    );

    // 이미 지난 시간이면 내일로
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduled, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_alarm',
        '복약 알림',
        channelDescription: '복약 알림 채널',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      _idFor(alarm.id!, weekday: 0),
      '복약 알림',
      alarm.label,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: null, // 한 번만
    );
  }

  /// 반복 있음: 선택된 요일마다 주 1회 반복 예약
  static Future<void> _scheduleWeekly(MedicationAlarm alarm) async {
    if (alarm.id == null) return;
    final now = DateTime.now();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_alarm',
        '복약 알림',
        channelDescription: '복약 알림 채널',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    for (final weekday in alarm.repeatDays) {
      // weekday: 1=월 ... 7=일 (이미 그렇게 쓰고 있음)
      var scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        alarm.time.hour,
        alarm.time.minute,
      );

      // 오늘 이전 요일이면 앞으로 돌려서 해당 요일의 다음 날짜 찾기
      while (scheduled.weekday != weekday ||
          scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final tzTime = tz.TZDateTime.from(scheduled, tz.local);

      await _plugin.zonedSchedule(
        _idFor(alarm.id!, weekday: weekday),
        '복약 알림',
        alarm.label,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents:
        DateTimeComponents.dayOfWeekAndTime, // 요일+시간 반복
      );
    }
  }
}
