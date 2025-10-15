import 'package:flutter/material.dart';
import 'package:animal_project/user_medication_alarm_model.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';

class MedicationAlarmAddEditScreen extends StatefulWidget {
  final MedicationAlarm? alarm; // 수정 모드일 경우 기존 알람 데이터

  const MedicationAlarmAddEditScreen({super.key, this.alarm});

  @override
  State<MedicationAlarmAddEditScreen> createState() =>
      _MedicationAlarmAddEditScreenState();
}

class _MedicationAlarmAddEditScreenState
    extends State<MedicationAlarmAddEditScreen> {
  late TimeOfDay _selectedTime;
  late final TextEditingController _labelController;
  bool _isSnoozeEnabled = false;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.alarm?.time ?? TimeOfDay.now();
    _labelController = TextEditingController(text: widget.alarm?.label ?? '');
    // isSnoozeEnabled 등 다른 속성도 여기서 초기화
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // '오전', '오후' 텍스트 스타일
    final timeTextStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey[400]);
    final highlightedTimeTextStyle = const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBE6),
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소', style: TextStyle(color: Colors.black54)),
        ),
        title: Text(widget.alarm == null ? '복약 알림 추가' : '복약 알림 수정', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () { /* 저장 로직 */ Navigator.of(context).pop(); },
            child: const Text('저장', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFFFFBE6),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: TimePickerSpinner(
              is24HourMode: false,
              normalTextStyle: timeTextStyle,
              highlightedTextStyle: highlightedTimeTextStyle,
              spacing: 60,
              itemHeight: 60,
              isForce2Digits: true,
              onTimeChange: (time) {
                setState(() {
                  _selectedTime = TimeOfDay(hour: time.hour, minute: time.minute);
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('반복'),
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('안 함', style: TextStyle(color: Colors.grey)), Icon(Icons.arrow_forward_ios, size: 16)],
            ),
            onTap: () { /* 반복 설정 화면으로 이동 */ },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('내용'),
            subtitle: TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                hintText: '알람 내용을 입력하세요',
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('다시 울림'),
            value: _isSnoozeEnabled,
            onChanged: (bool value) {
              setState(() {
                _isSnoozeEnabled = value;
              });
            },
          ),
          const Spacer(), // 남은 공간 차지
          // 수정 모드일 때만 '알람 삭제' 버튼 표시
          if (widget.alarm != null)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFFBE6),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () { /* 삭제 로직 */ Navigator.of(context).pop(); },
                child: const Text('알람 삭제', style: TextStyle(color: Colors.black, fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }
}