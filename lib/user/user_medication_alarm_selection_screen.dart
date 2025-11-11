// user_medication_alarm_selection_screen.dart (수정된 최종본)

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:animal_project/models/user_health_models.dart';
import 'package:animal_project/api_config.dart';

const Color kPrimaryColor = Color(0xFFC06362);

class MedicationAlarmSelectionScreen extends StatefulWidget {
  final List<MedicationAlarm> alarms;
  final String token;

  const MedicationAlarmSelectionScreen({
    super.key,
    required this.alarms,
    required this.token,
  });

  @override
  State<MedicationAlarmSelectionScreen> createState() =>
      _MedicationAlarmSelectionScreenState();
}

class _MedicationAlarmSelectionScreenState
    extends State<MedicationAlarmSelectionScreen> {
  final Set<String> _selectedAlarmIds = {};
  bool _isDeleting = false;

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    // 시간순으로 정렬
    widget.alarms.sort((a, b) {
      int hourCompare = a.time.hour.compareTo(b.time.hour);
      if (hourCompare != 0) return hourCompare;
      return a.time.minute.compareTo(b.time.minute);
    });
  }

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
        _selectedAlarmIds.clear();
      } else {
        _selectedAlarmIds.addAll(widget.alarms.map((a) => a.id));
      }
    });
  }

  String _formatTime(TimeOfDay time) {
    final period = time.period == DayPeriod.am ? '오전' : '오후';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$period ${hour.toString().padLeft(2, ' ')}:$minute';
  }

  Future<void> _deleteSelectedAlarms() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_selectedAlarmIds.length}개 알람 삭제'),
        content: const Text('선택한 알람을 모두 삭제하시겠습니까?'),
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
    setState(() => _isDeleting = true);
    try {
      List<Future<void>> deleteFutures = [];
      for (String id in _selectedAlarmIds) {
        final future = http.delete(
          Uri.parse('$_baseUrl/users/me/alarms/$id'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        );
        deleteFutures.add(future.then((response) {
          if (response.statusCode != 204) {
            throw Exception('ID $id 삭제 실패');
          }
        }));
      }
      await Future.wait(deleteFutures);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canDelete = _selectedAlarmIds.isNotEmpty;
    final bool isAllSelected = _selectedAlarmIds.length == widget.alarms.length && widget.alarms.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBE6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('알람 편집', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (canDelete && !_isDeleting) ? _deleteSelectedAlarms : null,
            child: _isDeleting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('삭제', style: TextStyle(color: canDelete ? Colors.red : Colors.grey)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('총 ${widget.alarms.length}개'),
                TextButton(
                  onPressed: _toggleSelectAll,
                  child: Text(isAllSelected ? '전체 해제' : '전체 선택'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.alarms.length,
              itemBuilder: (context, index) {
                final alarm = widget.alarms[index];
                final isSelected = _selectedAlarmIds.contains(alarm.id);
                return ListTile(
                  onTap: () => _toggleSelection(alarm.id),

                  // ✅ 기존 leading: Icon(...) 부분을 아래 코드로 교체하세요.
                  leading: isSelected
                  // --- ON 상태 ---
                      ? Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: kPrimaryColor, // 버건디 배경
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white, // 흰색 체크 아이콘
                      size: 16,
                    ),
                  )
                  // --- OFF 상태 ---
                      : Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400, width: 2), // 회색 테두리
                    ),
                  ),
                  title: Text(_formatTime(alarm.time), style: const TextStyle(fontSize: 20)),
                  subtitle: Text(alarm.label),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}