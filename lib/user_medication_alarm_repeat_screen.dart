// user_medication_alarm_repeat_screen.dart.

import 'package:flutter/material.dart';

class MedicationAlarmRepeatScreen extends StatefulWidget {
  final Set<int> initialRepeatDays;

  const MedicationAlarmRepeatScreen({
    super.key,
    required this.initialRepeatDays,
  });

  @override
  State<MedicationAlarmRepeatScreen> createState() =>
      _MedicationAlarmRepeatScreenState();
}

class _MedicationAlarmRepeatScreenState
    extends State<MedicationAlarmRepeatScreen> {
  late Set<int> _selectedDays;
  final List<String> _weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  @override
  void initState() {
    super.initState();
    _selectedDays = Set.from(widget.initialRepeatDays);
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
          onPressed: () => Navigator.of(context).pop(), // 저장하지 않고 뒤로가기
        ),
        title: const Text('반복 설정', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selectedDays), // 선택된 요일 반환
            child: const Text('저장', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _weekdays.length,
        itemBuilder: (context, index) {
          final dayIndex = index + 1; // 월요일=1, ...
          final isSelected = _selectedDays.contains(dayIndex);
          return ListTile(
            title: Text(_weekdays[index]),
            trailing: isSelected
                ? const Icon(Icons.check, color: Colors.red)
                : null,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedDays.remove(dayIndex);
                } else {
                  _selectedDays.add(dayIndex);
                }
              });
            },
          );
        },
      ),
    );
  }
}