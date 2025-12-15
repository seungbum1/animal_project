import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

import 'package:animal_project/models/user_health_models.dart';

class MedicationAlarmNotifications {
  MedicationAlarmNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// 플러그인 초기화 (여러 번 호출돼도 한 번만 실제로 실행)
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 한국 시간대 세팅
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );
    final settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(settings);

    // 안드로이드 13 이상 알림 권한 요청 (permission_handler 사용)
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  }

  /// 알림 하나당 고유 ID (서버 alarm.id 기반)
  static int _idFromAlarm(MedicationAlarm alarm) {
    return alarm.id.hashCode & 0x7fffffff;
  }

  /// 현재 가지고 있는 알람 리스트 전체를 다시 스케줄
  static Future<void> rescheduleAll(List<MedicationAlarm> alarms) async {
    if (!_initialized) await init();

    // 기존 알림 모두 지우고
    await _plugin.cancelAll();

    // 켜져 있는(isActive) 알림만 다시 등록
    for (final alarm in alarms) {
      if (alarm.isActive) {
        await _scheduleOne(alarm);
      }
    }
  }

  static Future<void> _scheduleOne(MedicationAlarm alarm) async {
    final id = _idFromAlarm(alarm);
    final tz.TZDateTime firstTime = _nextInstanceForAlarm(alarm);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_alarm', // 채널 ID
        '복약 알림', // 채널 이름
        channelDescription: '약 먹을 시간을 알려주는 알림',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final title = '복약 알림';
    final body = alarm.label.isNotEmpty ? alarm.label : '약 드실 시간이에요';

    // ⚠️ 일부 기기에서 exact 알람이 막혀 있어서,
    //    exactAllowWhileIdle 대신 inexactAllowWhileIdle 를 사용
    if (alarm.repeatDays.isEmpty) {
      // 반복 없음 → 한 번만 울리는 알림
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        firstTime,
        details,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } else {
      // 요일 반복 → 매주 같은 요일/시간
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        firstTime,
        details,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// MedicationAlarm 기준으로 가장 가까운 다음 알림 시간 계산
  static tz.TZDateTime _nextInstanceForAlarm(MedicationAlarm alarm) {
    final now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime makeForDay(DateTime day) {
      return tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        alarm.time.hour,
        alarm.time.minute,
      );
    }

    // 🔹 반복 없는 알람
    if (alarm.repeatDays.isEmpty) {
      final today = DateTime(now.year, now.month, now.day);
      var candidate = makeForDay(today);
      if (candidate.isBefore(now)) {
        final tomorrow = today.add(const Duration(days: 1));
        candidate = makeForDay(tomorrow);
      }
      return candidate;
    }

    // 🔹 반복 요일이 있는 알람
    for (int offset = 0; offset < 7; offset++) {
      final day =
      DateTime(now.year, now.month, now.day).add(Duration(days: offset));
      if (!alarm.repeatDays.contains(day.weekday)) continue;
      final candidate = makeForDay(day);
      if (candidate.isAfter(now)) {
        return candidate;
      }
    }

    // 혹시 못 찾으면 그냥 하루 뒤
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return makeForDay(tomorrow);
  }

  /// 특정 알람만 취소하고 싶을 때
  static Future<void> cancelForAlarm(MedicationAlarm alarm) async {
    if (!_initialized) await init();
    await _plugin.cancel(_idFromAlarm(alarm));
  }
}
