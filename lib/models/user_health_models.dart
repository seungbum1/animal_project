// lib/models/pet_health_models.dart

import 'package:flutter/material.dart';

// ==================== ⬇️ Data Models ⬇️ ====================

class WeightRecord {
  final DateTime date;
  final double? bodyWeight;
  final double? muscleMass;
  final double? bodyFatMass;

  WeightRecord({
    required this.date,
    this.bodyWeight,
    this.muscleMass,
    this.bodyFatMass,
  });

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    final dynamic weightValue = json['value'] ?? json['bodyWeight'];
    return WeightRecord(
      date: DateTime.parse(json['date']).toLocal(),
      bodyWeight: (weightValue as num?)?.toDouble(),
      muscleMass: (json['muscleMass'] as num?)?.toDouble(),
      bodyFatMass: (json['bodyFatMass'] as num?)?.toDouble(),
    );
  }
}

class ActivityRecord {
  final DateTime date;
  final int? time;
  final int? calories;

  ActivityRecord({required this.date, this.time, this.calories});
  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    return ActivityRecord(
      date: DateTime.parse(json['date']).toLocal(),
      time: (json['time'] as num?)?.toInt() ?? (json['value'] as num?)?.toInt(),
      calories: (json['calories'] as num?)?.toInt(),
    );
  }
}

class IntakeRecord {
  final DateTime date;
  final int? food;
  final int? water;

  IntakeRecord({required this.date, this.food, this.water});
  factory IntakeRecord.fromJson(Map<String, dynamic> json) {
    return IntakeRecord(
      date: DateTime.parse(json['date']).toLocal(),
      food: (json['food'] as num?)?.toInt() ?? (json['value'] as num?)?.toInt(),
      water: (json['water'] as num?)?.toInt(),
    );
  }
}

class PetProfile {
  final String name;
  final int age;
  final String gender;
  final List<DiaryEntry> diaries;
  final List<MedicationAlarm> alarms;
  final HealthChart healthChart;

  PetProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.diaries,
    required this.alarms,
    required this.healthChart
  });

  factory PetProfile.fromJson(Map<String, dynamic> json) {
    var diaryList = json['diaries'] as List? ?? [];
    var alarmList = json['alarms'] as List? ?? [];
    List<MedicationAlarm> parsedAlarms = alarmList.map((i) => MedicationAlarm.fromJson(i)).toList();
    return PetProfile(
      name: json['name'] ?? '이름 없음',
      age: json['age'] ?? 0,
      gender: json['gender'] ?? '',
      diaries: diaryList.map((d) => DiaryEntry.fromJson(d)).toList(),
      alarms: parsedAlarms,
      healthChart: HealthChart.fromJson(json['healthChart'] ?? {}),
    );
  }
}

class HealthChart {
  final List<ChartDataPoint> weight;
  final List<ChartDataPoint> activity;
  final List<ChartDataPoint> intake;
  final List<WeightRecord> weightDetails;
  final List<ActivityRecord> activityDetails;
  final List<IntakeRecord> intakeDetails;

  HealthChart({
    required this.weight,
    required this.activity,
    required this.intake,
    required this.weightDetails,
    required this.activityDetails,
    required this.intakeDetails
  });

  factory HealthChart.fromJson(Map<String, dynamic> json) {
    var activityList = json['activity'] as List? ?? [];
    var intakeList = json['intake'] as List? ?? [];
    var weightList = json['weight'] as List? ?? [];
    return HealthChart(
      weight: weightList.map((p) => ChartDataPoint.fromJson(p)).toList(),
      activity: activityList.map((p) => ChartDataPoint.fromJson(p, isActivity: true)).toList(),
      intake: intakeList.map((p) => ChartDataPoint.fromJson(p, isIntake: true)).toList(),
      weightDetails: weightList.map((p) => WeightRecord.fromJson(p)).toList(),
      activityDetails: activityList.map((p) => ActivityRecord.fromJson(p)).toList(),
      intakeDetails: intakeList.map((p) => IntakeRecord.fromJson(p)).toList(),
    );
  }
}

class ChartDataPoint {
  final DateTime date;
  final double value;

  ChartDataPoint({required this.date, required this.value});

  factory ChartDataPoint.fromJson(Map<String, dynamic> json, {bool isActivity = false, bool isIntake = false}) {
    dynamic val;
    if (isActivity) {
      val = json['time'] ?? json['value'];
    } else if (isIntake) {
      val = json['food'] ?? json['value'];
    } else {
      val = json['bodyWeight'] ?? json['value'];
    }
    return ChartDataPoint(
      date: DateTime.parse(json['date']).toLocal(),
      value: (val as num? ?? 0).toDouble(),
    );
  }
}

class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String imagePath;

  DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.imagePath
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      date: DateTime.parse(json['date']).toLocal(),
      imagePath: json['imagePath'] ?? '',
    );
  }
}

class MedicationAlarm {
  final String id;
  TimeOfDay time;
  String label;
  bool isActive;
  // ✅ 반복 요일과 다시 울림 시간 필드 추가
  Set<int> repeatDays; // 월:1, 화:2, ..., 일:7
  int? snoozeMinutes;  // 다시 울림 분

  MedicationAlarm({
    required this.id,
    required this.time,
    required this.label,
    this.isActive = true,
    this.repeatDays = const {}, // 기본값은 비어있는 Set
    this.snoozeMinutes,
  });

  factory MedicationAlarm.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String? ?? '00:00').split(':');
    // 서버에서 온 repeatDays (List<dynamic>)를 Set<int>로 변환
    final repeatDaysList = json['repeatDays'] as List<dynamic>? ?? [];
    final repeatDaysSet = repeatDaysList.map((day) => day as int).toSet();

    return MedicationAlarm(
      id: json['_id'] ?? '',
      time: TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1])),
      label: json['label'] ?? '',
      isActive: json['isActive'] ?? false,
      repeatDays: repeatDaysSet, // ✅ 추가
      snoozeMinutes: json['snoozeMinutes'] as int?, // ✅ 추가
    );
  }
}