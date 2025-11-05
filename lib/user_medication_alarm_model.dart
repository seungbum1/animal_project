// user_medication_alarm_model.dart.

import 'package:flutter/material.dart';

class MedicationAlarm {
  final String id;
  TimeOfDay time;
  String label;
  bool isActive;
  Set<int> repeatDays;      // ✅ 1. 반복 요일 저장을 위한 Set 추가
  int? snoozeMinutes;     // ✅ 2. 다시 울림 시간 저장을 위한 nullable int 추가

  bool get isOneTime => repeatDays.isEmpty; // ✅ 요일 미선택 = 1회성

  MedicationAlarm({
    required this.id,
    required this.time,
    required this.label,
    this.isActive = true,
    this.repeatDays = const {}, // ✅ 3. 생성자에 추가 (기본값은 빈 Set)
    this.snoozeMinutes,         // ✅ 4. 생성자에 추가
  });

  // ✅ 5. 서버 응답(JSON)을 MedicationAlarm 객체로 변환하는 팩토리 생성자 추가
  // 이 부분이 없으면 서버에서 데이터를 받아도 앱에서 사용할 수 없습니다.
  factory MedicationAlarm.fromJson(Map<String, dynamic> json) {
    final timeParts = json['time'].split(':');
    final repeatDaysFromServer = json['repeatDays'] as List<dynamic>?;

    return MedicationAlarm(
      id: json['_id'], // MongoDB의 ID는 보통 '_id' 입니다.
      time: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      label: json['label'],
      isActive: json['isActive'],
      // JSON의 List<dynamic>을 Set<int>으로 변환
      repeatDays: repeatDaysFromServer?.map((day) => day as int).toSet() ?? {},
      snoozeMinutes: json['snoozeMinutes'],
    );
  }
}