// user_medication_alarm_list_screen.dart (수정된 최종본)

import 'package:animal_project/user_add_health_record_dialog.dart';
import 'package:flutter/material.dart';
import 'package:animal_project/models/user_health_models.dart'; // ✅ 통합 모델 사용
import 'package:animal_project/user_medication_alarm_add_edit_screen.dart';
import 'package:animal_project/user_medication_alarm_selection_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:animal_project/api_config.dart';

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
  // ✅ 상태 변수로 변경
  late List<MedicationAlarm> _alarms;

  @override
  void initState() {
    super.initState();
    // ✅ 위젯으로부터 받은 초기 데이터로 상태를 초기화
    _alarms = List.from(widget.initialAlarms);
    // 시간순으로 정렬
    _alarms.sort((a, b) {
      int hourCompare = a.time.hour.compareTo(b.time.hour);
      if (hourCompare != 0) return hourCompare;
      return a.time.minute.compareTo(b.time.minute);
    });
  }

  // ✅ 다른 화면에서 추가/수정/삭제 후 돌아왔을 때 목록을 새로고침하는 함수
  Future<void> _refreshAlarms(dynamic result) async {
    // result가 true일 때만 (성공적으로 저장/삭제되었을 때) 새로고침
    if (result == true) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/users/me'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        );
        if (response.statusCode == 200 && mounted) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          // PetProfile 모델을 사용하여 안전하게 파싱
          final petProfile = PetProfile.fromJson(data['user']['petProfile'] ?? {});
          setState(() {
            _alarms = petProfile.alarms;
            // 시간순으로 다시 정렬
            _alarms.sort((a, b) {
              int hourCompare = a.time.hour.compareTo(b.time.hour);
              if (hourCompare != 0) return hourCompare;
              return a.time.minute.compareTo(b.time.minute);
            });
          });
        }
      } catch (e) {
        // 오류 처리 (예: 스낵바 표시)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('목록을 새로고침하는 데 실패했습니다: $e')),
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

  Future<void> _toggleAlarmActive(MedicationAlarm alarm, bool isActive) async {
    // UI 우선 변경
    final originalIsActive = alarm.isActive;
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
          'time': '${alarm.time.hour}:${alarm.time.minute}',
          'label': alarm.label,
          'isActive': isActive, // 변경된 상태
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('상태 업데이트 실패');
      }
    } catch (e) {
      // 실패 시 UI 원상 복구
      setState(() {
        alarm.isActive = originalIsActive;
      });
      if(mounted) {
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
          onPressed: () => Navigator.of(context).pop(), // 돌아갈 때도 새로고침 신호
        ),
        title: const Text('복약 알림',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [],
      ),
      body: Column(
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
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
                          token: widget.token, // ✅ 토큰 전달
                        ),
                      ),
                    ).then(_refreshAlarms); // ✅ 선택 삭제 후 돌아오면 새로고침
                  },
                  child: const Text('편집',
                      style: TextStyle(fontSize: 16, color: Colors.black54)),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MedicationAlarmAddEditScreen(
                          token: widget.token, // ✅ 토큰 전달
                        ),
                      ),
                    ).then(_refreshAlarms); // ✅ 추가 후 돌아오면 새로고침
                  },
                  icon: const Icon(Icons.add, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _alarms.isEmpty
                ? const Center(child: Text('설정된 알람이 없습니다.\n알람을 추가해보세요.'))
                : ListView.separated(
              itemCount: _alarms.length,
              separatorBuilder: (context, index) =>
              const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final alarm = _alarms[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 8.0),
                  title: Text(_formatTime(alarm.time),
                      style: const TextStyle(fontSize: 24)),
                  subtitle:
                  Text(alarm.label, style: const TextStyle(fontSize: 14)),
                  trailing: Switch(
                    value: alarm.isActive,
                    onChanged: (bool value) {
                      // ✅ 스위치 변경 시 API 호출
                      _toggleAlarmActive(alarm, value);
                    },
                    // ✅ activeColor를 red로 변경
                    activeColor: Colors.white,         // Thumb color when ON
                    activeTrackColor: kPrimaryColor,

                    inactiveTrackColor: Colors.grey.shade300, // 배경 트랙 색상
                    inactiveThumbColor: Colors.white,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MedicationAlarmAddEditScreen(
                          alarm: alarm,
                          token: widget.token, // ✅ 토큰 전달
                        ),
                      ),
                    ).then(_refreshAlarms); // ✅ 수정 후 돌아오면 새로고침
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