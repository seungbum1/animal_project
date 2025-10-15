import 'package:flutter/material.dart';
import 'package:animal_project/user_medication_alarm_model.dart';

class MedicationAlarmSelectionScreen extends StatefulWidget {
  final List<MedicationAlarm> alarms;

  const MedicationAlarmSelectionScreen({super.key, required this.alarms});

  @override
  State<MedicationAlarmSelectionScreen> createState() =>
      _MedicationAlarmSelectionScreenState();
}

class _MedicationAlarmSelectionScreenState
    extends State<MedicationAlarmSelectionScreen> {
  final Set<String> _selectedAlarmIds = {};

  void _toggleSelection(String alarmId) {
    setState(() {
      if (_selectedAlarmIds.contains(alarmId)) {
        _selectedAlarmIds.remove(alarmId);
      } else {
        _selectedAlarmIds.add(alarmId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedAlarmIds.length == widget.alarms.length) {
        _selectedAlarmIds.clear(); // 모두 선택된 경우 모두 해제
      } else {
        _selectedAlarmIds.addAll(widget.alarms.map((a) => a.id)); // 모두 선택
      }
    });
  }

  String _formatTime(TimeOfDay time) {
    final period = time.period == DayPeriod.am ? '오전' : '오후';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$period ${hour.toString().padLeft(2, ' ')}:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final bool isAllSelected = _selectedAlarmIds.length == widget.alarms.length;
    final bool canDelete = _selectedAlarmIds.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBE6),
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소', style: TextStyle(color: Colors.black54)),
        ),
        title: const Text('복약 알림', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _toggleSelectAll,
            child: Text(isAllSelected ? '전체 해제' : '전체 선택', style: const TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: canDelete ? () { /* 삭제 로직 */ Navigator.of(context).pop(); } : null,
            child: Text('삭제', style: TextStyle(color: canDelete ? Colors.red : Colors.grey)),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: widget.alarms.length,
        itemBuilder: (context, index) {
          final alarm = widget.alarms[index];
          final isSelected = _selectedAlarmIds.contains(alarm.id);
          return Container(
            color: isSelected ? Colors.purple.withOpacity(0.1) : Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
              title: Text(_formatTime(alarm.time)),
              subtitle: Text(alarm.label),
              trailing: Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  _toggleSelection(alarm.id);
                },
                activeColor: Colors.purple,
                shape: const CircleBorder(),
              ),
              onTap: () => _toggleSelection(alarm.id),
            ),
          );
        },
      ),
    );
  }
}