// user_medication_alarm_add_edit_screen.dart (최종 디자인 수정본)

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:animal_project/models/user_health_models.dart';
import 'package:animal_project/user_medication_alarm_repeat_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:animal_project/api_config.dart';

const Color kPrimaryColor = Color(0xFFC06362);

class MedicationAlarmAddEditScreen extends StatefulWidget {
  final MedicationAlarm? alarm;
  final String token;

  const MedicationAlarmAddEditScreen(
      {super.key, this.alarm, required this.token});

  @override
  State<MedicationAlarmAddEditScreen> createState() =>
      _MedicationAlarmAddEditScreenState();
}

class _MedicationAlarmAddEditScreenState
    extends State<MedicationAlarmAddEditScreen> {
  late TimeOfDay _selectedTime;
  late final TextEditingController _labelController;
  late Set<int> _selectedRepeatDays;
  int? _snoozeMinutes;
  bool get _isSnoozeEnabled => _snoozeMinutes != null;
  bool _isSaving = false;

  // ✅ 각 피커의 상태를 제어하기 위한 컨트롤러 추가
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _periodController;

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.alarm?.time ?? TimeOfDay.now();
    _labelController = TextEditingController(text: widget.alarm?.label ?? '');
    _selectedRepeatDays = widget.alarm?.repeatDays ?? {};
    _snoozeMinutes = widget.alarm?.snoozeMinutes;

    // ✅ 컨트롤러 초기화
    _periodController = FixedExtentScrollController(initialItem: _selectedTime.period == DayPeriod.am ? 0 : 1);
    // 12시 형식에 맞게 시간 조정 (13시는 1시, 0시는 12시)
    int initialHour = _selectedTime.hourOfPeriod;
    if (initialHour == 0) initialHour = 12; // 0시는 12시로 표시
    _hourController = FixedExtentScrollController(initialItem: initialHour - 1);
    _minuteController = FixedExtentScrollController(initialItem: _selectedTime.minute);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  // ... (_getRepeatDaysText, _showSnoozeDialog, _saveAlarm, _deleteAlarm 함수는 기존과 동일)
  String _getRepeatDaysText() {
    if (_selectedRepeatDays.isEmpty) return '안 함';
    if (_selectedRepeatDays.length == 7) return '매일';
    if (_selectedRepeatDays.containsAll({1, 2, 3, 4, 5}) &&
        _selectedRepeatDays.length == 5) return '주중 (월-금)';
    if (_selectedRepeatDays.containsAll({6, 7}) &&
        _selectedRepeatDays.length == 2) return '주말 (토-일)';
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    List<String> selectedDayNames = [];
    for (int i = 1; i <= 7; i++) {
      if (_selectedRepeatDays.contains(i)) {
        selectedDayNames.add(weekdays[i - 1]);
      }
    }
    return '매주 ${selectedDayNames.join(', ')}';
  }

  Future<void> _showSnoozeDialog() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('다시 울림 간격'),
          children: [5, 10, 15, 30]
              .map((minutes) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, minutes),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text('$minutes분 간격'),
            ),
          ))
              .toList(),
        );
      },
    );
    if (selected != null) {
      setState(() {
        _snoozeMinutes = selected;
      });
    }
  }

  Future<void> _saveAlarm() async {
    if (_labelController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알람 내용을 입력해주세요.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final isEditMode = widget.alarm != null;
    final url = isEditMode
        ? '$_baseUrl/users/me/alarms/${widget.alarm!.id}'
        : '$_baseUrl/users/me/alarms';
    final body = json.encode({
      'time': '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
      'label': _labelController.text,
      'isActive': widget.alarm?.isActive ?? true,
      'repeatDays': _selectedRepeatDays.toList(),
      'snoozeMinutes': _snoozeMinutes,
    });
    try {
      final response = isEditMode
          ? await http.put(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'}, body: body)
          : await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'}, body: body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        throw Exception('알람 저장 실패 (${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAlarm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알람 삭제'),
        content: const Text('정말 이 알람을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/users/me/alarms/${widget.alarm!.id}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 204) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        throw Exception('알람 삭제 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ✅ 시간 선택기를 만드는 새로운 헬퍼 위젯
  Widget _buildTimePicker() {
    const double itemExtent = 40.0;
    const double pickerWidth = 60.0;
    final timeTextStyle =
    TextStyle(fontSize: 26, color: Colors.grey[1000]);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // --- 오전/오후 피커 ---
        SizedBox(
          width: 80,
          child: CupertinoPicker(
            scrollController: _periodController,
            itemExtent: itemExtent,
            onSelectedItemChanged: (index) {
              _updateSelectedTime();
            },
            children: [
              Center(child: Text('오전', style: timeTextStyle)),
              Center(child: Text('오후', style: timeTextStyle)),
            ],
          ),
        ),
        // --- 시간 피커 ---
        SizedBox(
          width: pickerWidth,
          child: CupertinoPicker(
            scrollController: _hourController,
            itemExtent: itemExtent,
            looping: true,
            onSelectedItemChanged: (index) {
              _updateSelectedTime();
            },
            children: List<Widget>.generate(12, (index) {
              return Center(child: Text('${index + 1}'.padLeft(2, '0'), style: timeTextStyle));
            }),
          ),
        ),
        Text(':', style: timeTextStyle.copyWith(fontWeight: FontWeight.bold)),
        // --- 분 피커 ---
        SizedBox(
          width: pickerWidth,
          child: CupertinoPicker(
            scrollController: _minuteController,
            itemExtent: itemExtent,
            looping: true,
            onSelectedItemChanged: (index) {
              _updateSelectedTime();
            },
            children: List<Widget>.generate(60, (index) {
              return Center(child: Text('${index}'.padLeft(2, '0'), style: timeTextStyle));
            }),
          ),
        ),
      ],
    );
  }

  // ✅ 피커 값이 변경될 때마다 _selectedTime 상태를 업데이트하는 함수
  void _updateSelectedTime() {
    int hour = _hourController.selectedItem + 1;
    if (_periodController.selectedItem == 1) { // 오후
      if (hour != 12) hour += 12;
    } else { // 오전
      if (hour == 12) hour = 0; // 오전 12시는 0시
    }
    final int minute = _minuteController.selectedItem;
    setState(() {
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFFFFBE6),
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소', style: TextStyle(color: Colors.black54, fontSize: 16)),
        ),
        title: Text(widget.alarm == null ? '복약 알림 추가' : '복약 알림 수정',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveAlarm,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('저장', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- 시간 선택기 ---
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBE6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ✅ 새롭게 만든 시간 피커 호출
                  _buildTimePicker(),
                  // 하이라이트 박스 (디자인)
                  IgnorePointer(
                    child: Container(
                      width: 220, // 너비를 살짝 조절하여 여백을 줍니다.
                      height: 40,
                      decoration: BoxDecoration(

                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // --- 설정 카드 ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.repeat_rounded,
                    title: '반복',
                    trailingText: _getRepeatDaysText(),
                    onTap: () async {
                      final result = await Navigator.push<Set<int>>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MedicationAlarmRepeatScreen(
                              initialRepeatDays: _selectedRepeatDays),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          _selectedRepeatDays = result;
                        });
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.label_outline_rounded, color: kPrimaryColor),
                    title: const Text('내용'),
                    subtitle: TextField(
                      controller: _labelController,
                      decoration: const InputDecoration(
                        hintText: '알람 내용을 입력하세요',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(top: 4),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.snooze_rounded, color: kPrimaryColor),
                    title: const Text('다시 울림'),
                    subtitle: _isSnoozeEnabled
                        ? Text('${_snoozeMinutes}분 후 다시 울림')
                        : null,
                    trailing: Switch.adaptive(
                      value: _isSnoozeEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          if (value) {
                            _snoozeMinutes = 5;
                            _showSnoozeDialog();
                          } else {
                            _snoozeMinutes = null;
                          }
                        });
                      },
                      activeTrackColor: kPrimaryColor,
                      activeColor: Colors.white,
                    ),
                    onTap: () {
                      setState(() {
                        if (!_isSnoozeEnabled) {
                          _snoozeMinutes = 5;
                          _showSnoozeDialog();
                        } else {
                          _snoozeMinutes = null;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // --- 삭제 버튼 ---
            if (widget.alarm != null)
              GestureDetector(
                onTap: _isSaving ? null : _deleteAlarm,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      '알람 삭제',
                      style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: kPrimaryColor),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailingText, style: const TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
      onTap: onTap,
    );
  }
}