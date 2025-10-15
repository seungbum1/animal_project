import 'package:flutter/material.dart';
import 'package:animal_project/user_medication_alarm_model.dart';
import 'package:animal_project/user_medication_alarm_add_edit_screen.dart';
import 'package:animal_project/user_medication_alarm_selection_screen.dart';

class MedicationAlarmListScreen extends StatefulWidget {
  const MedicationAlarmListScreen({super.key});

  @override
  State<MedicationAlarmListScreen> createState() => _MedicationAlarmListScreenState();
}

class _MedicationAlarmListScreenState extends State<MedicationAlarmListScreen> {
  // 임시 알람 데이터
  final List<MedicationAlarm> _alarms = [
    MedicationAlarm(id: '1', time: const TimeOfDay(hour: 9, minute: 0), label: '아침 약'),
    MedicationAlarm(id: '2', time: const TimeOfDay(hour: 9, minute: 10), label: '아침 밥,물'),
    MedicationAlarm(id: '3', time: const TimeOfDay(hour: 17, minute: 0), label: '저녁 약 복용', isActive: true),
    MedicationAlarm(id: '4', time: const TimeOfDay(hour: 17, minute: 10), label: '저녁 물,밥'),
  ];

  // 시간을 보기 좋게 포맷하는 함수
  String _formatTime(TimeOfDay time) {
    final period = time.period == DayPeriod.am ? '오전' : '오후';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$period ${hour.toString().padLeft(2, ' ')}:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBE6), // 연노랑
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('복약 알림', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black54),
            onPressed: () { /* 검색 기능 구현 */ },
          ),
        ],
      ),
      body: Column(
        children: [
          // 편집 / 추가 버튼 영역
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => MedicationAlarmSelectionScreen(alarms: _alarms)));
                  },
                  child: const Text('편집', style: TextStyle(fontSize: 16, color: Colors.black54)),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MedicationAlarmAddEditScreen()));
                  },
                  icon: const Icon(Icons.add, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 알람 목록
          Expanded(
            child: ListView.separated(
              itemCount: _alarms.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final alarm = _alarms[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  title: Text(_formatTime(alarm.time), style: const TextStyle(fontSize: 24)),
                  subtitle: Text(alarm.label, style: const TextStyle(fontSize: 14)),
                  trailing: Switch(
                    value: alarm.isActive,
                    onChanged: (bool value) {
                      setState(() {
                        alarm.isActive = value;
                      });
                    },
                    activeColor: Colors.deepPurpleAccent,
                  ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => MedicationAlarmAddEditScreen(alarm: alarm)));
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