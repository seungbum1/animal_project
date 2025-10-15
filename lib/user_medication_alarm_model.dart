import 'package:flutter/material.dart';

class MedicationAlarm {
  final String id;
  TimeOfDay time;
  String label;
  bool isActive;
  // '반복', '다시 알림' 등의 추가 속성을 여기에 정의할 수 있습니다.

  MedicationAlarm({
    required this.id,
    required this.time,
    required this.label,
    this.isActive = true,
  });
}