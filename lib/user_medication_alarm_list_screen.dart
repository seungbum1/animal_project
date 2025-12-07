// user_medication_alarm_list_screen.dart (수정된 최종본)

import 'package:animal_project/user_add_health_record_dialog.dart';
import 'package:flutter/material.dart';
import 'package:animal_project/models/user_health_models.dart'; // 통합 모델
import 'package:animal_project/user_medication_alarm_add_edit_screen.dart';
import 'package:animal_project/user_medication_alarm_selection_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:animal_project/api_config.dart';

import 'medication_alarm_notifications.dart'; // ✅ 새로 추가

const Color kPrimaryColor = Color(0xFFC06362);

class MedicationAlarmListScreen extends StatefulWidget {
  final List<MedicationAlarm> initialAlarms;
  final String token;

  const MedicationAlarmListScreen({
    super.key,
    required this.initialAlarms,
    required this.token,
  });

  @override
  State<MedicationAlarmListScreen> createState() =>
      _MedicationAlarmListScreenState();
}

class _MedicationAlarmListScreenState extends State<MedicationAlarmListScreen> {
  String get _baseUrl => ApiConfig.baseUrl;
  late List<MedicationAlarm> _alarms;

  // ✅ 반복 없는 알람 자동 OFF 타이머
  Timer? _autoOffTimer;

  @override
  void initState() {
    super.initState();
    _alarms = List.from(widget.initialAlarms);
    _sortAlarms();

    // 알림 플러그인 초기화 (혹시 main에서 안 했을 때 대비)
    MedicationAlarmNotifications.init();

    // 현재 알람 상태 기준으로 로컬 알림 싹 재등록
    _resyncNotifications();

    // 1분마다 "반복 없음 + 오늘 시간 지난 알람" 자동 OFF 체크
    _startAutoOffTimer();
  }

  @override
  void dispose() {
    _autoOffTimer?.cancel();
    super.dispose();
  }

  void _sortAlarms() {
    _alarms.sort((a, b) {
      int hourCompare = a.time.hour.compareTo(b.time.hour);
      if (hourCompare != 0) return hourCompare;
      return a.time.minute.compareTo(b.time.minute);
    });
  }

  // ✅ 알람 목록 변경될 때마다 로컬 알림 재스케줄
  Future<void> _resyncNotifications() async {
    await MedicationAlarmNotifications.rescheduleAll(_alarms);
  }

  // ✅ 1분마다 한 번씩 확인해서 "반복 없음 + 이미 지난 시간" 자동 OFF
  void _startAutoOffTimer() {
    _autoOffTimer?.cancel();

    // 처음 한 번 즉시 체크
    _checkAndAutoDeactivateOneShotAlarms();

    _autoOffTimer = Timer.periodic(
      const Duration(minutes: 1),
          (_) => _checkAndAutoDeactivateOneShotAlarms(),
    );
  }

  Future<void> _checkAndAutoDeactivateOneShotAlarms() async {
    final now = DateTime.now();

    for (final alarm in List<MedicationAlarm>.from(_alarms)) {
      if (!alarm.isActive) continue; // 이미 꺼진 건 스킵
      if (alarm.repeatDays.isNotEmpty) continue; // 반복 있는 건 스킵

      final todayAlarmTime = DateTime(
        now.year,
        now.month,
        now.day,
        alarm.time.hour,
        alarm.time.minute,
      );

      if (now.isAfter(todayAlarmTime)) {
        // ✅ 오늘 기준 이미 지난 시간이면 자동 OFF
        await _toggleAlarmActive(alarm, false);
      }
    }
  }

  // ✅ 다른 화면에서 추가/수정/삭제 후 돌아왔을 때 목록 새로고침
  Future<void> _refreshAlarms(dynamic result) async {
    if (result == true) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/users/me'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        );
        if (response.statusCode == 200 && mounted) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final petProfile =
          PetProfile.fromJson(data['user']['petProfile'] ?? {});
          setState(() {
            _alarms = petProfile.alarms;
            _sortAlarms();
          });

          // ✅ 서버 기준 최신 상태로 다시 스케줄
          _resyncNotifications();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('목록을 새로고침하는 데 실패했습니다: $e')),
          );
        }
      }
    }
  }

  String _formatTime(TimeOfDay time) {
    final period = time.period == DayPeriod.am ? '오전' : '오후';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$period ${hour.toString().padLeft(2, ' ')}:$minute';
  }

  Future<void> _toggleAlarmActive(
      MedicationAlarm alarm, bool isActive) async {
    final originalIsActive = alarm.isActive;

    // UI 먼저 반영
    setState(() {
      alarm.isActive = isActive;
    });

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/me/alarms/${alarm.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'time':
          '${alarm.time.hour.toString().padLeft(2, '0')}:${alarm.time.minute.toString().padLeft(2, '0')}',
          'label': alarm.label,
          'isActive': isActive,
          'repeatDays': alarm.repeatDays.toList(),
          'snoozeMinutes': alarm.snoozeMinutes,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('상태 업데이트 실패 (${response.statusCode})');
      }

      // ✅ 서버 반영 성공 시 로컬 알림 재스케줄
      await _resyncNotifications();
    } catch (e) {
      // 실패 시 UI 원복
      setState(() {
        alarm.isActive = originalIsActive;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('알람 상태 변경에 실패했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBE6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('복약 알림',
            style:
            TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0, vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MedicationAlarmSelectionScreen(
                          alarms: _alarms,
                          token: widget.token,
                        ),
                      ),
                    ).then(_refreshAlarms);
                  },
                  child: const Text('편집',
                      style: TextStyle(
                          fontSize: 16, color: Colors.black54)),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MedicationAlarmAddEditScreen(
                              token: widget.token,
                            ),
                      ),
                    ).then(_refreshAlarms);
                  },
                  icon: const Icon(Icons.add, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _alarms.isEmpty
                ? const Center(
              child: Text('설정된 알람이 없습니다.\n알람을 추가해보세요.'),
            )
                : ListView.separated(
              itemCount: _alarms.length,
              separatorBuilder: (context, index) =>
              const Divider(
                  height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final alarm = _alarms[index];
                return ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 8.0),
                  title: Text(_formatTime(alarm.time),
                      style:
                      const TextStyle(fontSize: 24)),
                  subtitle: Text(alarm.label,
                      style:
                      const TextStyle(fontSize: 14)),
                  trailing: Switch(
                    value: alarm.isActive,
                    onChanged: (bool value) {
                      _toggleAlarmActive(alarm, value);
                    },
                    activeColor: Colors.white,
                    activeTrackColor: kPrimaryColor,
                    inactiveTrackColor:
                    Colors.grey.shade300,
                    inactiveThumbColor: Colors.white,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MedicationAlarmAddEditScreen(
                              alarm: alarm,
                              token: widget.token,
                            ),
                      ),
                    ).then(_refreshAlarms);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
